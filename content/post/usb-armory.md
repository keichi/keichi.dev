---
title: "超小型シングルボードコンピュータのUSB Armoryがやって来た"
date: "2015-04-01T21:25:46+09:00"
images: ["http://keichi.net/images/usb_armory.jpg"]
---

USB Armoryというガジェットが家に届いた。[USB Armory](http://www.inversepath.com/usbarmory.html)は、[Inverse Path](http://www.inversepath.com/)
というトリエステを拠点とする会社が開発した、シングルボードコンピュータだ。大きさは
一般的なUSBフラッシュメモリと同程度、価格は130USDで、ARM Cortex-A8 800MHz & 512MB DDR3
というハードウェアが手に入る。OSは、Android, Debian, Ubuntu, Arch Linuxなどが
走る。また、ハードウェアとソフトウェアはオープンソースで[公開](https://github.com/inversepath/usbarmory)
されている。

<!--more-->

![USB Armory](/images/usb_armory.jpg)

基本的に何でもできるハードウェアなのだが、特にセキュリティ関係の用途を想定
しているようだ:

- 暗号化、ウィルススキャン、ホスト認証、データ自動削除などの高度な機能を持った
    ストレージ
- OpenSSHクライアントとエージェン
- エンドツーエンド暗号化されたVPN
- ウェブサーバつきのパスワードマネージャ
- ビットコインのウォレット (Electrumが動作確認済み)
- セキュリティトークン

こんなイケてるハードウェアはぜひ試してみるしかない、ということで、早速今年の
1月末に注文した。そして届いたのが今日。早速ログインして遊んでみた。

## 触ってみた

基板の裏側にMicro SDカードのスロットが付いており、ここにOSを焼いたカードを刺す。
今回は、Debianが既にインストールされたMicro SDカードを買った。

```nohighlight
keichi@usbarmory:~$ df -ah
Filesystem      Size  Used Avail Use% Mounted on
rootfs          1.8G  292M  1.5G  17% /
/dev/root       1.8G  292M  1.5G  17% /
devtmpfs        252M     0  252M   0% /dev
tmpfs            51M   76K   51M   1% /run
tmpfs           5.0M     0  5.0M   0% /run/lock
proc               0     0     0    - /proc
sysfs              0     0     0    - /sys
tmpfs           101M     0  101M   0% /run/shm
devpts             0     0     0    - /dev/pts
```

メモリは潤沢にある。
```nohighlight
keichi@usbarmory:~$ free
             total       used       free     shared    buffers     cached
Mem:        515688     118164     397524          0       3760     101024
-/+ buffers/cache:      13380     502308
Swap:            0          0          0
```

今回はDebian WheezyがプリインストールされたMicro SDカードを使った。Debian以外には、
Archのプリビルトイメージが[提供](https://github.com/inversepath/usbarmory/wiki/Available-images)されている。
イメージを自作する方法も丁寧に[解説](https://github.com/inversepath/usbarmory/wiki/Preparing-a-bootable-microSD-image)されている。
```nohighlight
keichi@usbarmory:~$ uname -a
Linux usbarmory 3.18.2 #2 PREEMPT Fri Jan 9 15:17:41 CET 2015 armv7l GNU/Linux
```

どんなプロセスが動いているか調べてみた。`shellinaboxd`というのが見慣れないけど、
これはウェブブラウザで動くターミナルエミュレータらしい。デフォルトでは、ブラウザで
USB Armoryの4300ポートにアクセスすると、ブラウザの中でターミナルが使える。
でも要らないので無効化した。あとcronも動いてるけど、USB Armoryを抜くたびにRTCが
リセットされるので要らないかなあ。
```nohighlight
keichi@usbarmory:~$ ps aux
USER       PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root         1  0.1  0.2   1660  1136 ?        Ss   12:22   0:00 init [2]
root         2  0.0  0.0      0     0 ?        S    12:22   0:00 [kthreadd]
root         3  0.0  0.0      0     0 ?        S    12:22   0:00 [ksoftirqd/0]
root         4  0.0  0.0      0     0 ?        S    12:22   0:00 [kworker/0:0]
root         5  0.0  0.0      0     0 ?        S<   12:22   0:00 [kworker/0:0H]
root         6  0.0  0.0      0     0 ?        S    12:22   0:00 [kworker/u2:0]
root         7  0.0  0.0      0     0 ?        S    12:22   0:00 [rcu_preempt]
root         8  0.0  0.0      0     0 ?        S    12:22   0:00 [rcu_sched]
root         9  0.0  0.0      0     0 ?        S    12:22   0:00 [rcu_bh]
root        10  0.0  0.0      0     0 ?        S    12:22   0:00 [watchdog/0]
root        11  0.0  0.0      0     0 ?        S<   12:22   0:00 [khelper]
root        12  0.0  0.0      0     0 ?        S    12:22   0:00 [kdevtmpfs]
root        13  0.0  0.0      0     0 ?        S    12:22   0:00 [khungtaskd]
root        14  0.0  0.0      0     0 ?        S<   12:22   0:00 [writeback]
root        15  0.0  0.0      0     0 ?        S<   12:22   0:00 [crypto]
root        16  0.0  0.0      0     0 ?        S<   12:22   0:00 [bioset]
root        17  0.0  0.0      0     0 ?        S<   12:22   0:00 [kblockd]
root        18  0.0  0.0      0     0 ?        S    12:22   0:00 [kworker/0:1]
root        19  0.0  0.0      0     0 ?        S    12:22   0:00 [kswapd0]
root        20  0.0  0.0      0     0 ?        S    12:22   0:00 [fsnotify_mark]
root        29  0.0  0.0      0     0 ?        S    12:22   0:00 [irq/17-mmc0]
root        30  0.0  0.0      0     0 ?        S    12:22   0:00 [kworker/u2:1]
root        31  0.0  0.0      0     0 ?        S<   12:22   0:00 [deferwq]
root        32  0.0  0.0      0     0 ?        S    12:22   0:00 [kworker/u2:2]
root        33  0.2  0.0      0     0 ?        S    12:22   0:00 [mmcqd/0]
root        34  0.0  0.0      0     0 ?        S    12:22   0:00 [jbd2/mmcblk0p1-]
root        35  0.0  0.0      0     0 ?        S<   12:22   0:00 [ext4-rsv-conver]
root       148  0.1  0.3   2272  1672 ?        Ss   12:22   0:00 udevd --daemon
root       252  0.0  0.0      0     0 ?        S<   12:22   0:00 [ci_otg]
root       264  0.0  0.2   2268  1532 ?        S    12:22   0:00 udevd --daemon
root       269  0.0  0.2   2268  1532 ?        S    12:22   0:00 udevd --daemon
root      1367  0.0  0.0      0     0 ?        S<   12:22   0:00 [ipv6_addrconf]
root      1481  0.0  0.4  27344  2128 ?        Sl   12:22   0:00 /usr/sbin/rsyslogd -c5
101       1501  0.0  0.4   3712  2304 ?        Ss   12:22   0:00 /usr/bin/shellinaboxd -q --background=/var/run/shellinaboxd.pid -c /var/lib/shellinabox -p 42
root      1502  0.0  0.1   1300   988 ?        Ss   12:22   0:00 startpar -f -- shellinabox
101       1503  0.0  0.2   3712  1284 ?        S    12:22   0:00 /usr/bin/shellinaboxd -q --background=/var/run/shellinaboxd.pid -c /var/lib/shellinabox -p 42
root      1527  0.0  0.2   1828  1300 ?        Ss   12:22   0:00 /usr/sbin/cron
root      1557  0.0  0.4   5136  2548 ?        Ss   12:22   0:00 /usr/sbin/sshd
root      1585  0.0  0.2   1636  1236 ?        Ss+  12:22   0:00 /sbin/getty -L console 115200 vt100
root      1616  0.2  0.7   8160  3732 ?        Ss   12:26   0:00 sshd: keichi [priv]
keichi    1618  0.0  0.5   8160  2636 ?        S    12:26   0:00 sshd: keichi@pts/0
keichi    1619  0.0  0.4   2564  2172 pts/0    Ss   12:26   0:00 -bash
keichi    1627  0.0  0.2   2464  1352 pts/0    R+   12:27   0:00 ps aux
```

## 感想
1時間ほど触ってみた感想は、かなり良い。組み込みLinuxは全然分からない僕のような
人間でも、普段使ってるUbuntuと同じように使える。パフォーマンスもかなり高い
([ベンチマーク](https://github.com/inversepath/usbarmory/wiki/Benchmarks)を見ると、
Raspberry Pi 2よりやや遅いぐらい)ので、ストレスも感じない。
色々面白そうなことができそうなデバイスだけど、何でもできるがゆえに、どんな使い方
をしたらいいか迷ってしまう。とりあえずOpenSSH・GPG・Electrumあたりを入れて
運用してみるか。

ちなみに、このUSB Armoryの開発ストーリーを紹介しているプレゼンテーションが
[ここ](https://www.youtube.com/watch?v=KKLnhmri8Cg)に上がっている。KiCadで
RAMとの配線を設計する難しさ、すぐ壊れるインダクタ、金メッキの不具合など、
開発で直面した諸々の罠を面白く語ってくれている。ハードウェアの自作に興味のある
方はぜひ観て欲しい。実は僕がUSB Armoryの存在を知ったのは、このビデオなのだ。

