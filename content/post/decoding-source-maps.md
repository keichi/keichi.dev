---
title: Source Mapの仕組み
date: 2022-09-21T21:32:55+09:00
description:
tags: []
---

Source mapの謎のエンコーディングってどういう仕組みになっているんだろう…
と疑問に思って調べた記録です．


## Source mapの概要

Source map (`*.map`) というのは主にWebフロントエンド開発で使われるファイル形式で，
TypeScriptやSassのようなトランスパイラの変換前後のソースコードの対応関係を記録しています．
ネイティブ開発でいうところのデバッグシンボルみたいなものです．
仕様書は[ここ](https://sourcemaps.info/spec.html)にあります．

Source mapファイルは下記のような構造のJSONになっています．`version`がsource
mapのバージョン，`file`が変換後のファイル名，`sources`が変換前のファイル名のリスト，
`sourceRoot`が`sources`の基底となるパス，`names`がシンボル名のリストをそれぞれ保持しています．
そして，`mappings`が変換前後のソースコードの対応関係を表現しているわけですが，
一見よくわからない方法でエンコードされています．

```json
{
  "version": 3,
  "file": "binary_parser.js",
  "sourceRoot": "",
  "sources": [
    "../lib/binary_parser.ts"
  ],
  "names": [],
  "mappings": ";;;AAAA,MAAM,OAAO;IAWX,YAAY,UAAkB,EAAE,mBAA4B;QAV5D,SAAI,GAAG,EAAE,CAAC;..."
}
```

## mappingsの内容

mappingsには，変換前後のソースコード上の位置の対応関係が記録されています．
source mapではファイルサイズが小さくなるように工夫して保持しています．
具体的には，**差分符号化**と**可変長符号化**を組み合わせた方法になっています．

## mappingsのデコード

mappingsをデコードするには，次のようにします．
まず，`mappings`の中身の文字列を`;`をデリミタとして分割します．
得られた文字列の配列は，**変換後**のソースコードの各行に対応します．
次に，各行に対応する文字列をさらに`,`をデリミタとして分割します．
得られた文字列の配列は，**変換後**のソースコードの1つの位置に対応します．
各文字列を以降，**セグメント**と呼びます．

各セグメントはBase64 VLQという，名前の通りBase64とVariable-Length Quantity (VLQ)
を組み合わせた形式でエンコードされています．
まず，各文字をBase64でデコードするとそれぞれ6bitのビット列になります．

さらに，6bitのビット列をVLQでデコードします．6bitのうち，
最上位bitはcontinuation bitといい，6bitのビット列が続く場合，1になります．
また，最初の6bitの最下位bitはsign bitといい，符号を示します (1なら負)．
以下に，`gBACpC`というセグメントをBase64 VLQでデコードした結果を示します．

![](/images/base64_vlq.png)

セグメントをデコードすると，次の5つの数値の組が得られます．これらの値は差分符号化されており，
直前のセグメントの値に対する相対値としてして表現されています．
また，2-5は省略可能であり， 省略された場合は0 (直前のセグメントの値と同じ) として扱われます．

1. 変換後のソースコードの列番号
1. `sources`配列のインデックス (変換前のソースコードのファイル名)
1. 変換前のソースコードの行番号
1. 変換前のソースコードの列番号
1. `names`配列のインデックス (変換前のソースコードにおける識別子名)

## おまけ

[Gist](https://gist.github.com/keichi/bae95d1fd54dfcbb74eb6cb3ed0abf24)
に自作した簡易的なsource mapのデコーダをアップロードしてあります．
