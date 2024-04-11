---
title: AMD GPUへのオフローディングに対応したGCCをビルドする
date: 2024-04-10T22:35:13+09:00
description:
tags: []
---

研究室にAMDのGPUが配備されたので，OpenACCとOpenMP Target Offloadingに対応したGCCを整備しました．
オフローディングに対応したGCCのビルド手順は基本的に[GCCの公式ページ](https://gcc.gnu.org/wiki/Offloading)
に書いてありますが，微妙なconfigureオプションの違いで失敗したりしたので，動作確認した手順を以下にメモしておきます．

大きく分けて，以下の3つを順にビルドしていく必要があります．GCCはAMD GPU用のアセンブラやリンカ等の
ツールチェーンを提供していないので，LLVMもビルドする必要があります．以下ではそれぞれの手順を説明します．

- LLVM 13.0.1 (AMD GPUをターゲット)
- GCC 13.2.0 (AMD GPUをターゲット)
- GCC 13.2.0 (x86-64をターゲット)

## LLVMのビルド

まずLLVMをビルドします．GCCが対応しているLLVMのバージョンが限られており，この記事執筆時点ではLLVM 13.0.1
を使用する必要があります．

```
curl -sL https://github.com/llvm/llvm-project/releases/download/llvmorg-13.0.1/llvm-project-13.0.1.src.tar.xz | tar -xJvf -
cd llvm-project-13.0.1.src
cmake -B build -S llvm -D 'LLVM_TARGETS_TO_BUILD=X86;AMDGPU' -D LLVM_ENABLE_PROJECTS=lld
cmake --build build
```

ビルドしたLLVMからas, ld, nm, ar, ranlibを取り出し，GCCをインストール予定のディレクトリにコピーします．

```
export INSTALL_DIR=/opt/gcc-13

mkdir -p $INSTALL_DIR/amdgcn-amdhsa/bin
cp -a build/bin/llvm-ar $INSTALL_DIR/amdgcn-amdhsa/bin/ar
cp -a build/bin/llvm-ar $INSTALL_DIR/amdgcn-amdhsa/bin/ranlib
cp -a build/bin/llvm-mc $INSTALL_DIR/amdgcn-amdhsa/bin/as
cp -a build/bin/llvm-nm $INSTALL_DIR/amdgcn-amdhsa/bin/nm
cp -a build/bin/lld $INSTALL_DIR/amdgcn-amdhsa/bin/ld
```

## GCCのビルド (2回目)

GCCのソースコードをダウンロードしておきます．また，newlibというlibcの実装をダウンロードしておきます．

```
curl -sL https://ftp.tsukuba.wide.ad.jp/software/gcc/releases/gcc-13.2.0/gcc-13.2.0.tar.gz | tar -xzvf -
cd gcc-13.2.0
curl -sL http://sourceware.org/pub/newlib/newlib-4.4.0.20231231.tar.gz | tar --strip-components=1 -xzvf - newlib-4.4.0.20231231/newlib
```

AMD GPUバックエンドのGCCをビルドします．
最後にnewlibをダウンロードしたディレクトリを削除しておきます．

```
contrib/download_prerequisites

mkdir build-amdgcn-amdhsa
cd build-amdgcn-amdhsa
../configure \
    --target=amdgcn-amdhsa \
    --enable-languages=c,c++,fortran,lto \
    --disable-sjlj-exceptions \
    --with-newlib \
    --enable-as-accelerator-for=x86_64-pc-linux-gnu \
    --with-build-time-tools=$INSTALL_DIR/amdgcn-amdhsa/bin \
    --disable-libquadmath \
    --prefix=$INSTALL_DIR
make
sudo make install
rm -r ../newlib
```

## GCCのビルド (1回目)

x86-64バックエンドのGCCをビルドします．AMD GPU用のオフローディングを有効にしてconfigureします．

```
mkdir build-host
cd build-host
../configure \
    --build=x86_64-pc-linux-gnu \
    --host=x86_64-pc-linux-gnu \
    --target=x86_64-pc-linux-gnu \
    --enable-offload-targets=amdgcn-amdhsa=$INSTALL_DIR \
    --disable-bootstrap \
    --disable-multilib \
    --prefix=$INSTALL_DIR
make
sudo make install
```

## コンパイル・実行

まずインストールしたGCCにパスを通します．

```
export INSTALL_DIR=/opt/gcc-13
export PATH=$INSTALL_DIR/bin:$PATH
export LD_LIBRARY_PATH=$INSTALL_DIR/lib64:$LD_LIBRARY_PATH
```

以下のコマンドでコンパイルします．

```
gcc -fopenacc -offload=famdgcn-amdhsa -foffload-options=-march=gfx90a openacc.c
```

なおgfx90aはMI210のアーキテクチャです．搭載されているGPUのアーキテクチャは，`rocm-smi
--showproductname`で表示できます．

実行時には，ユーザが`video`グループに所属している必要があります．また，NVIDIA
GPU用のオフローディングも有効にしてGCCをビルドした際には，`ACC_DEVICE_TYPE=radeon`と環境変数を
設定し，明示的にAMD GPUを要求する必要があります．
