---
title: Intel CPUでのハードウェアパフォーマンスカウンタの使い方
date: 2020-11-03T17:45:28+09:00
description:
tags: []
---

モダンなCPUはハードウェアパフォーマンスカウンタという機能を備えており，
CPU内で発生した様々なイベント (クロック，命令のリタイア，キャッシュヒット・ミ
スなど) をハードウェアでカウントし，性能解析に役立てることができる．
ここでは，Intel CPUにおけるハードウェアパフォーマンスカウンタの使用方法を説明する．

## 概要

Intelプロセッサのハードウェアパフォーマンスカウンタは
Performance Monitoring Counter (PMC) と呼ばれており，Model-Specific Register (MSR)
の一部としてアクセスできる．PMCの使用方法はIntelのマニュアル
["Intel 64 and IA-32 Architectures Software Developer’s Manual Volume 3 (3A, 3B, 3C & 3D): System Programming Guide"](https://software.intel.com/content/www/us/en/develop/articles/intel-sdm.html)のChapter 18と19に詳しく書かれている．

CPU内にはPMCというユニットが複数存在し，CPU内の様々なユニットで発生するイベント
をカウントする．
PMCはgeneral-purpose performance countersとfixed-function performance counters
に分類される．前者はプログラムすることにより任意のイベントをカウントできる
一方，後者はカウンタごとに決まったイベントしかカウントできない．
また，イベントの種類はarchitectural performance eventとnon-architectural performance event
に分類される．名前がわかりにくいが，architectural performance eventはマイクロア
ーキテクチャ間で互換性がある一方，non-architectural performance eventは
特定のマイクロアーキテクチャに依存するものらしい．

PMCの数は限られており，1つのPMCでは1種類のイベントしかカウントできない．
CPUに搭載されているPMCの具体的な数はマイクロアーキテクチャやモデルによって異なる
が，最近のプロセッサならハードウェアスレッド毎にfixed-function performance countersが3つ，
general-purpose performance countersが4つある．
これ以上のイベントを計測したい場合は，プログラムを複数回走らせなければならない．

## PMCの設定・読み出し方法

具体的にPMCを設定し，カウントを読み出す方法を説明する．
General-purpose performance counterの実体は，`IA32_PMC0`，`IA32_PMC1`, …
というMSRにある．また，fixed-function performance countersの実体は，
`IA32_FIXED_CTR0`，`IA32_FIXED_CTR1`，…である．
各general-purpose performance counterには設定をプログラムするための
MSR`IA32_PERFEVTSEL0`，`IA32_PERFEVTSEL1`，…が存在する．
`IA32_PMC0`の設定は`IA32_PERFEVTSEL0`でプログラムするという具合になる．
fixed-function performance countersの設定は全て`IA32_FIXED_CTR_CTRL`を通して
行う．最後に，全カウンタの有効・無効を制御する`IA32_PERF_GLOBAL_CTRL`という
MSRがある．

PMCはハードウェアスレッドまたはコアごとに存在しており，あくまでハードウェアレベル
のものである．したがって，OSが測定対象のタスクをマイグレーションしてしまう
と正しくカウントができない．したがって正しい測定を行うためにはスレッドアフィニティを
設定することが必須である．

### General-purpose performance counters

General-purpose performance countersの使用方法は次の手順になる:

1. `IA32_PERF_GLOBAL_CTRL`で使用するPMCを有効化
2. `IA32_PERFEVTSELx`でカウントするイベントを設定
3. `IA32_PMCx`からカウントを読む

例えば，LLCミスを`PMC0`でカウントしたい場合は次のようにMSRを設定する．
まず，`IA32_PERF_GLOBAL_CTRL`(`0x38f`) で`PMC0`を有効にする．
`IA32_PERF_GLOBAL_CTRL`のレイアウトは次の図のようになっている (以降の図は全て
Intelのマニュアルより抜粋) ので，0ビット目を立てる．

![IA32_PERF_GLOBAL_CTRL](/images/IA32_PERF_GLOBAL_CTRL.png)

次に，`IA32_PERFEVTSEL0` (`0x186`)で`PMC0`をプログラムする．
`IA32_PERFEVTSELx`のレイアウトは下図のようになっており，各フィールドの意味は
次のとおりである．

- Event Select: 対象とするCPU内のユニットを指定
- UMASK: ユニット内でカウントするイベントの種類を指定
- OS: カーネルモード時のみカウントする
- USR: ユーザモード時のみカウントする
- EN: カウンタを有効化

![IA32_PERFEVTSELx](/images/IA32_PERFEVTSELx.png)

LLCミスイベントの場合，Event Selectは`0x2e`，Umaskは`0x41`を設定する．
各イベントのイベント番号とUmaskはIntelのマニュアルのChapter 19に網羅されている．
USRフラグ (16ビット目) ・ OSフラグ (17ビット目) のいずれかまたは両方を立てる．
さらに ENフラグ (22ビット目) を立ててカウンタを有効にする．

設定は以上である．`IA32_PMC0` (`0xc1`) を読めばLLCミスの回数がわかる．

### Fixed-function performance counters

Fixed-function performance counterの設定手順は次のとおりである:

1. `IA32_PERF_GLOBAL_CTRL`と`IA32_FIXED_CTR_CTRL`で使用するPMCを有効化
2. `IA32_FIXED_CTRx`からカウントを読む

例えば，リタイアした命令数をカウントする場合は次のようにMSRを設定する．
リタイアした命令数は`CTR0`がカウントしているので，このPMCを有効に
する．

まず，`IA32_PERF_GLOBAL_CTRL` (`0x38f`) で`FIX0`に対応する32ビット目を立てる．
次に，`IA32_FIXED_CTR_CTRL` (`0x38d`) の対応するビットを立てる．
レイアウトは下図の通りである．0ビット目と1ビット目のいずれかまたは両方を立てる．

![IA32_FIXED_CTR_CTRL](/images/IA32_FIXED_CTR_CTRL.png)

以上で設定が完了したので，`IA32_FIXED_CTR0` (`0x309`) を読み出す．

## サンプリング

`IA32_PERFEVTSELx`の`INT`ビットを立てることにより，カウンタがオーバーフローした際に
割り込みを発生させることができる．割り込みが発生した際のプログラムカウンタを
サンプリングすることでイベントの発生頻度が高い命令を調べることができる．
ただし，この方法ではパイプライン段数が深い現代のプロセッサでは問題がある．
というのも，割り込みが発生した時点でカウンタをオーバーフローさせた命令は既に
パイプラインを進んでおり，割り込み発生時のプログラムカウンタは実際にPMCを
オーバーフローさせた命令のプログラムカウンタとずれている．

そこで導入されたのがProcessor Event-Based Sampling (PEBS)
という仕組みである．PEBSを使用すると，カウンタがオーバーフローした時点で
ハードウェアがプログラムカウンタ等のレジスタをメモリのバッファに保存して
おいてくれる．このバッファが溢れた際に割り込みが発生するので，ソフトウェアは
バッファに蓄積された情報を読みに行けば良い．PEBSを利用することにより
サンプリング結果が正確になる上，割り込み回数が減るのでオーバーヘッドが削減される．

## PMCにアクセスするためのツール・ライブラリ

実際にPMCを使用して自分のアプリケーションを測定する場合は，
既存のツールやライブラリを使用すれば良い．
簡単と思われる順に書くと，次のようになると思う．普通は1か2で十分で，自分で
MSRを操作する必要はないはず．

1. [perf](https://perf.wiki.kernel.org/index.php/Main_Page)や[Intel VTune](https://software.intel.com/content/www/us/en/develop/tools/vtune-profiler.html)等のプロファイラを使用する．これらのツールはお手軽だが，具体的にどのパフォーマンスカウンタを読んでいるのかわからない場合がある．perfの場合，カーネルのソースコード ([arch/x86/events/intel/core.cなど](https://github.com/torvalds/linux/blob/a38b0ba1b7d2e7a6d19877540240e8a4352fc93c/arch/x86/events/intel/core.c))を読むとわかる．
2. [PAPI](http://icl.utk.edu/papi/software/)や[LIKWID](https://hpc.fau.de/research/tools/likwid/)等のフレームワークを使用する．アプリケーションの一部分のみ正確に測定したい場合，これらのフレームワークを使用することになる．アプリケーションからライブラリ関数を呼ぶことで，カウンタの開始・停止を指示できる．使用できるカウンタの種類も1に比べ多い．
3. msrドライバを使用する．`modprobe msr`すると，`/dev/cpu/n/msr`からMSRが
  見えるようになる．このデバイスを開き，対象のMSR番号だけシークした後，
  8バイト単位で読み書きする．
4. `wrmsr`, `rdmsr`命令を使用する．カーネルモードでしか実行できないので，
  カーネルモジュールを書く必要がある．

