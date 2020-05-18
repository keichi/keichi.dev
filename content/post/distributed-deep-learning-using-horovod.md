---
title: NAIST小規模計算クラスタでHorovodを用いて分散深層学習する
date: 2020-05-18T12:05:57+09:00
description:
tags: []
---

[以前書いた記事](/post/naist-cluster-tensorflow/)の続きです．
本記事では，分散深層学習フレームワーク
[Horovod](https://horovod.readthedocs.io/en/latest/summary_include.html)を用い，
NAISTの小規模計計算クラスタで複数ノードのGPU上で並列に深層学習を実現します．
用いるソフトウェアのバージョンは次の通りです:

- Python 3.6.9
- TensorFlow 2.2.0
- CUDA 10.0
- cuDNN 7.6.5
- NCCL 2.6.4
- Horovod 0.19.2
- GCC 7.3.1
- Open MPI 3.0.0

Python，TensorFlow，CUDA，cuDNNについては，
[以前の記事](/post/naist-cluster-tensorflow/)の手順に従ってインストール
します．GCCとOpen MPIは既にクラスタにインストールされているので，
それぞれ`compiler/gcc/7`と`mpi/openmpi/3.0.0`モジュールをロードすればOKです．

## NCCL (NVIDIA Collective Communications Library) のインストール

[NVIDIAのWebサイト](https://developer.nvidia.com/nccl/nccl-download)から
アーカイブをダウンロードし，適当なディレクトリへ展開します．

```
tar Jxvf nccl_2.6.4-1+cuda10.0_x86_64.txz
```

## Horovodのインストール

Horovodはpipでインストールできます．ただし，インストール時に
CUDA，NCCL，MPIなどをリンクしたネイティブ拡張モジュールをビルドするため，
環境変数でこれらのライブラリの場所を教えてあげる必要があります．

```
HOROVOD_CUDA_HOME=<path/to/cuda> \
HOROVOD_NCCL_HOME=<path/to/nccl> \
HOROVOD_GPU_ALLREDUCE=NCCL \
HOROVOD_GPU_BROADCAST=NCCL \
pip install --no-cache-dir horovod
```

`HOROVOD_GPU_ALLREDUCE=MPI`などと設定することにより，NCCLの代わりにMPIを
用いて通信できるようです．

## Horovodの実行

Horovodのリポジトリから，サンプルスクリプトの1つ
[tensorflow2_synthetic_benchmark.py](https://github.com/horovod/horovod/blob/f8fb21e0ceebbdc6ccc069c43239731223d2961d/examples/tensorflow2_synthetic_benchmark.py)
をダウンロードしておきます．これは，TensorFlow 2でダミーデータを用いて
ResNet-50モデルを訓練するベンチマークです．

次のジョブスクリプトを作成します:

```
#!/bin/sh
#$ -S /bin/bash
#$ -q pascal_short.q
#$ -pe mpi 96

module load compiler/gcc/7
module load mpi/openmpi/3.0.0

mpirun -np 8 -npernode 2 \
    -x NCCL_DEBUG=INFO -x HOROVOD_MPI_THREADS_DISABLE=1 \
    -mca pml ob1 \
    python3 tensorflow2_synthetic_benchmark.py
```

Horovodでは，1GPUにつき1MPIプロセスを起動する必要があります．
P100搭載ノードは1ノードにつきP100を2枚搭載しているので，`-npernode 2`と指定
します．また，今回は4ノード (=8GPU) 使うことにし，`-np 8`と指定します．

ジョブスクリプトを投入すると，下記の通り8GPUを用いて並列に学習できている
ことがわかります．

```
Model: ResNet50
Batch size: 32
Number of GPUs: 8
Running warmup...
...
Running benchmark...
Iter #0: 176.7 img/sec per GPU
Iter #1: 176.2 img/sec per GPU
Iter #2: 174.8 img/sec per GPU
Iter #3: 173.6 img/sec per GPU
Iter #4: 175.7 img/sec per GPU
Iter #5: 174.8 img/sec per GPU
Iter #6: 175.0 img/sec per GPU
Iter #7: 173.4 img/sec per GPU
Iter #8: 170.8 img/sec per GPU
Iter #9: 177.8 img/sec per GPU
Img/sec per GPU: 174.9 +-3.7
Total img/sec on 8 GPU(s): 1399.1 +-29.3
```
