---
title: Process Management Interface (PMI) とは
date: 2018-02-27T19:15:24+09:00
description:
tags: []
---

ジョブスケジューラとMPIの連携について色々調べていたところ、PMIという仕組みが
出てきたので簡単にメモしておく。PMI (Process Management Interface) は、
並列分散アプリケーションのプロセス管理機能のインターフェースを標準化したAPIだ。

PMIの目的は、MPI実装からプロセス管理機能を分離することにある。PMIを使用しない場合、
MPI実装が計算ノード上でアプリケーションのプロセスを起動・終了する。つまり、プロセ
ス管理機能とMPI通信機能は一体的に実装されている。PMIではこれらの機能を分離し、
MPI通信機能はMPI実装、プロセス管理機能はプロセスマネージャに担当させる。
この分離により、下記のメリットがある:

- MPI実装 (あるいは他の並列分散プログラミングミドルウェア) とプロセス
  マネージャを別々に開発可能にする
- MPI実装とプロセスマネージャを任意の組み合わせで使用可能にする
- ジョブスケジューラ等のミドルウェアからハードウェアの構成やインターコネクトの
  の情報を得ることで、より効率的なプロセス配置を実現する

PMIにはPMI・PMI2・PMIxという異なるバージョンがあり、現時点ではPMIxが最新だと
思う。
さらに詳しい情報は
[PMI: a scalable parallel process-management interface for extreme-scale
systems](https://dl.acm.org/citation.cfm?id=1894127) や [PMIx: process management
for exascale environments](https://dl.acm.org/citation.cfm?id=3127027)
に書いてある。

## PMIのAPI

PMIが定義するAPIの雰囲気がわかるように、PMI2から関数を抜粋して書いておく。
各関数のより細かい説明は[MPICHの
Wiki](https://wiki.mpich.org/mpich/index.php/PMI_v2_API) などにある。


### ジョブの起動

- `PMI2_Job_Spawn`: プロセスマネージャへプロセス群の起動を要求
- `PMI2_Job_GetId`: プロセスが所属するジョブのIDを取得
- `PMI2_Job_Connect`: ジョブへ接続 (`PMI2_KVS_*` で他ジョブのKVSを読み書きする
  際に使用)
- `PMI2_Job_Disconnect`: ジョブへの接続解除

### プロセス間の情報交換

- `PMI2_KVS_Put`: プロセスが所属するジョブのKVSへ書き込み
- `PMI2_KVS_Get`: プロセスが所属するKVSから読み込み
- `PMI2_KVS_Fence`: `PMI2_KVS_Put` による書き込みをコミット

### ジョブ属性・ノード属性のクエリ

- `PMI2_Info_GetNodeAttr`: ノードの属性を取得
- `PMI2_Info_PutNodeAttr`: ノードの属性を設定
- `PMI2_Info_GetJobAttr`: ジョブの属性を取得

## 実際にPMIを使ってみる

PMIに対応しているOpen MPI (MPI実装) とSlurm (ジョブスケジューラ) で実際にPMI
を試してみる。手元にあるFedora 27のクラスタを使う。

まず、Slurmが正しくインストール・設定できていて、sbatchやsrunが動く
必要がある。Slurmのインストール方法を書くと長くなってしまうので、省略する。
また、PMIのヘッダファイルが含まれているslurm-develパッケージをインストール
しておく。これはOpen MPIをビルドするノードだけにインストールされていれば良い。
計算ノードには、PMIの共有ライブラリが含まれるslurm-libsパッケージをインスト
ールする。

次に、Open MPIをソースからビルドする。Fedaora 27でパッケージマネージャから
インストールできるOpen MPIはconfigure時にPMIが有効になっていないので、
自分でビルドする必要がある。

```
$ dnf install -y autoconf automake libtool gcc-c++ gcc make flex bison
$ git clone https://github.com/open-mpi/ompi.git
$ cd ompi
$ git checkout v3.0.0
$ ./autogen.pl
$ ./configure --prefix=<path> --with-slurm --with-pmi
$ make -j 16
$ make install
```

以上の準備をした後、簡単なMPIアプリケーションを4ノード上で
起動するようsrunを実行すると、次のように期待する挙動になる:

```
$ srun -N 4 hello
Hello world from processor node01, rank 0 out of 4 processors
Hello world from processor node04, rank 3 out of 4 processors
Hello world from processor node02, rank 1 out of 4 processors
Hello world from processor node03, rank 2 out of 4 processors
```

一方、PMIを使用していない環境下でアプリケーションを起動すると、

```
$ srun -N 4 hello
Hello world from processor node02, rank 0 out of 1 processors
Hello world from processor node03, rank 0 out of 1 processors
Hello world from processor node04, rank 0 out of 1 processors
Hello world from processor node01, rank 0 out of 1 processors
```

となる。これは、各ノードで起動したMPIプロセスが互いを認識できず、別個の
アプリケーションとして動作してしまっていることを示している。よって、PMIを使用
しない場合はmpiexecを併用しなければならない。
