---
title: "USB ArmoryでElectrum Bitcoin Walletを動かす"
date: "2015-04-07T23:51:04+09:00"
---

[USB Armory](/post/usb-armory)の有用なユースケースの1つとして考えられるのが、
ポータブルなビットコインのウォレットだ。ビットコインのウォレットの実体は、複数の
公開鍵/秘密鍵ペアの集合だ。鍵ペアは暗号化した状態で、ウォレットをインストール
したコンピュータに保存しておく。ここで問題になるのが、自分の普段使っている
マシン以外でビットコインの支払いなどの操作をしたいときだ。
信頼できないマシンに鍵ペアを転送するのは、明らかに危険だ。

このような状況で、USB Armoryを使うと都合が良い。USB Armoryにウォレットの
鍵ペアを保存し、USB Armoryの上でウォレット・アプリケーションを動かせば、
信頼できないコンピュータで安全にビットコインの取引を行うことができる。

<!--more-->

Inverse PathによるUSB Armoryの紹介ページでは、Electrumというウォレットが動作確認
済みと書かれている。よって、僕もElectrumをインストールして使ってみることにした。
ちなみに、普段Macで使っているウォレットもElectrumだ。数多く存在するビットコイン
ウォレットアプリケーションの中でもElectrumを使っているのには理由があるのだが、
それはまた別の記事で説明することにする。

## インストール方法

まず、USB Armoryにログインし、Electrumをインストールする。

```nohighlight
$ sudo apt-get install python-qt4 python-pip
$ sudo pip install https://download.electrum.org/Electrum-2.0.4.tar.gz
```

次に、`xauth`をインストールする。

```nohighlight
$ sudo apt-get install xauth
```

USB Armoryを接続して使いたいコンピュータから、X11 Forwardingを有効にした状態で、
USB Armoryに接続し、Electrumを起動する。

```nohighlight
$ ssh -X <USB ArmoryのIPアドレス>
$ electrum
```

ElectrumのUIが表示されるので、ウォレットをインポートするか、新規作成する。

## 注意点
- USB Armoryを接続するコンピュータには、X11 Serverがインストールされている
    必要がある。僕はMacユーザなので、XQuartzをインストールした。
- ちなみに`XQuartz 2.7.7`とOSX Yosemiteの組み合わせは、X11 Forwardingに問題
    があり、僕の環境では上手く動かなかった。`XQuartz 2.7.8 RC1`をインストール
    したところ、直った。
- Hot WalletなElectrumとして使用するためには、USB Armoryがインターネットに
    接続できている必要がある。
