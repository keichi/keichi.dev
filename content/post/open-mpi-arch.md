+++
Description = ""
Tags = [
]
date = "2016-12-06T16:33:13+09:00"
title = "Open MPIのアーキテクチャ"
draft = true

+++

OpenMPIのアーキテクチャを理解するために、
_"The Architecture of Open Source Applications Volume ||: Structure, Scale and
Few More Fearless Hacks"_ という本のOpenMPIの章を読んだので、学んだことを簡単に
メモしておく。

<!--more-->

## OpenMPIの成り立ち

OpenMPIは次の4つのオープンソースなMPI実装を開発していたチームの協力の結果生ま
れた:

- LAM/MPI -- インディアナ大学
- LA/MPI (Los Alamos MPI) -- ロス・アラモス国立研究所
- FT-MPI (Fault-Tolerant MPI) -- テネシー大学
- PACX-MPI -- シュトゥットガルト大学

各チームが開発してきた4つのMPI実装をマージするのは困難であったため、フルスク
ラッチで新しいMPI実装を開発することになった。なお、SVN上での最初のコミットは
2003年11月22日に行われた。

## アーキテクチャ

### 設計方針

OpenMPIの開発開始時点で、既に巨大なプロジェクトになることが予期されていた。と
いうのも、

- 2003年時点における最新のMPI標準であるMPI-2.0は、300以上のAPI関数を定義してい
  た。
- 前身となった4つのプロジェクトのいずれもが巨大なコードベースだった。例えば、
  LAM/MPIのソースコードは、1,900ファイル以上かつ計30万行以上だった。
- OpenMPIを、前身となったプロジェクトを全て合わせたよりも、多くの機能、環境、
  ネットワークをサポートしたかった。

以上を踏まえて、OpenMPIのアーキテクチャを設計するにあたり、以下の3つの目標が
掲げられた:

- 各抽象化レイヤで、似たような機能をまとめる
- 実行時にロードできるプラグインと、実行時に設定できるパラメータで異なる実装を
  切り替えられるようにする
- パフォーマンスを下げるような抽象化を行わない

### 抽象化レイヤ

OpenMPIは主に3つの抽象化レイヤがある:

- Open, Portable Access Layer (OPAL): 最もハードウェアに近いレイヤであり、
  連結リスト、文字列操作、デバッグなどのよくあるユーティリティを提
  供する。OSに依存する処理、例えばNICの発見、プロセス間のメモリ共有、
  アフィニティ、高分解能タイマなどもこのレイヤで抽象化されている。
- Open MPI Run-Time Environment (ORTE): MPI実装は、MPI関数を提供するだけで
  なく、ジョブを起動・監視・終了するランタイムも提供しなければいけない。ORTEは
  このランタイムを提供するレイヤである。単純な環境では`rsh`や`ssh`によりプロセ
  スが起動される。より高度なHPC特化の環境では、スケジューラとの連携によりプロ
  セスを立ち上げる。OpenMPIでは、Torque/PBS Pro, SLURM, Oracle Grid Engine,
  LSFなどのスケジューラがサポートされている。
- Open MPI (OMPI): OMPIは最上位のレイヤであり、アプリケーションに公開される
  唯一のレイヤである。MPIのAPIはこのレイヤで実装されている。ポータビリティが
  最も重要な要件であるため、MPIレイヤは様々なネットワークやプロトコルをサポー
  トしている。

各抽象化レイヤは順に積み重なってはいるものの、ORTEやOMPIレイヤはパフォーマンス
上の必要に応じて下位のレイヤをバイパスできる。例えば、OMPIレイヤはOSバイパス
によりNICに直接アクセスすることができる。

各レイヤは別個のライブラリとして実装されている。ORTEライブラリはOPALライブラリ
に依存し、OMPIライブラリはORTEライブラリに依存している。各レイヤを別のライブラ
リに分けることで、抽象化を破るような実装を防ぐことができる。例えば、上位レイヤ
のシンボルを呼び出そうとすると、リンクに失敗するようになっている

### プラグイン

OpenMPIは、実行時にロード可能なコンポーネントの集まりとして実装されている。コ
ンポーネントは共通のインターフェースを持つものの、
実際、Open MPI v1.5には155個のプラグインが含まれている。例えば、`memcpy()`実装
のプラグイン、リモートサーバでプロセスを立ち上げるためのプラグイン、異なる
ネットワークを介して通信するためのプラグインなどがある。

```c
struct mca_btl_base_component_2_0_0_t {
    /* Base component struct */
    mca_base_component_t btl_version;
    /* Base component data block */
    mca_base_component_data_t btl_data;

    /* btl-framework specific query functions */
    mca_btl_base_component_init_fn_t btl_init;
    mca_btl_base_component_progress_fn_t btl_progress;
};
```

```c
struct mca_btl_tcp_component_t {
    /* btl framework-specific component struct */
    mca_btl_base_component_2_0_0_t super;

    /* Some of the TCP BTL component's specific data members */
    /* Number of TCP interfaces on this server */
    uint32_t tcp_addr_count;

    /* IPv4 listening socket descriptor */
    int tcp_listen_sd;

    /* ...and many more not shown here */
};
```
