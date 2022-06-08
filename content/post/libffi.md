---
title: libffiって何をするためのライブラリなの?
date: 2022-06-08T15:13:50+09:00
description:
tags: []
---

**TL;DR** libffiを使うと，実行時までシグネチャが不明な関数を呼び出すことができる．

libffiという名前はよく見るし，自分でインストールしたこともある．
なんとなくスクリプト言語からCの関数を呼ぶ時に必要らしというのは知っているけど，
具体的に何をやってくれるライブラリなのか知らなかったので，調べてみた．

## 前提条件

まず下記のような内容の共有ライブラリ `libadd.so` があり，
`add()` を他のプログラムから呼び出したいとする．

```c
int add(int a, int b)
{
    return a + b;
}
```

このような場合，まず動的ローダを呼び出して`libadd.so`をロードし，`add()`のアド
レスを取得する．

```c
void *handle = dlopen("./libadd.so", RTLD_LAZY); // libadd.soをロード
void *add = dlsym(handle, "add"); // add()のアドレスを取得
```

問題はここからで，`add`はvoidポインタなのでこのままでは呼び出せない．そこで
`add`を正しいシグネチャの関数ポインタにキャストすると，関数として呼び出せるよ
うになる．

```c
void call_func_ptr(void *add)
{
    int c = 0;
    c = ((int(*)(int,int))(add))(1, 2);

    printf("call via function pointer: add(1, 2) = %d\n", c);
}
```

プラグインのような共有ライブラリなら関数のシグネチャは事前に知っていると仮定できる．
しかし，関数の型が実行時まで不明な場合はどうしたらいいのだろう?

## インラインアセンブリ

関数の型がコンパイル時に不明な場合は，コンパイラに頼ることはできない．
そのため，[呼び出し規約](https://freak-da.hatenablog.com/entry/2021/03/25/172248)
にしたがってレジスタやスタックに引数を設定をして関数を呼び出すことになる．
これはアセンブリで書く必要があり，例えば次のようになる:

```c
void call_inline_asm(void *add)
{
    int c = 0;

    asm("movq %1, %%rdi\n\t"
        "movq %2, %%rsi\n\t"
        "call *%3\n\t"
        : "=g"(c)
        : "g"(1), "g"(2), "g"(add)
        : "%rdi", "%rsi");

    printf("call via inline assembly: add(1, 2) = %d\n", c);
}
```

しかし，呼び出し規約はOSやプロセッサに依存するので，色々なOSやプロセッサで
動くようにしたいと思うと大変だ．

## Foreign Function Interface (FFI)

libffiiを用いるとそんな手間を省くことができる．libffiを使って`add()`を呼び出す
コードは次のようになる．

```c
void call_ffi(void *add)
{
    ffi_cif cif;
    ffi_type* args[] = {&ffi_type_sint32, &ffi_type_sint32};
    ffi_prep_cif(&cif, FFI_DEFAULT_ABI, 2, &ffi_type_sint32, args);

    int a = 1, b = 2, c = 0;
    void *values[] = {&a, &b};

    ffi_call(&cif, FFI_FN(add), &c, values);

    printf("call via libffi: add(1, 2) = %d\n", c);
}
```

libffiの使い方はシンプルで，まず`ffi_prep_cif()`で呼び出したい関数のシグネチャを
表現した`ffi_cif`構造体を作成する．そして，`ffi_call()`に`ffi_cif`構造体と
引数を渡して実際に関数を呼び出す．
この例では引数の型として`int`しか使用していないが，
各組み込み型に対応する`ffi_type_*`が用意されている．
また，`ffi_type`を用いることで，任意の構造体に対応する型を定義することもできる．
