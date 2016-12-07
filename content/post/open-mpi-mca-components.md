+++
Description = ""
Tags = [
]
date = "2016-12-06T18:12:38+09:00"
title = "Open MPIのMCAフレームワーク一覧"

+++

Open MPIに含まれている各MCAフレームワークの担当領域を調べたときのメモ。
Open MPIのバージョンはv 1.10。随時追記していく。

<!--more-->

## Open MPI (OMPI) レイヤ

ソースコードでは`ompi/mca`以下。

- allocator: メモリアロケータ
- coll: Collective Communication Interface, MPI集団通信のアルゴリズム
- fbtl
- mpool: メモリプール
- pml: P2P Management Layer, MPI 1対1通信のセマンティクス
- sbgp
- bcol
- fcoll: MPI-IOの集団型I/O
- mtl: Matching Transport Layer, Message Matchingをサポートするハードウェアでの
  MPI 1対1通信
- pubsub
- sharedfp: MPI-IOにおける共有ファイルポインタ
- bml: BTL Management Layer, 複数のBTLモジュールをまとめる
- crcp: Checkpoint/Restart Coordination Protocol
- fs: MPI-IOのファイル操作
- op: MPI_Op
- rcache: Registration Cache
- topo: MPIトポロジ
- btl: Byte Transfer Layer, プロセス間におけるバイト列の送受信
- dpm: MPI-2における動的プロセス生成
- io: MPI-IOのファイル読み書き
- osc: One-sided Communication interface, MPI-2の片側通信
- rte
- vprotocol

## Open, Portable Access Layer (OPAL) レイヤ

ソースコードでは`opal/mca`以下。

- backtrace
- base
- compress
- crs
- db
- dl
- event
- hwloc
- if
- installdirs
- memchecker
- memcpy
- memory
- pstat
- sec
- shmem
- timer

## Open MPI Run-Time Environment (ORTE) レイヤ

ソースコードでは`orte/mca`以下。

- dfs
- errmgr
- ess
- filem
- grpcomm
- iof
- odls
- oob
- plm
- ras
- rmaps
- rml
- routed
- sensor
- snapc
- sstore
- state
