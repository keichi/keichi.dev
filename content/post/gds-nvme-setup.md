---
title: GPUDirect Storageの環境構築 (ローカルNVMe, Rocky Linux使用)
date: 2025-08-22T15:43:20+09:00
description:
tags: []
---

Rocky Linux 8.10のGPUサーバにGPUDirect Storage (GDS) の環境を構築した際のメモです。
公式の[ドキュメント](https://docs.nvidia.com/gpudirect-storage/troubleshooting-guide/index.html)
にインストール手順は書いてあるのですが、手順や要件が色々散らばっていて読みづらかったので、自分用にまとめました。
ローカルのNVMeでの検証が目的のため、Lustreなどリモートファイルシステムは試していません。

## IOMMUを無効化する

IOMMUが有効になっていれば、カーネルコマンドラインパラメータを変更して無効化する。
今回使用したサーバでは既に無効になっていたので、手順は省略する。

## CUDA ToolkitとNVIDIAドライバのインストール

CUDA Toolkitをインストールする。

```
sudo dnf config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/rhel8/x86_64/cuda-rhel8.repo
sudo dnf clean all
sudo dnf -y install cuda-toolkit-13-0
```

オープンソース版のNVIDIAドライバをインストールする。

```
sudo dnf -y module install nvidia-driver:open-dkms
```

もしプロプライエタリ版ドライバをインストールしていれば、オープンソース版へ切り替えが必要となる。

## OFEDのインストール

GDS用にパッチされたNVMeドライバをインストールする。(カーネルでPCI P2P DMA機能が利用可能であれば
標準のNVMeドライバを使えるらしいが、カーネル6.2以上かつP2P DMA機能を有効にしてコンパイルされている
必要がある)

GDS対応NVMeドライバはなぜかNVIDIA MLNX_OFEDに含まれているので、MLNX_OFEDをダウンロード・展開し、
インストーラでインストールする。事前にドライバをコンパイルする際に必要なパッケージをインストールしておく。

```
sudo yum install -y kernel-rpm-macros kernel-modules-extra kernel-devel-$(uname -r)
sudo ./mlnxofedinstall --with-nvmf --with-nfsrdma --add-kernel-support --skip-repo
```

NVMeのドライバはinitramfsに含まれているので、initramfsを再生成し再起動する。

```
sudo dracut -f
sudo reboot
```

## GPUDirect Storageのインストール

GDSをインストールする。なお`nvidia-fs`というドライバがDKMSでビルドされるのだが、特にエラーメッセージ
もなくインストールされないことがあった。再インストールで解消した。

```
sudo dnf -y install nvidia-gds
```

## NVMeの準備

ブロックデバイスのファイルシステムとしては、XFSまたはEXT4に対応しているので、いずれかでNVMeを
フォーマットし、マウントする。なお、EXT4の場合はジャーナリングモードをorderedに設定してマウントする必要がある。

```
sudo mount -o data=ordered /dev/nvme0n1 /mnt
```

## 動作確認

まずドライバやライブラリがインストールされているか、GDSに同梱されているgdskcheckというツールで確認する。
以下のようにDriver ConfigurationにおいてNVMeがSupportedになっていればインストールは成功。

```
/usr/local/cuda/gds/tools/gdscheck -p
GDS release version: 1.15.0.42
 nvidia_fs version:  2.26 libcufile version: 2.12
 Platform: x86_64
 ============
 ENVIRONMENT:
 ============
 =====================
 DRIVER CONFIGURATION:
 =====================
 NVMe P2PDMA        : Unsupported
 NVMe               : Supported
 NVMeOF             : Unsupported
 SCSI               : Unsupported
 ScaleFlux CSD      : Unsupported
 NVMesh             : Unsupported
 DDN EXAScaler      : Unsupported
 IBM Spectrum Scale : Unsupported
 NFS                : Unsupported
 BeeGFS             : Unsupported
 ScaTeFS            : Unsupported
 WekaFS             : Unsupported
 Userspace RDMA     : Unsupported
 --Mellanox PeerDirect : Disabled
 --rdma library        : Not Loaded (libcufile_rdma.so)
 --rdma devices        : Not configured
 --rdma_device_status  : Up: 0 Down: 0
...
==============
 PLATFORM INFO:
 ==============
 IOMMU: disabled
 Nvidia Driver Info Status: Supported(Nvidia Open Driver Installed)
 Cuda Driver Version Installed:  13000
 Platform: AS -4124GS-TNR, Arch: x86_64(Linux 4.18.0-553.69.1.el8_10.x86_64)
 Platform verification succeeded
```

次に実際にGDSを用いて正しくI/Oできるか確認する。ddでNVMe上にテストファイルを生成する。

```
dd if=/dev/urandom of=/scratch/keichi/gds-test-1G bs=1M count=1024
```

同梱のgdsio_verifyというツールを用い、GDSでI/Oを実行する。

```
/usr/local/cuda/gds/tools/gdsio_verify -d 0 -f /scratch/keichi/gds-test-1G -n 1 -s 1G
gpu index :0,file :/scratch/keichi/gds-test-1G, gpu buffer alignment :0, gpu buffer offset :0, gpu devptr offset :0, file offset :0, io_requested :1073741824, io_chunk_size :1073741824, bufregister :true, sync :1, nr ios :1,
fsync :0,
Batch mode: 0
Data Verification Success
```

Data Verification Successと出力されているので、破損なしに読み込みできたことがわかる。

## 性能比較

これも同梱のgdsioというツールで簡単なベンチマークを実行できる。
以下はシーケンシャルリード、8スレッド、I/Oサイズ1 MiB、ファイルサイズ1 GiBの条件での実行例。
なお、最適なハードウェア構成ではなため性能値は参考になならない。

NVMe -> GPU

```
/usr/local/cuda/gds/tools/gdsio -D /scratch/keichi/gdsio -w 8 -d 0 -I 0 -x 0 -s 1G -i 1M
IoType: READ XferType: GPUD Threads: 8 DataSetSize: 8363008/8388608(KiB) IOSize: 1024(KiB) Throughput: 6.816723 GiB/sec, Avg_Latency: 1138.933194 usecs ops: 8167 total_time 1.170003 secs
```

NVMe -> CPU

```
/usr/local/cuda/gds/tools/gdsio -D /scratch/keichi/gdsio -w 8 -d 0 -I 0 -x 1 -s 1G -i 1M
IoType: READ XferType: CPUONLY Threads: 8 DataSetSize: 8359936/8388608(KiB) IOSize: 1024(KiB) Throughput: 6.844410 GiB/sec, Avg_Latency: 1134.363057 usecs ops: 8164 total_time 1.164842 secs
```

NVMe -> CPU -> GPU

```
/usr/local/cuda/gds/tools/gdsio -D /scratch/keichi/gdsio -w 8 -d 0 -I 0 -x 2 -s 1G -i 1M
IoType: READ XferType: CPU_GPU Threads: 8 DataSetSize: 8368128/8388608(KiB) IOSize: 1024(KiB) Throughput: 6.808443 GiB/sec, Avg_Latency: 1140.044948 usecs ops: 8172 total_time 1.172143 secs
```
