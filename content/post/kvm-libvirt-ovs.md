+++
date = "2015-10-22T23:14:18+09:00"
title = "CentOS 7でKVM + libvirt + Open vSwitchな仮想化環境のつくり方"

+++

CentOS 7上でのKVM、libvirt、Open vSwitchを使った仮想化環境のつくり方について
メモしておく。目指す構成は下の画像の通り。ゲストOSは`192.168.100.0/24`の
ネットワークで、NATでホスト外のネットワークに出ることができる。

![](/images/kvm_ovs_network.png)

<!--more-->

## ホストOSのインストール

CentOS 7をminimal構成でインストールする。この際、LVMのパーティションを1つ
余分に作っておく。 (ここでは`/dev/sda3`) このパーティションは、libvirtの
LVMストレージプールにするため。

```bash
$ fdisk -l
Device      Boot    Start         End      Blocks   Id  System
/dev/sda1     *      2048     1026047      512000   83  Linux    # /boot
/dev/sda2         1026048   839886847   419430400   83  Linux    # /, /home
/dev/sda3       839886848  1953103871   556608512   83  Linux    # ストレージプール
```

```
$ df -h
Filesystem               Size  Used Avail Use% Mounted on
/dev/mapper/centos-root   50G  1.9G   49G   4% /
devtmpfs                  48G     0   48G   0% /dev
tmpfs                     48G     0   48G   0% /dev/shm
tmpfs                     48G   17M   48G   1% /run
tmpfs                     48G     0   48G   0% /sys/fs/cgroup
/dev/mapper/centos-home  150G   33M  150G   1% /home
/dev/sda1                497M  162M  335M  33% /boot
```

KVM、libvirt、Open vSwitchをインストールする。Open vSwitchはCentOS 7のbase
リポジトリに入っていないので、RDOリポジトリ (本来はOpenStackのインストール
に使う) からインストールする。

```bash
$ yum update
$ yum install https://rdo.fedorapeople.org/openstack/openstack-kilo/rdo-release-kilo.rpm
$ yum install qemu-kvm libvirt virt-install openvswitch
$ systemctl start libvirtd
$ systemctl start openvswitch
```

## ホストOSのネットワーク設定

ゲストOSのためのブリッジをOVSで作成する。`ovs-vsctl add-br ovsbr0`で作成できる
が、永続化のために下記スクリプトを作成する。`ZONE=trusted`は後のfirewalldの
設定のため。

```text
# vim /etc/sysconfig/network-scripts/ifcfg-ovsbr0
DEVICE=ovsbr0
ONBOOT=yes
DEVICETYPE=ovs
TYPE=OVSBridge
BOOTPROTO=static
IPADDR=192.168.100.1
NETMASK=255.255.255.0
HOTPLUG=no
ZONE=trusted
```

作成したOVSをlibvirtに登録する。

```xml
<network>
  <name>ovsbr0</name>
  <forward mode='bridge'/>
  <bridge name='ovsbr0'/>
  <virtualport type='openvswitch'/>
</network>
```

上記XMLファイルを`ovsbr0.xml`という名前で保存した後、libvirtのデフォルトの
ネットワークを削除してovsbr0を登録する。

```bash
$ virsh net-destroy default
$ virsh net-autostart default --disable
$ virsh net-define ovsbr0.xml
$ virsh net-start ovsbr0
$ virsh net-autostart ovsbr0
```

ゲストOSからホストOSの外のネットワークに出られるようにNATを設定する。まず、
カーネルでパケット転送を有効にする。次に、ovsbr0をtrustedゾーンに追加し、
ゲストOSからのパケットを全て許可する。最後にpublicゾーンにIPマスカレードを
追加し、NATを有効にする。

```bash
$ sysctl -w net.ipv4.ip_forward=1
$ echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
$ firewall-cmd --zone=trusted --add-interface=ovsbr0
$ firewall-cmd --zone=public --add-masquerade
$ firewall-cmd --zone=public --add-masquerade --permanent
```

ゲストOSからDHCPとDNSを使えるように設定する。

```bash
# vim /etc/dnsmasq.conf
listen-address=192.168.100.1
dhcp-range=192.168.100.2,192.168.100.150,255.255.255.0,12h
systemctl enable dnsmasq
systemctl start dnsmasq
```

## ストレージプールの設定

ここでは、/dev/sda3に作ったLVM VGをストレージプールとして使用する。PVのみ
手動で作成し、VGはlibvirtにつくらせる。

```bash
$ pvcreate /dev/sda3
$ virsh pool-define-as vmpool logical - - /dev/sda3 vmpool /dev/vmpool
$ virsh pool-autostart vmpool
$ virsh pool-start vmpool
```

ストレージプールに、ボリュームを作成する。このボリュームはLVとして作成される。

```
$ virsh vol-create vmpool vmdisk1 10G
```

## ゲストOSのインストール

`virt-install`を使ってゲストOSをインストールする。`--disk`オプションで先に
作成したボリュームを指定し、`--network`オプションで先に作成したOVSブリッジを
使ったネットワークを指定する。ここでは、CentOS 7をテキストモードで
ネットワークインストールしている。
仮想ブリッジovsbr0に接続したtapデバイスは自動的に作成される。

```bash
$ virt-install --connect qemu:///system --name vm1 --ram=2048 \
    --vcpus=1 --disk /dev/vmpool/vmdisk1 --os-type=linux
    --os-variant rhel7 --hvm --accelerate --nographics \
    --extra-args="text console=tty0 console=ttyS0,115200" --autostart \
    --location http://ftp.riken.jp/Linux/centos/7/os/x86_64 --network network=ovsbr0
```

