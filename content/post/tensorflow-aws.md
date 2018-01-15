---
title: "TensorFlow r0.10 on AWS"
date: "2016-09-27T00:22:25+09:00"
---

最近TensorFlowで深層学習の勉強をしているが、手持ちのMac Book Pro Retina 13-inch
だとチュートリアルの時点で既に学習が遅すぎて辛いので、AWSでGPUインスタンスを
借り、その上でTensorFlowを動かしてみることにした。以下にTensorFlow r0.10をAWS上
でGPUを使って動かすまでの手順をメモしておく。CUDA Toolkitが元々入っている
NVIDIAのAMIを使い、TensorFlowはビルド済みのバイナリを用いることで、できるだけ
手間のかからない方法を目指した。

AWS MarketplaceでAmazon Linux AMI with NVIDIA GRID GPU Driverを選択して
g2.2xlarge (g2.8xlarge) インスタンスを作成する。なお、私の環境ではg2.2xlarge
インスタンスの起動制限が0台になっていたので、サポートに連絡して制限を緩和して
もらった。ちなみに東京リージョンよりもバージニアやオレゴンの方が安いので
おすすめ。

<!--more-->

まず、環境変数をいくつか設定する。

```bash
# vim ~/.bash_profile
$ export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/opt/nvidia/cuda/lib64:/opt/nvidia/cuda/extras/CUPTI/lib64"
$ export CUDA_HOME=/opt/nvidia/cuda
```

次にcuDNNをインストールする。インストールするのはcuDNN v5.1 for CUDA 7.5。他の
バージョンだと動かない。

```bash
$ wget https://developer.nvidia.com/compute/machine-learning/cudnn/secure/v5.1/prod/7.5/cudnn-7.5-linux-x64-v5.1-tgz
$ tar xzvf cudnn-7.5-linux-x64-v5.1.tgz
$ sudo cp cuda/include/cudnn.h /opt/nvidia/cuda/include
$ sudo cp cuda/lib64/libcudnn* /opt/nvidia/cuda/lib64
$ sudo chmod a+r /opt/nvidia/cuda/include/cudnn.h /opt/nvidia/cuda/lib64/libcudnn*
```

Python 3.5をインストールする。yumで入れられるpythonは3.4だったので、ソースから
ビルドする。Anaconda, pyenv, pythonzなど好みの方法で入れれば良いと思う。

```bash
$ sudo yum install zlib-devel bzip2-devel openssl-devel readline-devel ncurses-devel sqlite-devel gdbm-devel db4-devel expat-devel libpcap-devel xz-devel pcre-devel
$ curl https://www.python.org/ftp/python/3.5.2/Python-3.5.2.tgz | tar xzvf -
$ cd Python-3.5.2/
$ ./configure --prefix=/usr/local
$ make
$ sudo make install
```

上記の方法だとpythonのバイナリは`/usr/local/bin`に配置されるので、sudoが
`/usr/local/bin`のバイナリを読めるようにする。

```
# sudo visudo
Defaults    secure_path = /sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin
```

TensorFlowをインストールする。ここではpipから`Ubuntu/Linux 64-bit, GPU enabled, Python 3.5`
をインストールする。必要な人はanacondaやvirtualenvなどでつくった隔離環境の中で
インストールすれば良いと思う。

```bash
$ export TF_BINARY_URL=https://storage.googleapis.com/tensorflow/linux/gpu/tensorflow-0.10.0-cp35-cp35m-linux_x86_64.whl
$ pip3 install --upgrade $TF_BINARY_URL
```

TensorFlowがインストールできたか確認。

```bash
$ python3 -c 'import os; import inspect; import tensorflow; print(os.path.dirname(inspect.getfile(tensorflow)))'''
```

MNISTのサンプルを動かしてみる。1ミニバッチあたり20ms程度で学習できた。

```bash
$ python3 -m tensorflow.models.image.mnist.convolutional
I tensorflow/stream_executor/dso_loader.cc:108] successfully opened CUDA library libcublas.so locally
I tensorflow/stream_executor/dso_loader.cc:108] successfully opened CUDA library libcudnn.so locally
I tensorflow/stream_executor/dso_loader.cc:108] successfully opened CUDA library libcufft.so locally
I tensorflow/stream_executor/dso_loader.cc:108] successfully opened CUDA library libcuda.so.1 locally
I tensorflow/stream_executor/dso_loader.cc:108] successfully opened CUDA library libcurand.so locally
Extracting data/train-images-idx3-ubyte.gz
Extracting data/train-labels-idx1-ubyte.gz
Extracting data/t10k-images-idx3-ubyte.gz
Extracting data/t10k-labels-idx1-ubyte.gz
I tensorflow/stream_executor/cuda/cuda_gpu_executor.cc:925] successful NUMA node read from SysFS had negative value (-1), but there must be at least one NUMA node, so returning NUMA node zero
I tensorflow/core/common_runtime/gpu/gpu_init.cc:102] Found device 0 with properties:
name: GRID K520
major: 3 minor: 0 memoryClockRate (GHz) 0.797
pciBusID 0000:00:03.0
Total memory: 4.00GiB
Free memory: 3.95GiB
I tensorflow/core/common_runtime/gpu/gpu_init.cc:126] DMA: 0
I tensorflow/core/common_runtime/gpu/gpu_init.cc:136] 0:   Y
I tensorflow/core/common_runtime/gpu/gpu_device.cc:838] Creating TensorFlow device (/gpu:0) -> (device: 0, name: GRID K520, pci bus id: 0000:00:03.0)
Initialized!
Step 0 (epoch 0.00), 6.7 ms
Minibatch loss: 12.054, learning rate: 0.010000
Minibatch error: 90.6%
Validation error: 84.6%
Step 100 (epoch 0.12), 20.9 ms
Minibatch loss: 3.294, learning rate: 0.010000
Minibatch error: 4.7%
Validation error: 7.3%
Step 200 (epoch 0.23), 20.6 ms
Minibatch loss: 3.466, learning rate: 0.010000
Minibatch error: 10.9%
Validation error: 4.0%
Step 300 (epoch 0.35), 20.7 ms
Minibatch loss: 3.216, learning rate: 0.010000
Minibatch error: 6.2%
Validation error: 3.3%
Step 400 (epoch 0.47), 20.6 ms
Minibatch loss: 3.217, learning rate: 0.010000
Minibatch error: 7.8%
Validation error: 2.9%
...
Step 8400 (epoch 9.77), 20.6 ms
Minibatch loss: 1.596, learning rate: 0.006302
Minibatch error: 0.0%
Validation error: 0.7%
Step 8500 (epoch 9.89), 20.6 ms
Minibatch loss: 1.632, learning rate: 0.006302
Minibatch error: 3.1%
Validation error: 0.9%
Test error: 0.8%
```
