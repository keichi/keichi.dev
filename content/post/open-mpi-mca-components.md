---
title: "Open MPIのMCAフレームワーク一覧"
date: "2016-12-06T18:12:38+09:00"
---

Open MPIに含まれている各MCAフレームワークの担当領域を調べたときのメモ。
Open MPIのバージョンはv 1.10。随時追記していく。

<!--more-->

## Open MPI (OMPI) レイヤ

ソースコードでは`ompi/mca`以下。

- allocator: メモリアロケータ
- coll: Collective Communication Interface, MPI集団通信のアルゴリズム
- fbtl: File Byte Transfer Layer, MPI-IOにおけるread/writeを抽象化
- mpool: メモリプール
- pml: P2P Management Layer, MPI 1対1通信のセマンティクス
- sbgp: Collective Operation Sub-group
- bcol: Base Collective Operations
- fcoll: MPI-IOの集団型I/O
- mtl: Matching Transport Layer, Message Matchingをサポートするハードウェアでの
  MPI 1対1通信
- pubsub: MPI-2 のpublish/subscribe
- sharedfp: MPI-IOにおける共有ファイルポインタ
- bml: BTL Management Layer, 複数のBTLモジュールをまとめる
- crcp: チェックポイント・リスタート用プロトコル
- fs: MPI-IOのファイル操作
- op: MPI_Op
- rcache: Registration Cache
- topo: MPIトポロジ
- btl: Byte Transfer Layer, プロセス間におけるバイト列の送受信
- dpm: MPI-2における動的プロセス生成
- io: MPI-IOのファイル読み書き
- osc: One-sided Communication interface, MPI-2の片側通信
- rte: Run-time environment operations
- vprotocol: Protocols for the "v" PML

## Open, Portable Access Layer (OPAL) レイヤ

ソースコードでは`opal/mca`以下。

- backtrace: バックトレース
- compress: 圧縮アルゴリズム
- crs: チェックポイント・リスタート
- db: 内部用Key-Valueストア
- dl: 共有ライブラリの動的ロード・リンク
- event
- hwloc
- if: NICの取得
- installdirs
- memchecker: メモリチェッカ (valgrindなど) のラッパ
- memcpy
- memory
- pstat
- sec
- shmem: Shared Memory Support
- timer: 高精度タイマ

## Open MPI Run-Time Environment (ORTE) レイヤ

ソースコードでは`orte/mca`以下。

- dfs: 分散ファイルシステム
- errmgr: RTEエラーマネージャ
- ess: RTE Environment-Specific Services, 環境依存のサービス
- filem: リモートファイルの管理
- grpcomm: RTE Group Communications
- iof: I/O Forwarding
- odls: ORTE Daemon Local Launch Subsystem
- oob: Out-Of-Band通信
- plm: プロセスのライフサイクル管理
- ras: リソース割当
- rmaps: リソースマッピング
- rml: RTE Message Layer
- routed: RMLのためのルーティングテーブル
- sensor: ソフトウェアとハードウェアの死活監視
- snapc: Snapshot Coordination
- sstore: Distributed Scalable Storage
- state: RTEの状態遷移機械
