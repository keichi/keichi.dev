---
title: 20分で1000万ノードを発見する高速BitTorrent DHTクローラを作った話
date: 2019-06-11T11:48:24+09:00
description:
tags: []
draft: true
---

[ゲームボーイのエミュレータを自作した話](/post/write-yourself-a-game-boy-emulator/)
に引き続き，つくったものを紹介するシリーズ．

## 動機

BitTorrentプロトコルに興味を持って調べていたところ，NICTとネットエージェントと
いう会社の発表
[「DHTの迅速で膨大なモニタリング: 24時間以内に1000万ノードの情報をクローリングする」](https://pacsec.jp/psj11/PacSec2011_Massive-Monitoring_jp.pdf) を発見した．

## BitTorrent DHT

[なぜなにTorrent](https://nazenani-torrent.firefirestyle.net/)

### ダウンロードの手順 (DHT無し)

1. 欲しいファイルのTorrentファイルを用意する (ウェブサイトからHTTPでダウンロード)
2. Torrentファイルからトラッカの一覧を読み出す
3. トラッカに接続し，ファイルの断片を持つピアのアドレスを得る
4. ピアからファイルのピースをダウンロードする

### ダウンロードの手順 (DHT有り)

DHT以前のBitTorrentの問題として，トラッカが停止するとピアの探索ができなくなり，
ピースを持っているピアが存在するに関わらず，ピースのダウンロードができなくなる．
また，ピアの数が増加すると，トラッカがボトルネックになってしまう．

この問題に対して，BitTorrent Mainline DHTでは，ピアの情報を分散ハッシュテーブ
ルに保存しトラッカを不要になり，耐障害性とスケーラビリティを向上する．
BitTorrent DHTはKademliaと呼ばれるDHTを基にしており，160-bitのアドレス空間を
2分木に構造化している．DHTを構成する計算機はKRPCと呼ばれるプロトコルで通信する
．KRPCは，BencodeというTorrentファイルと同様のシリアライゼーションした
メッセージをUDP上で送受信する．DHTの詳細は[BEP0005](https://www.bittorrent.org/beps/bep_0005.html)で述べられている．

ping, find_node, get_peers, and announce_peerなどがある．
find_nodeは，あるノードIDを投げると，そのノードIDに "近い" ノードを複数返す．
クローリングにあたっては，find_nodeを再帰的に投げていけば，DHT上のノードを
次々と発見できることになる．

## 並列分散型クローラ (10時間で1000万ノード)


## 単1ノードクローラ (20分で1000万ノード)

### 基本設計

### 並列キューの最適化

### ノード情報の保存・問い合わせ

### その他

Bencode
