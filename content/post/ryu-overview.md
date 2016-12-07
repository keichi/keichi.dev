+++
date = "2015-11-30T23:00:44-06:00"
draft = true
title = "Ryu OpenFlowコントローラの概要"

+++

[Ryu](http://osrg.github.io/ryu/)はOpenFlowコントローラを開発するための
フレームワーク

<!--more-->

## Ryuのアーキテクチャ

### Ryuアプリケーション

Ryuで動作するOpenFlowコントローラは、複数のRyuアプリケーションからなる。それぞれ
のアプリケーションはクラスで、`ryu.base.app_manager.RyuApp`を継承する。
Ryuアプリケーションはユーザが定義するもの以外に、ビルトインのものがある。
例として下記などがあげられるが、他にも様々なRyuアプリケーションがリポジトリに
含まれている。これらのRyuアプリケーションを見れば、チュートリアルやリファレンス
に載っていないことも大抵実装できる。

- `ofp_event` (OpenFlowプロトコルメッセージをハンドルする)
- `ryu.topology.switches.Switches` (ネットワークのトポロジを監視する)
- `ryu.app.ofctl_rest.RestStatsApi` (フローの追加・変更・削除のためのREST APIを提供する)
- `ryu.app.simple_switch_*.SimpleSwitch*` (L2スイッチの様々な実装)

### イベント

Ryuアプリケーション同士は、互いに通信し連携することができる。最もわかりやすい例
としては、`ofp_event`アプリケーションがある。このアプリケーションは、
他の全てのアプリケーションにOpenFlowに関連するイベントを通知する。
アプリケーション間の連携には3つの方法がある:

- ブロードキャストイベント (1:nの通知)
- ユニキャストイベント (1:1の通知)
- メソッド (1:1)

#### ブロードキャストイベント
ブロードキャストイベントは、1つのアプリケーションから複数のアプリケーション
に対して通知されるイベントである。イベントの実体は、`ryu.controller.event.EventBase`
を継承する任意のクラスである。イベントの受信側では、`set_ev_cls`デコレータを
アプリケーションのメソッドに適用し、任意のイベントクラスを購読する。
イベントの送信側では、`RyuApp.send_event_to_observers`メソッドで
イベントオブジェクトを購読している全てのアプリケーションに対して送信する。

```python
from ryu.base import app_manager
from ryu.lib import hub
from ryu.controller.event import EventBase
```

### 参考
1. http://momijiame.tumblr.com/post/63843270751/openflow-%E3%82%B3%E3%83%B3%E3%83%88%E3%83%AD%E3%83%BC%E3%83%A9-ryu-%E3%81%AE%E3%82%A2%E3%83%97%E3%83%AA%E3%82%B1%E3%83%BC%E3%82%B7%E3%83%A7%E3%83%B3%E9%96%93%E9%80%9A%E4%BF%A1
