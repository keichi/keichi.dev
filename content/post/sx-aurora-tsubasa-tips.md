---
title: SX-Aurora TSUBASAの使い方メモ
date: 2022-06-01T18:05:04+09:00
description:
tags: []
draft: true
---


## ツールチェーン

### コンパイラ

- C, C++, Fortranのコンパイラはそれぞれ`ncc`, `nc++`, `nfort`
- 標準のbinutilsはVEに対応していないので，nでprefixされたbinutilsを使う
  `nreadelf`, `nnm`, `nobjdump`など．
- `-report-all`オプションをつけると`ソースコード.L`というファイル (編集リスト)
  が生成され，どのようにベクトル化・最適化されたのか確認できる．
- 非常に大きいコードのコンパイル時にはスタック不足でコンパイラが落ちることがある．
  その場合は`ulimit -s`でスタックサイズを増やすと成功するかもしれない．

### 監視ツール
- `/opt/nec/ve/bin`にツールチェーンがインストールされている．
- `top`や`ps`, `free`, `vmstat`, `strace`でVE上のプロセスを確認できる
- `ve_exec`でプログラムを実行するVEトコアを指定可能
- NECコンパイラでは`__NEC__`マクロが定義される

## 性能測定

### PROGINF

- `VE_PROGINF=DETAIL`で性能のサマリがでる

### FTRACE

- `-ftrace`オプションをつけてコンパイル後，実行する．`ftrace.out`というファイルができるので，`ftrace`コマンドを同じディレクトリで実行
- ルーフライン解析
	- REQ B/F: REQ. B/F そのまま
	- ACT B/F: REQ.ST B/F + ACT.VLD B/F
- V.OP RATIOは命令数のベクトル率
- EXCLUSIVE TIMEとVECTOR TIME
- `ftrace_region_begin()`と`ftrace_region_end()`でコードを囲むとその部分の
  性能を測定することができる．ヘッダファイル (`ftrace.h`) のincludeが必要．
- `-ftrace`オプションをつけてコンパイルすると`_FTRACE`というマクロが定義される
    ので，`ftrace_region_*()`の呼び出しは`#ifdef _FTRACE`で囲むといい．

## 並列化

### OpenMP
- "Unable to grow stack"
- スレッド数は`OMP_NUM_THREADS`または`VE_OMP_NUM_THREADS`という環境変数で設定
    する．`VE_OMP_NUM_THREADS`の方が優先順位が高いので，VHとVEでスレッド数を変
    えたいときはVHのスレッド数を`OMP_NUM_THREADS`，VEのスレッド数を`VE_OMP_NUM_THREADS`
    で設定すると良い．

### MPI
- `mpincc`, `mpinc++`, `mpinfort`が内部で呼ぶコンパイラはそれぞれ`NMPI_CC`, `NMPI_CXX`, `NMPI_FC`環境変数で設定できる．
- `mpincc/nc++/fort`に`-mpiprof`をつけるとMPIプロファイラが有効になる．
  このオプションがないとPMPIのシンボルが定義されないため，
  外部のMPIプロファイラを使用する際も付ける必要がある．
- `NMPI_COMMINF=YES`を設定すると，MPI通信のプロファイリング結果が表示される．

## NUMAモード

- メモリ帯域幅は変わらないが，キャッシュ帯域幅が2.1TB/sから3.0TB/sに向上する
- `venumainfo`でNUMA情報を確認可能
- `VE_NUMA_OPT`で`--cpunodebind`と`--localmembind`が設定可能

設定方法は，root権限で下記を実行する:

```
# vecmd vconfig set partitioning_mode on # またはoff
# vecmd state set off
# vecmd state set mnt
# vecmd reset card
```
