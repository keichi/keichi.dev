---
title: GBxCart Mini RWの使い方 (macOS Mojave)
date: 2019-03-18T21:10:33+09:00
description:
tags: []
---

GBxCart Mini RWというゲームボーイのROMダンパを買った．
最近開発しているゲームボーイのエミュレータをテストするにあたり，ゲームボーイの
カートリッジからROMデータを吸い出す必要があったからだ．

![ROMダンパの概観](/images/gbxcart.jpg)

## 購入方法

購入したのはinsideGadgetsの[GBxCart Mini
RW](https://shop.insidegadgets.com/product/gbxcart-rw/)というROMダンパだ．
調べたところでは他にもBennVennの[The Joey Jr.](https://bennvenn.myshopify.com/collections/game-cart-to-pc-interface/products/usb-gb-c-cart-dumper-the-joey-jr)
， J.Rodrigoの[Cart Flasher](https://www.tindie.com/products/JRodrigo/cart-flasher-for-gameboy/)，GAMEBANKの[GBA Dumper](http://www.gamebank-web.com/product/159)
などのROMダンパがあるらしい．知名度は他のROMダンパに比べやや低いけれども，
レビューは高く，価格が安かったので，GBxCartに購入を決めた．
なおGBxCart *Mini* RWは，無印のGBxCart RWから，ゲームボーイアドバンスのROM
ダンパ機能を省略した廉価版だ．

3/6にinsideGadgetsのウェブサイト上で注文したところ，3/7に発送され，3/18に到着
した．オーストラリアからInternational Economy便で来た．また，ROMダンパに加え，
ROMデータを吸出すカートリッジが当然必要になるので ，[ファミコンショップお宝王
](https://www.otakaraou.com/)というウェブサイトで 購入した．

![準備したカートリッジ](/images/gb-carts.jpg)

## クライアントのインストール

ROMを吸い出す前に，GBxCartのクライアントプログラムをPCにインストールする必要
がある．Windowsの場合はGUIのクライアントが提供されているが，macOS (および
Linux) ではCUIの クライアントしか提供されていない．クライアントのリポジトリを
GitHubからクローンし，ビルドする．特に依存関係はないので，makeするだけで良い
．

```
$ git clone https://github.com/insidegadgets/GBxCart-RW.git
$ cd GBxCart-RW/Interface_Programs/GBxCart_RW_Console_Interface_v1.20/
$ make
```

macOS Mojaveではドライバが既に内蔵されているので，別途ドライバをインストール
する必要はなかったが，古いmacOSではドライバをインストールする必要があるらしい
．その場合は，CH340というUSB-Serial変換チップの
[ドライバ](http://www.wch.cn/download/CH341SER_MAC_ZIP.html)をインストールする
．

## ROMの吸出し

![ROM吸出しの様子](/images/gbxcart2.jpg)

クライアントをインストールしたら，GBxCartにカートリッジを挿し，PCとUSB接続
する．そして，クライアントを用いてカートリッジヘッダを読み込んだ後，
ROM本体を読む．

```
$ ./gbxcart_rw_console_v1.20
GBxCart RW v1.20 by insideGadgets
################################
unable to open comport : No such file or directory
...
Connected on COM port: 41

Please select an option:
0. Read Header
1. Read ROM
2. Backup Save (Cart to PC)
3. Restore Save (PC to Cart)
4. Erase Save from Cart
5. Specify Cart ROM/MBC
6. Specify Cart RAM
7. Custom commands
8. Other options
x. Exit
>0

--- Read Header ---
Game title: HOSHINOKA
MBC type: MBC1
ROM size: 256KByte (16 banks)
RAM size: None
Logo check: OK

Please select an option:
0. Read Header
1. Read ROM
2. Backup Save (Cart to PC)
3. Restore Save (PC to Cart)
4. Erase Save from Cart
5. Specify Cart ROM/MBC
6. Specify Cart RAM
7. Custom commands
8. Other options
x. Exit
>1

--- Read ROM ---
Reading ROM to HOSHINOKA.gb
[             25%             50%             75%            100%]
[################################################################]
Finished

Please select an option:
0. Read Header
1. Read ROM
2. Backup Save (Cart to PC)
3. Restore Save (PC to Cart)
4. Erase Save from Cart
5. Specify Cart ROM/MBC
6. Specify Cart RAM
7. Custom commands
8. Other options
x. Exit
>x
```

注意点としては，
(1) ROMを読み出す前に，必ずカートリッジヘッダを読み込む．
カートリッジヘッダを読み込んでいないと，ROMを正しく読めない．また，カートリッ
ジヘッダを読み込んだ際に，`Logo check: OK`となっていることを確認する．
(2) カートリッジを差し替える際は，一旦USBケーブルを抜く．

