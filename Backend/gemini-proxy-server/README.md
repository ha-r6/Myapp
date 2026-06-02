# Gemini Proxy Server

Firebase を使わずに、`iPhoneアプリ -> 小さいAPIサーバー -> Gemini API` でつなぐ最小構成です。

このサーバーは次のことだけをします。

- アプリから `GET /lens-lookup?q=...` を受け取る
- サーバー側の `GEMINI_API_KEY` で Gemini API を呼ぶ
- JSON をそのままアプリへ返す

DB は使いません。

## 使い方

### 1. APIキーを環境変数に入れる

```bash
export GEMINI_API_KEY="あなたのGemini APIキー"
```

### 2. サーバーを起動する

```bash
cd Backend/gemini-proxy-server
npm start
```

デフォルトでは `http://localhost:8787` で起動します。

### 3. 動作確認

```bash
curl "http://localhost:8787/health"
curl "http://localhost:8787/lens-lookup?q=TOPARDS%20Mocha%20Ring"
```

## アプリ側の設定

公開向けでは、ユーザーに URL を入力させません。

`[Myapp/AppConfig.swift](/Users/ha_r/Desktop/Myapp/Myapp/AppConfig.swift:1)` の
`AppConfig.aiSpecLookupEndpoint` に API サーバーのURLを入れます。

例:

```swift
static let aiSpecLookupEndpoint = "https://your-domain.com/lens-lookup"
```

ローカル確認だけなら、同じネットワーク上で見えるPCのIPでもOKです。
実機から使う場合は `localhost` では届かないので、同じネットワーク上で見えるPCのIPや、公開したURLを使ってください。

例:

- `http://192.168.1.20:8787/lens-lookup`
- `https://your-domain.com/lens-lookup`

## 置き場所の例

このサーバーは Firebase でなくても動きます。

- 自分の Mac
- VPS
- Render
- Railway
- Fly.io

まずはローカル起動で十分です。
