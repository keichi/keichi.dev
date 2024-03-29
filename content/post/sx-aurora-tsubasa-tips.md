---
title: SX-Aurora TSUBASA SDKの使い方メモ
date: 2022-06-01T18:05:04+09:00
description:
tags: []
---

NECのマニュアル (PDF) を毎回参照するのが面倒なので，自分用に雑多な情報をまとめたメモです．
適宜更新しています．


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
    - 標準ライブラリ (STLなど) の中身のベクトル化状況も確認したい場合は，`-report-system-header`オプションを足す
- 非常に大きいコードをコンパイル時するとスタック不足でコンパイラが落ちることがある．
  その場合は`ulimit -s`でスタックサイズを増やすと成功するかもしれない．
- NECコンパイラでは`__NEC__`マクロが定義される

### デバッグ

- エラー時にスタックトレースを表示するには，実行時に環境変数`VE_TRACEBACK=ALL`を設定する
- スタックトレースにファイル名や行番号を表示するには，
  コンパイル時にオプション`-traceback=verbose -g`を指定した上で，実行時に環境変数`VE_TRACEBACK=VERBOSE`を設定する
    - MPIプログラムの場合は環境変数`NMPI_VE_TRACEBACK=ON`を設定する

### 監視ツール
- `/opt/nec/ve/bin`以下の`ve-top`, `ve-ps`, `ve-free`, `ve-vmstat`, `ve-strace`でVE上のプロセスを確認できる
- `ve_exec`でプログラムを実行するVEとコアを指定可能

## 性能測定

### PROGINF

- 実行時に環境変数`VE_PROGINF=DETAIL`と設定すると性能の概要が出力される．
- MPIプログラムでは，`NMPI_PROGINF=YES`を設定すると，PROGINF情報が全ランクに渡って集計されて表示される．
    - `VE_PROGINF=DETAIL`では各ランクが独立にPROGINF情報を出力してしまうので注意．

### FTRACE

- `-ftrace`オプションをつけてコンパイル後，実行する．`ftrace.out`というファイルができるので，`ftrace`コマンドを同じディレクトリで実行
- ルーフライン解析を行うには，ftrace実行に `VE_PERF_MODE`環境変数に`VECTOR-MEM`を設定し，
  メモリアクセスのプロファイルを収集する
    - LLCにおけるB/F (NEC用語ではREQ B/F) = REQ. B/F
    - HBMにおけるB/F (NEC用語ではACT B/F) = REQ.ST B/F + ACT.VLD B/F
- ベクトル化率V.OP RATIOはベクトル命令数/全命令数で算出されている (実行時間ベースではないことに注意)
    - 実行時間ベースでの内訳はEXCLUSIVE TIMEとVECTOR TIMEを見る
- `ftrace_region_begin()`と`ftrace_region_end()`でコードを囲むとその部分の
  性能を測定することができる．ヘッダファイル (`ftrace.h`) のincludeが必要．
- `-ftrace`オプションをつけてコンパイルすると`_FTRACE`というマクロが定義される
    ので，`ftrace_region_*()`の呼び出しは`#ifdef _FTRACE`で囲むと便利

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
- 通信時間をプロファイルするには，コンパイル時に`-mpiprof`オプションをつけた上で，
  実行時に `NMPI_COMMINF=YES`環境変数を設定する．
    - `-mpiprof`オプションがないとPMPIのシンボルが定義されないため，外部のMPIプロファイラを使用する際も必要．
- FTRACEも使用可能
    - `ftrace.out.*.*`という名前でランクごとにFTRACEファイルが出力される．
    - FTRACEファイルはランクごとに分析できる他，`ftrace -f ftrace.out.*`と全ランクのファイルをftraceコマンドの引数に渡すと，全ランクの情報が集計される．

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
