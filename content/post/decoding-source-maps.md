---
title: Source Mapの仕組み
date: 2022-09-21T21:32:55+09:00
description:
tags: []
draft: true
---

Source mapの謎のエンコーディングってどういう仕組みになっているんだろう…
と疑問に思って調べた記録です．


## Source mapの概要

Source map (`*.map`) というのは主にWebフロントエンド開発で使われるファイル形式で，
TypeScriptやSassのようなトランスパイラの返還前後のソースコードの対応関係を記録しています．
ネイティブ開発でいうところのデバッグシンボルみたいなものです．
仕様書は[ここ](https://sourcemaps.info/spec.html)にあります．

Source mapファイルは下記のような構造のJSONになっています．`version`がsource
mapのバージョン，`file`が変換後のファイル名，`sources`が変換前のファイル名のリスト，
`sourceRoot`が`sources`の基底となるパス，`names`がシンボル名のリストをそれぞれ保持しています．
そして，`mappings`が変換前後のソースコードの対応関係を保持しているわけですが，
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

mappingsには，変換前後のソースコード上の位置の対応関係として，下記の情報が保持されています．

- 変換前のソースコードのファイル名
- 変換前のソースコードの行番号
- 変換前のソースコードの列番号
- 変換後のソースコードの行番号
- 変換後のソースコードの列番号

これらの情報を単純に辞書や配列として持つことも可能ですが，ファイルサイズが大きくなってしまうため，source mapではファイルサイズが小さくなるように工夫して保持しています．
具体的には，**差分符号化**と**可変長符号化**を組み合わせた方法になっています．

## mappingsのデコード

実際にmappingsをデコードするには，次のようにします．
まず，`mappings`の中身の文字列を`;`をデリミタとして分割します．
得られた文字列の配列は，**変換後**のソースコードの各行に対応します．
次に，各行に対応する文字列をさらに`,`をデリミタとして分割します．
得られた文字列の配列は，**変換後**のソースコードの1つの位置に対応します．

得られた文字列はBase64 VLQという方法でエンコードされています．
これは名前の通りBase64とVariable-Length Quantity (VLQ)を組み合わせたもので，
順にデコードしていきます．

まず，各文字をBase64でデコードするとそれぞれ6bitのビット列になります．
この6bitのうち，最上位bitはcontinuation bitといって

`gBACpC`のような文字列をBa

![](/images/base64_vlq.png)
