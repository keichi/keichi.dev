---
title: YubiKeyをSSHの鍵に使うための設定
date: 2022-01-30T03:58:12+09:00
description:
tags: []
draft: false
---

新しいYubiKeyを購入するたびにSSHの鍵に使うための設定方法を調べるのが面倒なので，
自分用のメモを残しておく．

- macOSを前提とする (ただし，ほとんどの手順はLinuxでも同じはず)
- GPGを使う (PIVやFIDO2をSSHログインに使う方法もあるが，今回は使わない)
- 鍵はYubiKey上で生成する (秘密鍵のバックアップをとれないので，別のログイン
  手段を確保しておく)．

## YubiKeyのセットアップ

GPGとPinentryプログラムをインストールする．
macOSではGPG Suiteを使う人も多いようだが，私はMail/Finderのプラグインや
keyringのGUIは不要なので，本家のGPGのみインストールする．

```
$ brew install gnupg pinentry-mac
```

gpgを起動してadminモードに入る．

```
$ gpg --edit-card
gpg/card> admin
Admin commands are allowed
```

Key Derived Function (KDF)を有効化する．KDFとは，PINをハッシュ化して
YubiKey上に保存する機能である．PINを設定してからKDFを有効にすると，
ロックアウトしてしまうので注意．

```
gpg/card> kdf-setup
```

PINとAdmin PINを変更する．

```
gpg/card> passwd
gpg: OpenPGP card no. 00000000000000000000000000000000 detected

1 - change PIN
2 - unblock PIN
3 - change Admin PIN
4 - set the Reset Code
Q - quit

Your selection? 1
PIN changed.

1 - change PIN
2 - unblock PIN
3 - change Admin PIN
4 - set the Reset Code
Q - quit

Your selection? 3
PIN changed.

1 - change PIN
2 - unblock PIN
3 - change Admin PIN
4 - set the Reset Code
Q - quit
```

鍵アルゴリズムをED25519に変更する．

```
gpg/card> key-attr
Changing card key attribute for: Signature key
Please select what kind of key you want:
   (1) RSA
   (2) ECC
Your selection? 2
Please select which elliptic curve you want:
   (1) Curve 25519
   (4) NIST P-384
Your selection? 1
The card will now be re-configured to generate a key of type: ed25519
Note: There is no guarantee that the card supports the requested size.
      If the key generation does not succeed, please check the
      documentation of your card to see what sizes are allowed.
Changing card key attribute for: Encryption key
Please select what kind of key you want:
   (1) RSA
   (2) ECC
Your selection? 2
Please select which elliptic curve you want:
   (1) Curve 25519
   (4) NIST P-384
Your selection? 1
The card will now be re-configured to generate a key of type: cv25519
Changing card key attribute for: Authentication key
Please select what kind of key you want:
   (1) RSA
   (2) ECC
Your selection? 2
Please select which elliptic curve you want:
   (1) Curve 25519
   (4) NIST P-384
Your selection? 1
The card will now be re-configured to generate a key of type: ed25519
```

鍵を生成する．

```
gpg/card> generate
Make off-card backup of encryption key? (Y/n) n
Please specify how long the key should be valid.
         0 = key does not expire
      <n>  = key expires in n days
      <n>w = key expires in n weeks
      <n>m = key expires in n months
      <n>y = key expires in n years
Key is valid for? (0) 0
Key does not expire at all
Is this correct? (y/N) y

GnuPG needs to construct a user ID to identify your key.

Real name: Keichi Takahashi
Email address: hello@keichi.dev
Comment:
You selected this USER-ID:
    "Keichi Takahashi <hello@keichi.dev>"

Change (N)ame, (C)omment, (E)mail or (O)kay/(Q)uit? o
gpg: key 0xAF2F6B932484CC32 marked as ultimately trusted
gpg: directory '/Users/keichi/.gnupg/openpgp-revocs.d' created
gpg: revocation certificate stored as '/Users/keichi/.gnupg/openpgp-revocs.d/0000000000000000000000000000000000000000.rev'
public and secret key created and signed.
```

所有者などを設定する．
```
gpg/card> name
Cardholder's surname: Takahashi
Cardholder's given name: Keichi
gpg/card> lang
Language preferences: en
```

## GPGのセットアップ

GPGの設定ファイルを追加する．ネットで調べると長い設定ファイルの例が出てくるが，
最新のGPGを使っていればデフォルト値で
[問題ない](https://riseup.net/en/security/message-security/openpgp/gpg-best-practices)
らしいので，最小限の設定だけ記述する．

GPGの設定ファイル `.gnupg/gpg.conf` を作成する．
```
auto-key-retrieve
no-emit-version
```

gpg-agentの設定ファイル `.gnupg/gpg-agent.conf` を作成する．
```
enable-ssh-support
pinentry-program /opt/homebrew/bin/pinentry-mac
```

## シェルのセットアップ

シェルの設定ファイルにgpg-agentを自動起動する設定を足す．
私はzshを使用しているので，
oh-my-zshの[gpg-agnetプラグイン](https://github.com/ohmyzsh/ohmyzsh/blob/master/plugins/gpg-agent/gpg-agent.plugin.zsh)を使用する．
プラグインマネージャにzinitを使っているので，`.zshrc`に下記の行を追加する．

```
zinit snippet OMZP::gpg-agent/gpg-agent.plugin.zsh
```
