+++
Description = ""
Tags = []
Title = "mpi4pyの紹介"
date = "2017-12-19T23:06:00+09:00"
+++

これは [MPI Advent Calendar 2017](https://adventar.org/calendars/2548)
の21日目の記事です。

<!--more-->

この記事では、MPIのPythonバインディングである
[MPI for Python (mpi4py)](http://mpi4py.scipy.org/) を紹介したいと思います。
mpi4pyは多くのスパコンにプリインストールされており、PythonからMPIを呼ぶ際は、
ほぼこれ一択のようです。
mpi4pyを利用しているアプリケーションの一例として、
PFI/PFNさんの分散深層学習フレームワーク
[ChainerMN](https://github.com/chainer/chainermn) があげられます。

## 基本

pipでインストールできます。
```
$ pip install mpi4py
```

基本的には、MPIの提供する関数を素直にバインディングしています。
下記はHello, worldです:

```python
from mpi4py import MPI

comm = MPI.COMM_WORLD
rank = comm.Get_rank()
size = comm.Get_size()

print(f"Hello, world! from rank {rank} out of {size}")
```

実行は、通常のMPIアプリケーションと同様にmpiexecでokです。

```nohighlight
$ mpiexec -np 4 python3 test.py
Hello, world! from rank 0 out of 4
Hello, world! from rank 2 out of 4
Hello, world! from rank 3 out of 4
Hello, world! from rank 1 out of 4
```

ちなみに、`MPI_Init()`と
`MPI_Finalize()`は、mpi4pyモジュールの初回import時と、プロセス終了時に、
それぞれ自動的に呼ばれています。

## 通信関数

1対1や集団通信などの各種通信関数は、 `MPI.Comm` クラスのメソッド
になっています。
本家MPIとの違いとして、Pythonのオブジェクトをpickle (シリアライズ)
して送る小文字のメソッド
(`send()`, `recv()`, `bcast()` `scatter()`, `gather()`, etc.)
と、バッファを直接送る頭文字が大文字のメソッド
(`Send()`, `Recv()`, `Bcast()` `Scatter()`, `Gather()`, etc.)
の2系統に分かれています。

1対1通信でPythonのオブジェクトを送受信する例:

```python
from mpi4py import MPI

comm = MPI.COMM_WORLD
rank = comm.Get_rank()

if rank == 0:
    req = comm.isend("foo", dest=1, tag=0)
elif rank == 1:
    req = comm.irecv(source=0, tag=0)

req.wait()
```

Pythonのオブジェクトをブロードキャストする例:

```python
from mpi4py import MPI

comm = MPI.COMM_WORLD
rank = comm.Get_rank()

if rank == 0:
    msg = {"a": 123, "b": [456, 789]}
elif rank == 1:
    msg = None

comm.bcast(msg, root=0)
```

1対1通信でnumpyのndarrayを送受信する例:

```python
from mpi4py import MPI
import numpy as np

comm = MPI.COMM_WORLD
rank = comm.Get_rank()


if rank == 0:
    buf = np.arange(100, dtype="float64")
    req = comm.Isend(buf, dest=1, tag=0)
elif rank == 1:
    buf = np.empty(100, dtype="float64")
    req = comm.Irecv(buf, source=0, tag=0)

req.wait()
```

なお、 `numpy.ndarray` 以外にも、組み込み型の `bytes` や標準ライブラリの
`array.array` など、バッファプロトコルを実装している型なら使えます。

numpyのndarrayをバッファをAllreduceする例:

```python
from mpi4py import MPI
import numpy as np


comm = MPI.COMM_WORLD

sendbuf = np.arange(100, dtype="float64")
recvbuf = np.empty(sendbuf.shape, dtype="float64")

comm.Allreduce(sendbuf, recvbuf, MPI.SUM)
```


## マスタ・ワーカ型の並列化

mpi4pyは、 `concurrent.futures.Executor` を継承した `MPIPoolExecutor`
というクラスを提供しています。このクラスを使用すると、
`ThreadPoolExecutor` や `ProcessPoolExecutor` と同様のインターフェースで、
embarassingly parallelな計算を簡単に並列分散化することができます。

```
from mpi4py.futures import MPIPoolExecutor

def compute(x):
    # Some heavy computation
    return x * 2

if __name__ == "__main__":

    with MPIPoolExecutor() as executor:
        image = executor.map(compute, range(100))
```

内部では、MPI-2の動的プロセス作成機能 (`MPI_Comm_spwan()`) を使って
ワーカプロセスを立ち上げているため、MPICHでは下記のコマンドで起動します:

```nohighlight
$ mpiexec -usize 5 -np 1 python3 pool.py
```

Open MPIでは `-usze` の代わりに `OMPI_UNIVERSE_SIZE`
という環境変数を設定すれば良いらしいのですが、
なぜかエラーを吐いて起動できません…本家に
[issue](https://bitbucket.org/mpi4py/mpi4py/issues/88)
を立てたので、何か分かり次第追記します。

## まとめ

MPIのPythonバインディング mpi4py を紹介しました。
ここで紹介した以外にも、片側通信やMPI-IOなど、MPI-1/2/3のほとんどの機能が
ラップされています。
Pythonアプリケーションから手軽にMPIの機能を呼び出したいときに、
ぜひ使ってみてください。
