---
title: PLTとGOTってなんだっけ
date: 2020-05-06T16:17:45+09:00
description:
tags: []
---

PLTとGOTが何だったか今までに何回も検索したので，
忘れないよう自分なりにまとめておくことにしました．

**TL;DR** PLTとGOTは共有ライブラリの関数のリロケーションを実行時まで遅延するための仕組み

- PLT (Procedure Linkage Table): アプリケーションから直接呼ばれる．
    GOTから対応する共有ライブラリ関数のアドレスを取得し，間接ジャンプする．
- GOT (Global Offsets Table): 共有ライブラリ関数のアドレス一覧．
    実際に関数が呼ばれてからアドレスが設定される．

## 概要

共有ライブラリ関数の呼び出しは，プログラム->PLT->共有ライブラリという
2段ジャンプ方式になっています．これは，共有ライブラリはロードされるアドレス
が実行時まで不明なためです．プログラムがある共有ライブラリ関数を呼び出すと，
その際に動的リンカが共有ライブラリから関数のアドレスを探し出し，GOTに設定します．
PLTはGOTに設定されているアドレスを参照し，共有ライブラリにジャンプします．

もう少し細かい流れは下記の通りです:

### 初回の呼び出し

1. アプリケーションがPLT内のエントリを呼ぶ
2. PLTはGOTの対応するエントリが示すアドレスへジャンプ．初期状態では，
    PLTにあるリロケーション処理のアドレスが設定されている．
3. PLTはリロケーションのための準備を行い，動的リンカにジャンプ
4. 動的リンカはライブラリ関数のアドレスを解決し，GOTのエントリに上書き
5. ライブラリ関数へジャンプ

### 2回目以降の呼び出し

1. アプリケーションがPLT内のエントリを呼ぶ
2. PLTはGOTが示す共有ライブラリの関数へジャンプ

----

## PLTとGOTの動作を確かめてみる

実際に手を動かして，PLTとGOTが動く仕組みを確かめてみました．

### 下準備

まず，`gcc -no-pie -o hello hello.c`で次のソースコードをコンパイルします．
`-no-pie`フラグでPIE (と後述するRELRO) を切っています．

```c
#include <stdio.h>

int main()
{
    puts("hello, world");
    puts("hello, again");
}
```

生成された実行可能ファイルをlddで調べると，libcと動的リンカ (ld) に依存してい
ることがわかります．
```
$ ldd hello
	linux-vdso.so.1 (0x00007fff5efe1000)
	libc.so.6 => /lib/x86_64-linux-gnu/libc.so.6 (0x00007fb18c594000)
	/lib64/ld-linux-x86-64.so.2 (0x00007fb18c795000)
```

`readelf -a hello`すると，関係ありそうなセクションが見えます．
```
...
  [13] .plt              PROGBITS         0000000000401020  00001020
       0000000000000020  0000000000000010  AX       0     0     16
  [14] .plt.sec          PROGBITS         0000000000401040  00001040
       0000000000000010  0000000000000010  AX       0     0     16
...
  [23] .got              PROGBITS         0000000000403ff0  00002ff0
       0000000000000010  0000000000000008  WA       0     0     8
  [24] .got.plt          PROGBITS         0000000000404000  00003000
       0000000000000020  0000000000000008  WA       0     0     8
...
```


### 初回の呼び出し

gdbでhelloを起動し，`main`をディスアセンブルすると，下記のようになります．
`puts@plt`というアドレスを2回呼んでいることがわかります．

```
(gdb) disas
Dump of assembler code for function main:
=> 0x0000000000401136 <+0>:	endbr64
   0x000000000040113a <+4>:	push   %rbp
   0x000000000040113b <+5>:	mov    %rsp,%rbp
   0x000000000040113e <+8>:	lea    0xebf(%rip),%rdi        # 0x402004
   0x0000000000401145 <+15>:	callq  0x401040 <puts@plt>
   0x000000000040114a <+20>:	lea    0xec1(%rip),%rdi        # 0x402012
   0x0000000000401151 <+27>:	callq  0x401040 <puts@plt>
   0x0000000000401156 <+32>:	mov    $0x0,%eax
   0x000000000040115b <+37>:	pop    %rbp
   0x000000000040115c <+38>:	retq
End of assembler dump.
```

`puts@plt`は名前の通りPLTのエントリです．
`puts@plt`をディスアセンブルすると，`puts@got.plt`が指すアドレスへジャンプしていま
す．

```
(gdb) disas 'puts@plt'
Dump of assembler code for function puts@plt:
   0x0000000000401040 <+0>:	endbr64
   0x0000000000401044 <+4>:	bnd jmpq *0x2fcd(%rip)        # 0x404018 <puts@got.plt>
   0x000000000040104b <+11>:	nopl   0x0(%rax,%rax,1)
End of assembler dump.
```

`puts@got.plt`は，同じく名前の通りGOTのエントリです．
この時点では，`0x401030`という`.plt`内のアドレスになっています．

```
(gdb) x/a 0x404018
0x404018 <puts@got.plt>:	0x401030
```

ジャンプ先の`.plt`内の処理では，GOTの先頭アドレスと`puts`のGOT内でのインデック
スをスタックにプッシュし，動的リンカ (ld) へジャンプしています．
ldはglibcから`puts`のアドレスを解決した後，`puts@got.plt`に書き込みま
す．その後，glibcの`puts`にジャンプします．

<!--
1. `0x404018`の中身 (`0x401030`) にジャンプ
1. スタックに0をプッシュして
1. `0x401020`にジャンプ
1. `0x404008`をプッシュ
1. `0x404010`の中身へジャンプ -> `/lib64/ld-linux-x86-64.so.2`
-->

### 2回目以降の呼び出し

2回目の`puts`の呼び出しで`puts@got.plt`の中身を調べると，下記の通り，
`puts`本体のアドレスが設定されていることがわかります．

```
(gdb) x/a 0x404018
0x404018 <puts@got.plt>:	0x7ffff7e555a0 <__GI__IO_puts>
```


## メモ

- 何らかの方法で攻撃者がGOTへ値を書き込めてしまうと，任意コード実行が成立して
  してしまいます．そのため，プログラム起動時にGOTのエントリを全て埋めた後，
  GOTをread-onlyに設定する，RELRO (Relocation Read-Only) という機能があるそう
  です．
- ltraceはPLTにブレークポイントを書き込むことによって関数呼び出しをトレースしているそうです．

## 参考URL

- https://systemoverlord.com/2017/03/19/got-and-plt-for-pwning.html
- https://www.technovelty.org/linux/plt-and-got-the-key-to-code-sharing-and-dynamic-libraries.htmlohttps://systemoverlord.com/2017/03/19/got-and-plt-for-pwning.html
- https://www.redhat.com/en/blog/hardening-elf-binaries-using-relocation-read-only-relro
