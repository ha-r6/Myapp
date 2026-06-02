# Firebase Functions + Gemini（無料枠）で「レンズスペック自動入力」する（初心者向け）

このフォルダは **iOSアプリにGeminiのAPIキーを入れず**、Firebase Functions（サーバ）経由でGemini APIを呼び出すためのサンプルです。

## ざっくり流れ

1. Google AI StudioでGemini APIキーを作る（無料枠でOK）
2. Firebase Functionsにキーを「サーバ側だけ」で保存する
3. Functionsに `GET /lens-lookup?q=...` を作る（このサンプル）
4. FunctionsのURLをアプリに組み込む（ユーザー入力は不要）

※ Gemini の Free tier は上限を超えると課金が発生し得ます。試験中はリクエスト数を少なくして、必要なら請求アラートも設定してください。

## iOS側（このリポジトリに実装済み）

1) アプリの「設定」→「AIでスペックを自動入力する」をON
2) 「AIエンドポイント」に Functions のURLを貼り付ける

例:

- `https://<region>-<project>.cloudfunctions.net/lensLookup`

これで、レンズ追加画面の「AIでスペックを自動入力」ボタンが使えます。

## Functions側（このサンプルを使う）

### 0) 事前準備（Mac）

- Node.js をインストール（LTS推奨）
- Firebase CLI をインストール
  - `npm i -g firebase-tools`

### 1) Firebase プロジェクトを作成

1. Firebase Console で「プロジェクトを追加」
2. 作成後、左メニューから「Build → Functions」を開いて有効化

### 2) ログイン & Functions 初期化

ターミナルで作業用フォルダに移動して実行します。

1. `firebase login`
2. `firebase init functions`
   - 何を選ぶか迷ったら:
     - Language: JavaScript
     - ESLint: お好みでOK
     - Install dependencies now?: Yes

初期化が終わると `functions/` フォルダができます。

### 3) サンプルコードを貼る

`functions/index.js` を開いて、このリポジトリの

- `Backend/firebase-functions-gemini/index.js`

の中身をコピペしてください。

### 4) APIキーをサーバに入れる（重要）

GeminiのAPIキーは **絶対にiOSアプリに入れない** でください。

Firebase Functions（v2）の例（環境変数）:

- `GEMINI_API_KEY` に、Google AI Studioで作ったキーを設定します。

※ 設定方法は Functions の世代（v1/v2）や Firebase CLI の状態で変わることがあります。ここが詰まったら、まずメンターさんにも聞いてね。

### 5) デプロイ

`firebase deploy --only functions`

デプロイ後に表示される `lensLookup` のURLを、`Myapp/AppConfig.swift` に貼ります。

## よくある安全対策（おすすめ）

- 1日の回数制限（無料枠を超えないようにする）
- 失敗時はフォーム手入力に戻れるUIにする（iOS側は実装済み）
- Functionsのログを見て、想定外に叩かれてないか確認する
- 本番公開する前に、メンターさんにもセキュリティ面を確認してね

## レスポンス形式（iOSが期待するJSON）

`Myapp/Services/LensSpecLookup.swift` の `LensSpecLookupResult` と同じ形のJSONです。
