---
title: NAISTの小規模計算サーバでTensorFlow 2.0を動かす
date: 2020-01-03T00:01:44+09:00
description:
tags: []
---

NAISTには，構成員が無料で利用できる計算用クラスタが設置されており
([参考](https://itcw3.naist.jp/ITC-local/manual/h29computing/document.html))，
NVIDIA Tesla P100を搭載した計算ノードも無料で使用できます．
しかし，準備されているソフトウェア環境が古く，最新のTensorFlowを使用するためには，
Pythonを始めとして多数のソフトウェアを自力でインストールする必要があります．
小規模計算サーバ上でのソフトウェアのインストールには色々と罠があり，
困っている人を見かけたので，ここに手順をまとめておきます．
構築する環境は次の通りです:

- Python 3.7.4
- CUDA 10.0
- cuDNN 7.4
- TensorFlow 2.0.0

小規模計算サーバにソフトウェアをインストールする際の注意点として，計算ノードから
`/home`が見えないことがあります．
ログインノードでは`/home/is/<user>`がホームディレクトリとなりますが，
計算ノードは`/home`をマウントしておらず，`/work/<user>`がホームディレクトリとなります．
そのため，計算ノードで使用するソフトウェアは全て`/work`以下にインストールする
必要があります．また，`.bash_profile`等のシェルの設定ファイルは
`/home/is/<user>`と`/work/<user>`の両方で編集する必要があります．

## Python 3をインストールする

小規模計算サーバにプリインストールされているPythonは，残念ながらPython 2.7のみです．
Python 2のサポートは既に終了し，多くのライブラリもPython 2のサポートを切った
ため ([参考](https://python3statement.org/))，Python 3をインストールします．
Pythonをインストールするには様々な方法がありますが，ここでは
[pyenv](https://github.com/pyenv/pyenv)というPythonのバージョン管理ツールを使用します．
以下ではパスの`keichi`を自分のユーザ名に置き換えてください．

Pyenvのソースコードをcloneします．

```bash
$ git clone https://github.com/pyenv/pyenv.git /work/keichi/.pyenv
```

下記のシェルスクリプトを`/work/keichi/.bash_profile`および
`/home/is/keichi/.bash_profile`
に追記してください．(これらのファイルが存在しなければ新規作成してください)

```bash
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
if command -v pyenv 1>/dev/null 2>&1; then
  eval "$(pyenv init -)"
fi
```

再ログインか`.bash_profile`をsourceしたのち，pyenvを用いてPython 3.7.4をインス
トールします．

```bash
$ pyenv install 3.7.4
```

インストール完了後，Pythonのバージョンが3.7.4になっていることを確認します．

```
$ python --version
Python 3.7.4
```

## CUDAとcuDNNをインストールする

GPU上で計算を行うためのライブラリCUDA，および，DNN計算用ライブラリcuDNNを
インストールします．小規模計算サーバにはCUDA 9.1がプリインストールされています
が，最新のTensorFlowで使うには古いので自分でインストールする必要があります．

必要なCUDAおよびcuDNNのバージョンはTensorFlowのバージョンに依存します．
ここでは，TensorFlow 2.0をインストールすると仮定し，CUDA 10.0およびcuDNN 7.4
をインストールします．異なるバージョンのCUDAとcuDNNでも動く可能性はありま
すが，[TensorFlowの公式ドキュメント](https://www.tensorflow.org/install/source#gpu)
に記載されているバージョンを使用するのが無難だと思います．

### CUDA

[NVIDIAのウェブサイト](https://developer.nvidia.com/cuda-10.0-download-archive)
から，Linux > x86_64 > CentOS > 7 > runfile (local) と進み，CUDA Toolkit
10.0のインストーラをダウンロードします．
ダウンロードにはNVIDIAのデベロッパアカウントが必要です．

ダウンロードしたインストーラを小規模計算サーバのホームディレクトリにscpした後
，起動します．

```bash
$ sh cuda_10.0.130_410.48_linux.run
```

画面の表示に従い，インストールします．`/work`以下にインストールすることに注意
してください．

```text
Do you accept the previously read EULA?
accept/decline/quit: accept

Install NVIDIA Accelerated Graphics Driver for Linux-x86_64 410.48?
(y)es/(n)o/(q)uit: n

Install the CUDA 10.0 Toolkit?
(y)es/(n)o/(q)uit: y

Enter Toolkit Location
 [ default is /usr/local/cuda-10.0 ]: /work/keichi/cuda-10.0

Do you want to install a symbolic link at /usr/local/cuda?
(y)es/(n)o/(q)uit: n

Install the CUDA 10.0 Samples?
(y)es/(n)o/(q)uit: y

Enter CUDA Samples Location
 [ default is /home/is/keichi ]:
```

下記のシェルスクリプトを`/work/keichi/.bash_profile`および
`/home/is/keichi/.bash_profile`の**両方**に追記し，アプリケーションから
CUDAの共有ライブラリが見えるようにします．

```bash
export PATH=/work/keichi/cuda-10.0/bin:$PATH
export LD_LIBRARY_PATH=/work/keichi/cuda-10.0/lib64:$LD_LIBRARY_PATH
```

## cuDNN

[NVIDIAのウェブサイト](https://developer.nvidia.com/rdp/cudnn-archive)
から，cuDNN v7.4.2 (Dec 14, 2018), for CUDA 10.0のcuDNN Library for Linux
をダウンロードします．ダウンロードしたtarボールをscpで小規模計算サーバの
ホームディレクトリにscpし，解凍します．

```bash
$ tar xzvf cudnn-10.0-linux-x64-v7.4.2.24.tgz
```

解凍後のディレクトリから，共有ライブラリとヘッダファイルをCUDAのインストール先
にコピーします．
シンボリックリンクを維持するため，`-a`オプションを付与していることに注意して
ください．

```bash
$ cp -a cuda/lib64/libcudnn* /work/keichi/cuda-10.0/lib64/
$ cp -a cuda/include/cudnn.h /work/keichi/cuda-10.0/include/
```


## TensorFlowをインストールする

pipでTensorFlowをインストールします．
ここで重要なのが，**テンポラリディレクトリをホームディレクトリ上に置く**ことです．
詳細は省きますが，GPFSとSELinuxに起因する問題により，テンポラリディレクトリが
デフォルトの`/tmp`のままだとインストールが途中で失敗します．

```
$ mkdir $HOME/tmp
$ TMPDIR=$HOME/tmp pip install tensorflow-gpu==2.0.0
```

## 動作確認する

以上でTensorFlowおよびその依存関係のインストールは完了です．
TensorFlowでGPUを用いて学習できるか確認します．
Tesla P100を備える超並列演算ノード上でインタラクティブジョブを開始します．

```bash
$ qlogin -q pascal_intr.q
```

下記のPythonスクリプトを`mnist.py`として保存します．
TensorFlowの[公式チュートリアル](https://www.tensorflow.org/tutorials/quickstart/beginner)
と同一の内容です．

```python
import tensorflow as tf

mnist = tf.keras.datasets.mnist

(x_train, y_train), (x_test, y_test) = mnist.load_data()
x_train, x_test = x_train / 255.0, x_test / 255.0

model = tf.keras.models.Sequential([
  tf.keras.layers.Flatten(input_shape=(28, 28)),
  tf.keras.layers.Dense(128, activation='relu'),
  tf.keras.layers.Dropout(0.2),
  tf.keras.layers.Dense(10, activation='softmax')
])

model.compile(optimizer='adam',
              loss='sparse_categorical_crossentropy',
              metrics=['accuracy'])

model.fit(x_train, y_train, epochs=5)

model.evaluate(x_test,  y_test, verbose=2)
```

Pythonスクリプトを起動します．GPUを用いて学習できていることがわかります．

```bash
$ python mnist.py
2019-12-31 11:46:11.853055: I tensorflow/stream_executor/platform/default/dso_loader.cc:44] Successfully opened dynamic library libcuda.so.1
2019-12-31 11:46:13.003245: I tensorflow/core/common_runtime/gpu/gpu_device.cc:1618] Found device 0 with properties:
name: Tesla P100-PCIE-16GB major: 6 minor: 0 memoryClockRate(GHz): 1.3285
pciBusID: 0000:02:00.0
2019-12-31 11:46:13.005592: I tensorflow/core/common_runtime/gpu/gpu_device.cc:1618] Found device 1 with properties:
name: Tesla P100-PCIE-16GB major: 6 minor: 0 memoryClockRate(GHz): 1.3285
pciBusID: 0000:82:00.0
2019-12-31 11:46:13.026804: I tensorflow/stream_executor/platform/default/dso_loader.cc:44] Successfully opened dynamic library libcudart.so.10.0
...中略...
Epoch 1/5
2019-12-31 11:46:18.008094: I tensorflow/stream_executor/platform/default/dso_loader.cc:44] Successfully opened dynamic library libcublas.so.10.0
60000/60000 [==============================] - 5s 89us/sample - loss: 0.2982 - accuracy: 0.9133
Epoch 2/5
60000/60000 [==============================] - 4s 66us/sample - loss: 0.1487 - accuracy: 0.9550
Epoch 3/5
60000/60000 [==============================] - 4s 68us/sample - loss: 0.1102 - accuracy: 0.9664
Epoch 4/5
60000/60000 [==============================] - 4s 67us/sample - loss: 0.0912 - accuracy: 0.9717
Epoch 5/5
60000/60000 [==============================] - 4s 66us/sample - loss: 0.0779 - accuracy: 0.9761
10000/1 - 1s - loss: 0.0369 - accuracy: 0.9782
```

## Jupyter Notebook から使う

最後にJupyter Notebookの使用方法を示します．小規模計算サーバの各計算ノードは
NAISTの`163.221.0.0/16`のアドレスを持っており，学内のネットワークからはファイ
アウォールを介さずアクセスできます．そのため，簡単にJupyter Notebookを使用
できます．

pipでJupyter Notebookをインストールします:
```
$ TMPDIR=$HOME/tmp pip install jupyter
```

Jupyter Notebookのサーバを起動します:
```
$ jupyter-notebook --ip=0.0.0.0
```

起動後のメッセージに表示される`http://h29pascalX.naist.jp:8888/?token=xxxxxx`
というURLを手元のPCのブラウザで開けば，Jupyter Notebookを使用することができま
す．参考までに，TensorFlowのチュートリアルを実行したNotebookを
[ここ](https://gist.github.com/keichi/ebb5f43ef823d0c404d8631db61b1c74)に
貼っておきます．
