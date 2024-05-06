---
title: RAIDストレージをオンラインで拡張した際のメモ
date: 2024-03-08T22:59:43+09:00
description:
tags: []
---

現在所属している研究室では数十台程度の計算サーバを運用しており，各計算サーバではNFSサーバの領域を
ホームディレクトリとしてマウントして共有しています．
NFSサーバはDELLのラックサーバで，6TBのHDD 8本をRAID 1+0の構成で冗長化し，実効容量約20TBの
ストレージとして構成していました．空き容量が少なくなってきたので，
今回，6TBのHDD 8本を20TBのHDD 8本に換装し，計80TBに容量を増強しました．

このNFSサーバを止めると全ての計算サーバが使用不可能になるので，オンラインで容量を拡張しました．
今後再び容量を拡張する場合に備えて，以下に手順の記録を残しておきます．

## HDDの換装

まずRAIDの構成方法を調べたところ，PERC H730 MiniというRAIDコントローラでハードウェアRAIDを
構成していることがわかりました．このRAIDコントローラperccliというツールで制御できるので，
このツールをインストールしておきます．

RAID 1+0なので異なるRAID 1ペアのHDDは同時に交換できるはずですが，万が一トラブルが発生した場合を
考えて，1本ずつ交換することにします．HDDを交換する際には，まず交換するHDDをperccliで停止します．
(以下はスロット#7を交換する場合)

```
$ sudo /opt/MegaRAID/perccli/perccli64 /c0/e32/s7 set offline
```

その後新しいHDDを装着すると，自動的にRAIDに組み込まれ，リビルドが走ります．以下のコマンドでリビルド状況を
確認できるので，リビルドが成功したことを確認してから次のHDDを交換します．

```
$ sudo /opt/MegaRAID/perccli/perccli64 /c0 /e32 /s7 show rebuild
Controller = 0
Status = Success
Description = Show Drive Rebuild Status Succeeded.


-----------------------------------------------------
Drive-ID   Progress% Status      Estimated Time Left
-----------------------------------------------------
/c0/e32/s7        14 In progress -
-----------------------------------------------------
```

## RAIDボリュームの拡張

全てのHDDが交換できたら，RAIDボリュームの拡張を行います．

```
$ sudo /opt/MegaRAID/perccli/perccli64 /c0/v0 show expansion
Controller = 0
Status = Success
Description = None


EXPANSION INFORMATION :
=====================

--------------------------------------------
VD      Size OCE NoArrExp WithArrExp Status
--------------------------------------------
 0 21.830 TB Y   -        58.207 TB  -
--------------------------------------------

OCE - Online Capacity Expansion | WithArrExp - With Array Expansion
NoArrExp - Without Array Expansion
```

58.207TBの容量を追加できることがわかったので，RAIDボリュームの拡張を実行します．

```
$ sudo /opt/MegaRAID/perccli/perccli64 /c0/v0 expand Size=58.207TB expandarray
Controller = 0
Status = Success
Description = expansion operation succeeded


EXPANSION RESULT :
================

--------------------------------------------------------------------
VD      Size FreSpc    ReqSize   AbsUsrSz  %FreSpc NewSize   Status
--------------------------------------------------------------------
 0 21.830 TB 58.207 TB 58.206 TB 58.207 TB     100 80.037 TB -
--------------------------------------------------------------------

Size - Current VD size|FreSpc - Freespace available before expansion
%FreSpc - Requested expansion size in % of available free space
AbsUsrSz - User size rounded to nearest %
```

拡張が成功したので，ボリュームの情報を表示すると容量が80.037TBに増えていることがわかります．

```
$ sudo /opt/MegaRAID/perccli/perccli64 /c0/v0 show
Controller = 0
Status = Success
Description = None


Virtual Drives :
==============

---------------------------------------------------------------------
DG/VD TYPE   State Access Consist Cache Cac sCC      Size Name
---------------------------------------------------------------------
0/0   RAID10 Optl  RW     No      RWTD  -   ON  80.037 TB VirtualHDD
---------------------------------------------------------------------

Cac=CacheCade|Rec=Recovery|OfLn=OffLine|Pdgd=Partially Degraded|dgrd=Degraded
Optl=Optimal|RO=Read Only|RW=Read Write|HD=Hidden|B=Blocked|Consist=Consistent|
R=Read Ahead Always|NR=No Read Ahead|WB=WriteBack|
AWB=Always WriteBack|WT=WriteThrough|C=Cached IO|D=Direct IO|sCC=Scheduled
Check Consistency
```

## パーティションの拡張

次にパーティションを拡張します．以下のコマンドでOSが認識しているHDDの容量を更新します．

```
$ sudo rescan-scsi-bus.sh
```

現在のパーティションの情報を確認できます．

```
$ sudo fdisk -l
WARNING: fdisk GPT support is currently new, and therefore in an experimental phase. Use at your own discretion.

Disk /dev/sda: 88001.7 GB, 88001732411392 bytes, 171878383616 sectors
Units = sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 4096 bytes
I/O size (minimum/optimal): 4096 bytes / 4096 bytes
Disk label type: gpt
Disk identifier: 33958C21-E328-4C0E-AC9C-1CAB1B496029


#         Start          End    Size  Type            Name
 1         2048       411647    200M  EFI System      EFI System Partition
 2       411648      1435647    500M  Microsoft basic
 3      1435648  46879733759   21.8T  Linux LVM
```

3番のパーティションの容量を拡張します．ここではgrowpartを使って拡張します．

```
$ sudo growpart /dev/sda 3
CHANGED: partition=3 start=1435648 old: size=46878298112 end=46879733760 new: size=171876947934 end=171878383582
```

これでディスク上のパーティションテーブルは更新されていますが，OSが保持しているパーティションテーブル
が更新されていないので，以下のコマンドで更新させます．

```
$ sudo partprobe
```

再びパーティションの情報を確認すると，3番が80TBまで増えていることがわかります．

```
$ sudo fdisk -l
WARNING: fdisk GPT support is currently new, and therefore in an experimental phase. Use at your own discretion.

Disk /dev/sda: 88001.7 GB, 88001732411392 bytes, 171878383616 sectors
Units = sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 4096 bytes
I/O size (minimum/optimal): 4096 bytes / 4096 bytes
Disk label type: gpt
Disk identifier: 33958C21-E328-4C0E-AC9C-1CAB1B496029


#         Start          End    Size  Type            Name
 1         2048       411647    200M  EFI System      EFI System Partition
 2       411648      1435647    500M  Microsoft basic
 3      1435648 171878383581     80T  Linux LVM
```

## LVMボリュームの拡張

このシステムではLVMを使っているので，次にLVを拡張します．以下のように/homeとしてマウントしている
LVを拡張します．

```
$ lsblk
NAME                         MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda                            8:0    0   80T  0 disk
├─sda1                         8:1    0  200M  0 part /boot/efi
├─sda2                         8:2    0  500M  0 part /boot
└─sda3                         8:3    0   80T  0 part
  ├─centos-root              253:0    0   50G  0 lvm  /
  ├─centos-swap              253:1    0 15.7G  0 lvm  [SWAP]
  └─centos-home              253:2    0 21.8T  0 lvm  /home
sr0                           11:0    1 1024M  0 rom
loop0                          7:0    0  100G  0 loop
└─docker-253:0-67282893-pool 253:3    0  100G  0 dm
loop1                          7:1    0    2G  0 loop
└─docker-253:0-67282893-pool 253:3    0  100G  0 dm
```

PVの情報を確認します．

```
$ sudo pvs
  PV         VG     Fmt  Attr PSize   PFree
  /dev/sda3  centos lvm2 a--  <21.83t 64.00m
```

PVを拡張します．

```
$ sudo pvresize /dev/sda3
  Physical volume "/dev/sda3" changed
  1 physical volume(s) resized or updated / 0 physical volume(s) not resized
```

PVが計80GBまで増えました．

```
$ sudo pvs
  PV         VG     Fmt  Attr PSize   PFree
  /dev/sda3  centos lvm2 a--  <80.04t <58.21t
```

LVの状況を確認します．

```
$ sudo lvs
  LV   VG     Attr       LSize   Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
  home centos -wi-ao---- <21.77t
  root centos -wi-ao----  50.00g
  swap centos -wi-ao---- <15.69g
```

/の容量が今後不足するかもしれないので，ついでに100GBに拡張しておきます．


```
$ sudo lvextend -L 100GB /dev/centos/root
  Size of logical volume centos/root changed from 50.00 GiB (12800 extents) to 100.00 GiB (25600 extents).
  Logical volume centos/root successfully resized.
```

/homeの容量を拡張します．

```
$ sudo lvextend -L 79TB /dev/centos/home
  Size of logical volume centos/home changed from <21.77 TiB (5705616 extents) to 79.00 TiB (20709376 extents).
```

無事にLVを拡張できました．

```
$ sudo lvs
  LV   VG     Attr       LSize   Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
  home centos -wi-ao----  79.00t
  root centos -wi-ao---- 100.00g
  swap centos -wi-ao---- <15.69g
```

## ファイルシステムの拡張

最後に，ファイルシステムの容量を拡張します．XFSを使用しているので，`xfs_growfs`で拡張します．

```
$ sudo xfs_growfs /dev/mapper/centos-root
meta-data=/dev/mapper/centos-root isize=256    agcount=4, agsize=3276800 blks
         =                       sectsz=4096  attr=2, projid32bit=1
         =                       crc=0        finobt=0 spinodes=0
data     =                       bsize=4096   blocks=13107200, imaxpct=25
         =                       sunit=0      swidth=0 blks
naming   =version 2              bsize=4096   ascii-ci=0 ftype=0
log      =internal               bsize=4096   blocks=6400, version=2
         =                       sectsz=4096  sunit=1 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0
data blocks changed from 13107200 to 26214400
```

```
$ sudo xfs_growfs /dev/mapper/centos-home
meta-data=/dev/mapper/centos-home isize=256    agcount=22, agsize=268435455 blks
         =                       sectsz=4096  attr=2, projid32bit=1
         =                       crc=0        finobt=0 spinodes=0
data     =                       bsize=4096   blocks=5842550784, imaxpct=5
         =                       sunit=0      swidth=0 blks
naming   =version 2              bsize=4096   ascii-ci=0 ftype=0
log      =internal               bsize=4096   blocks=521728, version=2
         =                       sectsz=4096  sunit=1 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0
data blocks changed from 5842550784 to 21206401024
```

以上，完全にオンラインでHDDの換装からファイルシステムの拡張まで実現することができました．
