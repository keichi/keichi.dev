---
title: 阪大SQUIDでのNWChemを動かす
date: 2025-08-13T21:52:26+09:00
description:
tags: []
---

阪大のSQUIDには[NWChem](https://nwchemgit.github.io/index.html)がインストールされていないので、
ソースコードからのインストール方法を調査・検討しました。
ここでは、SQUIDのCPUノードを対象とし、GPUオフローディングは使用せずビルドします。

## ビルドの方針

NWChemはMPI+OpenMPのハイブリッド並列に対応していることになっていますが、機能によっては
OpenMPに対応していないようなので、ここではMPIの並列化のみを有効化しました。
また、コンパイラはgfortran、ifort、ifx、MPIライブラリはOpen MPIとIntel MPIを試したところ、
大きな性能差はありませんでしたが、gfortranとOpen
MPIの組み合わせが最速であったため、これを採用しました。
BLAS、LAPACK、ScaLAPACKの実装については、MKLを用いました。

## ビルド手順

ビルド手順は[NWChemのマニュアル](https://nwchemgit.github.io/Compiling-NWChem.html)
に詳細に記述されているので、これに従います。まずソースコードをダウンロードし展開します。

```
curl -sL https://github.com/nwchemgit/nwchem/archive/refs/tags/v7.2.3-release.tar.gz | tar xzf -
cd nwchem-7.2.3-release
```

BaseGCCモジュールをロードし、Open MPIを利用可能にします。また、MKLをロードします。
MKLはBaseCPUモジュールをロードすることでも使用できますが、MPIがIntel MPIになってしまうため、MKLのみロードします。

```
module load BaseGCC/2025
source /system/apps/rhel8/cpu/intel/inteloneAPI2025.0/2025.0.1/mkl/2025.0/env/vars.sh ilp64
```

以下でNWChemのビルド設定を行います。NWChemのビルド設定は環境変数を介して行うようになっています。
まず、ソースコードのトップディレクトリや対象アーキテクチャを設定します。

```
export NWCHEM_TOP=$(pwd)
export NWCHEM_TARGET=LINUX64
export NWCHEM_MODULES="all"
export USE_NOIO=TRUE
```

BLASとLAPACKのリンク方法を設定します。コンパイラ引数は[Intel oneAPI Math Kernel Library Link Line Advisor](https://www.intel.com/content/www/us/en/developer/tools/oneapi/onemkl-link-line-advisor.html)
を用いて生成しました。
自分でLink Line Advisorを使用する場合の注意点として、NWChemは64bit版のAPIが必要なので、
Select interface layerでFortran API with 64-bit integerを選択します。
また、ここではOpenMPを使用しないので、Select threading layerにSequentialを選択します。

```
export BLAS_SIZE=8
export BLASOPT="-m64 ${MKLROOT}/lib/libmkl_blas95_ilp64.a ${MKLROOT}/lib/libmkl_lapack95_ilp64.a -L${MKLROOT}/lib -Wl,--no-as-needed -lmkl_gf_ilp64 -lmkl_sequential -lmkl_core -lpthread -lm -ldl"
export LAPACK_SIZE=8
export LAPACK_LIB="${BLASOPT}"
```

同様にScaLAPACKのリンク方法も設定します。

```
export USE_SCALAPACK=y
export SCALAPACK_SIZE=8
export SCALAPACK="-m64 -L${MKLROOT}/lib -lmkl_scalapack_ilp64 -Wl,--no-as-needed -lmkl_gf_ilp64 -lmkl_sequential -lmkl_core -lmkl_blacs_openmpi_ilp64 -lpthread -lm -ldl"
```

MPI並列の設定をします。通信のバックエンドは`ARMCI_NETWORK`環境変数によって選択でき、
[様々な選択肢](https://nwchemgit.github.io/ARMCI.html)があります。
`MPI-PR`、`MPI-TS`、`ARMCI`を試したところ、`MPI-PR`が最速だったので、`MPI-PR`を使用しました。
MPIライブラリのパスなどはMPIのコンパイララッパから自動検出されます。

```
export ARMCI_NETWORK=MPI-PR
export USE_MPI=y
export USE_MPIF=y
export USE_MPIF4=y
```

以上の設定が完了したら、ビルドします。

```
cd src
make nwchem_config
make
```

`$NWCHEM_TOP/bin/LINUX64`に実行可能ファイルが生成されます。

## 実行手順

例えば以下のようなジョブスクリプトで起動できます。環境に応じて調整してください。

```
#!/bin/bash
#PBS -q SQUID
#PBS --group=<グループ名>
#PBS -l elapstim_req=00:10:00
#PBS -b 4
#PBS -T openmpi

module load BaseGCC/2025
source /system/apps/rhel8/cpu/intel/inteloneAPI2025.0/2025.0.1/mkl/2025.0/env/vars.sh ilp64

cd $PBS_O_WORKDIR

NWCHEM_TOP=<NWChemのトップディレクトリ>

mpirun ${NQSV_MPIOPTS} -x LD_LIBRARY_PATH -np 304 --bind-to core ${NWCHEM_TOP}/bin/LINUX64/nwchem <入力ファイル>
```
