+++
date = "2015-06-16T16:08:33+09:00"
title = "MPICH3の内部構造のメモ"

+++

MPICH3の内部構造について、ソースコードとwikiを読みながら調べた結果。更新中。
MPICH3のソースコードを読んだり改造したりする際には、まずは公式wikiの
[設計資料](https://wiki.mpich.org/mpich/index.php/Category:Design_Documents)を
一通り読むと良い。しかし、かなり大雑把で抜けも多いので、結局細かいところは
ソースコードを読み込んでいく必要がある。

<!--more-->

## モジュール
- ADI3: Abstract Device Interface version 3
    - トランスポート層以下の通信を抽象化し、MPICH3のモジュールに統一的なインターフェース
        を定義する
    - このインターフェースを実装したモジュールは現状CH3しかない
- CH3
    - ADI3で定義されたインターフェースを実装した通信モジュール
    - ビルド時にチャネルを選択することができる:
        - Nemesis: 複数の通信方法をサポートする高速なチャネル
        - Sock: UNIXソケットを使ったシンプルなチャネル
- PMI: Process Management Interface
    - 並列ジョブの作成、接続、終了
    - 並列ジョブに関する情報の問い合わせ、プロセスが実行されているノードの問い合わせなど
    - プロセス同士の接続に必要な情報の交換など
    - MPI name publish interfaceに関連する情報の交換
    - `MPI_COMM_WORLD`に所属する全てのプロセスで共有されるKVSがある
    - MPI name publishing interfaceで接続前のプロセス同士で、接続のための
        情報共有を行うことができる

## 用語
- VC: Virtual Connection
    - プロセス間の接続を抽象化したもの
    - アプリケーション起動時に一括で接続するのでは、必要になったときに接続する仕組み
    - 参照カウントを保持しており、参照カウントが0になったときに自動的に解放される
    - VCはどれか一つのProcess Groupに所属する
    - ソースコードでは`MPIDI_VC_t`

- MPI Process ID
    - OSのPIDとは別に、MPICHは独自のPIDを管理している
    - PIDにはLocal Process IDとGlobal Process IDがある
    - Local Process ID
        - Local Process ID (LPID) は、あるプロセスが別のプロセスを識別するためのものである
        - LPIDはプロセスごとにローカルなものなので、同じLPIDでもプロセスによって
            指しているプロセスは全く異なる
        - StaticなプロセスだけならMPI_COMM_WORLDにおけるランクとLPIDは等しい
        - DynamicにSpawnしたプロセスでは、色々ややこしくなる
        - ソースコードでは`int`
    - Global Process ID
        - Global Process IDは異なるプロセスでも指しいるプロセスは同じ
        - ソースコードでは`int[2]`。0要素目がProcess Group Id, 1要素目が
            Process Group内でのRankになっている。
        - `MPID_GPID_Get`や`MPID_GPID_GetAllInComm`でコミュニケータ内での
            GPIDを取得できる
        - `MPID_GPID_ToLpid`や`MPID_GPID_ToLpidArray`でGPIDからLPIDへ変換できる

- VCRT: Virtual Connection Reference Table
    - コミュニケータはVCRTというデータ構造を保持している
    - VCRTは、コミュニケータ内でのランクがインデックス、値がVCの配列
    - `MPI_Comm_dup`時にはVCRTはコピーされず、コミュニケータの参照カウントが増える
    - ソースコードでは`MPIDI_VCRT_t`

-  PG: Process Group
    - 全てのプロセスは、Process GroupとProcess Group内でのRankで一意に区別される
    - MPIのGroupとPGは一致するとは限らないので注意
    - ソースコードでは`MPIDI_PG_t`

