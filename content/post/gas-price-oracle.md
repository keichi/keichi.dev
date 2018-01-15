---
title: "Ethereumにおける推奨Gas価格の算出方法"
date: "2018-01-12T19:01:17+09:00"
---

**TL;DR** Gethは過去のトランザクションのgas価格の中央値を採用している。

## Gas Price Oracle

Ethereumのトランザクションの手数料は、 (トランザクションが消費するgasの総量)
* (gas価格) によって決定される。
マイナはgas価格が高いトランザクションを優先してブロックへ取り込んでいくため、
gas価格が高いほど早くトランザクションが処理される。一方でgas価格を上げると、
当然トランザクションの手数料も上がる。
そのため、トランザクションを安く・早く処理させるためには、適切なgas価
格を設定する必要がある。

ユーザは取引を作成する際に自由にgas価格を設定できるが、
手動設定するのは大変なので、大抵のEthereumクライアントは、
推奨gas価格を提示する仕組みを内蔵している。
これを**Gas Price Oracle (GPO)**と呼ぶ。

## GethのGas Price Oracleアルゴリズム

Gas Price Oracleのアルゴリズムはクライアントによって異なるが、ここでは、
Ethereumの公式クライアントである[geth](https://github.com/ethereum/go-ethereum)
のアルゴリズムを調査した。GethのGPOは
[eth/gasprice/gasprice.go](https://github.com/ethereum/go-ethereum/blob/release/1.7/eth/gasprice/gasprice.go)
に実装されている。

実際にGas価格の推奨値を求めているのは、 `Oracle.SuggestPrice()` だ。この関数で
は、まず最新のブロックからnブロック (デフォルトでは10ブロック) 以前までのブロック
に含まれる全てのトランザクションのgas価格を得る。トランザクションが含まれない
空のブロックがあれば 、さらに過去のブロックまで遡る。

```go
for sent < gpo.checkBlocks && blockNum > 0 {
    go gpo.getBlockPrices(ctx, blockNum, ch)
    sent++
    exp++
    blockNum--
}
maxEmpty := gpo.maxEmpty
for exp > 0 {
    res := <-ch
    if res.err != nil {
        return lastPrice, res.err
    }
    exp--
    if len(res.prices) > 0 {
        txPrices = append(txPrices, res.prices...)
        continue
    }
    if maxEmpty > 0 {
        maxEmpty--
        continue
    }
    if blockNum > 0 && sent < gpo.maxBlocks {
        go gpo.getBlockPrices(ctx, blockNum, ch)
        sent++
        exp++
        blockNum--
    }
}
```

このようにして得た過去のトランザクションのgas価格 `txPrices` を元に、
推奨gas価格を算出する。

```go
if len(txPrices) > 0 {
    sort.Sort(bigIntArray(txPrices))
    price = txPrices[(len(txPrices)-1)*gpo.percentile/100]
}
```

`gpo.percentile` のデフォルト値は50なので、デフォルトでは過去のトランザクショ
ンのgas価格の50パーセンタイル、つまり中央値を採用する。
最後に、最大でも500 Shannon (= 0.0000005 ether) になるようキャッピングする。

## 現在のGas Price Oracleアルゴリズムの問題点

このアルゴリズムの問題は、意図的に高額なGas価格のトランザクションを作成すると、
中央値を高騰させられることだ。実際、最近Gas価格の不審なスパイクが
[観測されている](https://www.ethnews.com/estimated-gas-prices-rising-dramatically-on-ethereum-network)
。

そのため、新しいGas価格推定アルゴリズムの導入が
[検討されている](https://www.ethnews.com/ethereum-foundations-nick-johnson-on-gwei-transaction-fees)
。新アルゴリズムでは、過去の所定の数のブロックについて、各ブロック中で最も安い
Gas価格を求め、それらの中央値 (あるいはパーセンタイル) を採用する。
現在はバックテストにより有効性を確認している段階で、gethへ導入される可能性が高
そうだ。
