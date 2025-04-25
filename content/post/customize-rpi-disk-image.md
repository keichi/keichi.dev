---
title: x64ホストでRaspberryPiのディスクイメージをカスタマイズする
date: 2025-04-24T09:20:21+09:00
description:
tags: []
---

RasPiのディスクイメージをPCでカスタマイズしたいとき，QEMUのユーザモードエミュレーションを用いると
手軽に実現できることができます．

以前自作した[ツール](https://github.com/keichi/pi-oven)ではRasPiのルートファイルシステムに入るために
chrootを用いていたのですが， systemd-nspawnを用いるとさらに手順を減らせる事がわかったので，
以下にメモしておきます．なお作業にはUbuntu 22.04を使用しています．

## ディスクイメージのカスタマイズ

RasPi OSのイメージをダウンロードして展開します．

```
$ wget https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2024-11-19/2024-11-19-raspios-bookworm-arm64-lite.img.xz
$ unxz 2024-11-19-raspios-bookworm-arm64-lite.img.xz
```

必要なパッケージをインストールします．

```
$ sudo apt intall -y qemu-user-static kpartx systemd-container
```

`kpartx`を用いてイメージ内の各パーティションをループバックマウントします．以下の例では `loop3p*`
というのがループバックデバイス名です．

```
$ sudo kpartx -av 2024-11-19-raspios-bookworm-arm64-lite.img
add map loop3p1 (252:1): 0 1048576 linear 7:3 8192
add map loop3p2 (252:2): 0 4325376 linear 7:3 1056768
```

マウントポイントを作成し，ループバックデバイスをマウントします．

```
$ sudo mkdir -p /mnt/rpi5
$ sudo mount /dev/mapper/loop3p2 /mnt/rpi5
$ sudo mount /dev/mapper/loop3p1 /mnt/rpi5/boot/firmware
```

`systemd-nspawn`を用いてRasPiのルートファイルシステム内に入ります．bashが起動するので，その中で
設定の修正やパッケージのインストールなどのカスタマイズ作業を行います．

```
$ sudo systemd-nspawn -D /mnt/rpi5
```

systemdが必要な場合は，以下の通り`-b`オプション付きで起動します．
事前に`passwd`でアカウントのパスワードを設定しておく必要があります．

```
$ sudo systemd-nspawn -b -D /mnt/rpi5
```

作業が終わったら，ファイルシステムをアンマウントしてループバクデバイスを削除します．

```
$ sudo umount /mnt/rpi5/boot/firmware
$ sudo umount /mnt/rpi5
$ sudo kpartx -dv 2024-11-19-raspios-bookworm-arm64-lite.img
```

## ルートファイルシステムの拡張

提供されているディスクイメージはほとんど空き容量がないため，パッケージを色々インストールしようとすると
容量が不足します．その場合は，以下の手順でルートファイルシステムを拡張することができます．

```
$ sudo apt intall -y parted
```

ディスクイメージファイルのサイズを拡張します (ここでは5GiB)．

```
$ fallocate -l 5G 2024-11-19-raspios-bookworm-arm64-lite.img
```

ルートファイルシステムである2番目のパーティションを最大まで拡張します．

```
$ parted 2024-11-19-raspios-bookworm-arm64-lite.img resizepart 2 100%
```

パーティションをループバックマウントします．

```
$ sudo kpartx -av 2024-11-19-raspios-bookworm-arm64-lite.img
```

最後にファイルシステムを拡張します．

```
$ sudo e2fsck -f /dev/mapper/loop3p2
$ sudo resize2fs /dev/mapper/loop3p2
```
