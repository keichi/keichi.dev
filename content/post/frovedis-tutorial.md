---
title: "WIP: Vector Engine向け機械学習フレームワークFrovedis入門"
date: 2022-08-08T14:50:07+09:00
description:
tags: []
---

## インストール方法

Frovedisの[GitHubリポジトリ](https://github.com/frovedis/frovedis/releases)
では，CentOS 7および8用のRPMパッケージが提供されているので，
これらを使用すると簡単にインストールできます．
以下では，CentOS 7を仮定して説明します．

まず，Vector EngineのランタイムとNEC MPIがインストールされていることを確認します．
この記事で用いるFrovedis 1.1.1の場合は，NEC MPI 2.20.0以上が必要です．
また，EPELリポジトリとPython 3がインストールされていなければ，インストールします．

```
$ sudo yum install -y epel-release && sudo yum update -y
$ sudo yum install -y python3
```

GitHubからFrovedis 1.1.1のRPMパッケージをダウンロードし，インストールします．

```
$ sudo yum install -y https://github.com/frovedis/frovedis/releases/download/v1.1.1/frovedis-1.1.1-1.el7.x86_64.rpm
```

FrovedisのPythonインターフェースが依存するパッケージをインストールします．
scikit-learnは必須ではありませんが，Frovedisがscikit-learn互換の
インターフェースを提供している以上，インストールしておくと便利です．
必要に応じてvirtualenv上にインストールしてください．

```
$ pip3 install --user scipy pandas scikit-learn
```

## Pythonインターフェースの使用

まず，Frovedisに付属するシェルスクリプトを読み込み，Frovedisを使用するための環境変数を設定します．

```
$ source /opt/nec/frovedis/ve/bin/veenv.sh
```

Pythonインタプリタを起動します．

```
$ python3
```

まず，Frovedis Serverを起動します．Frovedis ServerはVector Engine上で動作し，
実際の計算処理を担うプログラムです．Frovedis ServerはMPI並列化されており，
複数VEに渡って動作させることも可能ですが，ここでは，1VE 8プロセスで起動します．

```python
import os
from frovedis.exrpc.server import FrovedisServer

FrovedisServer.initialize("mpirun -np 8 {}".format(os.environ['FROVEDIS_SERVER']))
```

CPU上でテストデータを生成します．ここでは，100次元の特徴量を持つデータ点を
10万点生成します．

```python
from sklearn.datasets import make_classification

X, y = make_classification(n_samples=100000, n_features=100)
```

ここでは，
ロジスティック回帰を行うクラス `frovedis.mllib.linear_model.LogisticRegression`
を用いて，データを分類してみます．このクラスは，scikit-learnの[同名のクラス](https://scikit-learn.org/stable/modules/generated/sklearn.linear_model.LogisticRegression.html)と同じインターフェースを持っています．
なお，他に実装されているアルゴリズムは，[ここ](https://github.com/frovedis/frovedis/blob/master/doc/tutorial_python/tutorial_python.md#4-machine-learning-algorithms)に列挙されています．


```python
from frovedis.mllib.linear_model import LogisticRegression

lr = LogisticRegression()
lr.fit(X, y)
```

下記を実行すると，回帰係数が表示されます．

```
lr.coef_
```

Pythonインタプリタを終了する前に，Frovedis Serverを終了します．

```python
FrovedisServer.shut_down()
```
