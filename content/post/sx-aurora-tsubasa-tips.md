---
title: SX-Aurora TSUBASA SDKの使い方メモ
date: 2022-06-01T18:05:04+09:00
description:
tags: []
---

NECのマニュアルを参照するのが面倒なので，自分用に雑多な情報をまとめたメモです．


## ツールチェーン

### コンパイラ

- C, C++, Fortranのコンパイラはそれぞれ`ncc`, `nc++`, `nfort`
- 標準のbinutilsはVEに対応していないので，nでprefixされたbinutilsを使う．
  `nreadelf`, `nnm`, `nobjdump`などがある．
- 最適化レベルは`-O1`から`-O4`まである．
- デフォルトではインライン展開しないので，C++コードではベクトル化がかなり限定的である．
  `-finline-functions`をつけて自動インライン化を有効にするとベクトル化が促進される．
- コンパイラを実行する際に`-report-all`というオプションをつけると`ソースコード.L`
  というファイルが生成され，どのようにベクトル化・最適化されたのか確認できる．
- 非常に大きいコードをコンパイル時するとスタック不足でコンパイラが落ちることがある．
  その場合は`ulimit -s`でスタックサイズを増やすと成功するかもしれない．
- NECコンパイラでは`__NEC__`マクロが定義される

### デバッグ

- エラー時にスタックトレースを表示するには，実行時に環境変数`VE_TRACEBACK=ALL`を設定する
- スタックトレースにファイル名や行番号を表示するには，
  コンパイル時にオプション`-traceback=verbose`を指定した上で，実行時に環境変数`VE_TRACEBACK=VERBOSE`を設定する

### 監視ツール
- `/opt/nec/ve/bin`以下の`top`, `ps`, `free`, `vmstat`, `strace`でVE上のプロセスを確認できる
- `ve_exec`でプログラムを実行するVEとコアを指定可能

## 性能測定

### PROGINF

- 実行時に環境変数`VE_PROGINF=DETAIL`と設定すると性能の概要が出力される．

### FTRACE

- `-ftrace`オプションをつけてコンパイル後，実行する．`ftrace.out`というファイルができるので，`ftrace`コマンドを同じディレクトリで実行
- ルーフライン解析
	- REQ B/F: REQ. B/F そのまま
	- ACT B/F: REQ.ST B/F + ACT.VLD B/F
- ベクトル化率V.OP RATIOはベクトル命令数/全命令数 (実行時間ではないことに注意)
    - 実行時間での内訳はEXCLUSIVE TIMEとVECTOR TIMEを見る
- `ftrace_region_begin()`と`ftrace_region_end()`でコードを囲むとその部分の
  性能を測定することができる．ヘッダファイル (`ftrace.h`) のincludeが必要．
- `-ftrace`オプションをつけてコンパイルすると`_FTRACE`というマクロが定義される
    ので，`ftrace_region_*()`の呼び出しは`#ifdef _FTRACE`で囲むといい．

## 並列化

### OpenMP
- "Unable to grow stack"というエラーが表示された場合は，スタックサイズが不足している．
    `export OMP_STACKSIZE=2G`などでスタックサイズを拡張すると良い．
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

- NUMAモードではメモリ帯域幅は変わらないが，キャッシュ帯域幅が約2.1TB/sから3.0TB/sに向上する (Type 20Bの場合)
- `venumainfo`でNUMA情報を確認可能
- `VE_NUMA_OPT`で`--cpunodebind`と`--localmembind`が設定可能

設定方法は，root権限で下記を実行する:

```
# vecmd vconfig set partitioning_mode on # またはoff
# vecmd state set off
# vecmd state set mnt
# vecmd reset card
```
