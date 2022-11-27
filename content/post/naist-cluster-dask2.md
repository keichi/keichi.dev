---
title: NAIST小規模計算クラスタでDaskを動かす (2022年版)
date: 2022-11-27T17:18:39+09:00
description:
tags: []
---


[以前](/post/naist-cluster-dask/)NAISTの小規模計算クラスタでDaskを動作させる方法を書きましたが，今年度新しいクラスタにリプレースされたことにともない，Dask-jobqueueの設定方法が一部変わりました．ここでは，以前のクラスタとの設定方法の違いをメモしておきます．

# インストール

まず，以前と同様にDaskとDask-jobqueueをインストールします．

```
$ pip install "dask[complete]" dask_jobqueue
```

venvを利用する場合，デフォルトでインストールされているPythonではvenvを利用できない (python3.8-venvがインストールされていない) ので，Pyenvなどを用いて自前でPythonをインストールする必要があります．
なお，この記事の執筆時点ではDask-jobqueueがPython 3.11上で動かないバグがあるため，
3.10以下のPythonをインストールする必要がありました．

## クラスタの起動

Dask-jobqueueを用いてクラスタを起動します．

```python
import dask
from dask_jobqueue import SLURMCluster
from dask.distributed import Client

cluster = SLURMCluster(
    queue="cluster_short",
    cores=52,
    memory="380GB",
    local_directory="/var/tmp",
    interface="ens1f1.3219",
    scheduler_options={"interface": "bond1.3219"}
)

cluster.scale(jobs=1)
client = Client(cluster)
```

ジョブスケジューラ，キュー名，ハードウェア構成が変わったため，使用するクラスタクラス
を`SLURMCluster`に変更し，`queue`, `cores`, `memory`をそれぞれ変更しています．

また，NIC名も変わったので，`interface`と`scheduler_options`も合わせて変更しています．

## 動作確認

Daskのコードの書き方に変更はありません．例えば，次のコードが正常に動けば成功です．

```python
import dask.array as da

x = da.random.random((100000, 100000, 10), chunks=(1000, 1000, 5))
y = da.random.random((100000, 100000, 10), chunks=(1000, 1000, 5))
z = (da.arcsin(x) + da.arccos(y)).sum(axis=(1, 2))
z.compute()

```
