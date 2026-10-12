# Kindle購入通知メール → GitHub Issue 連携

Kindleで本を買うと、Amazonから注文確認メールが届きます。それを読んで、
該当するIssueのステータスを **`💰 購入済み`** に自動で変える仕組みです。

**なぜメールなのか**: Kindleには購入履歴を取得する公式APIがありません。
非公式に内部APIを叩く方法はありますが、規約リスクがあり壊れやすいため、
Amazonが自分宛に送ってくる注文確認メールを購入シグナルとして使います。

## 動き

```
Amazonの注文確認メール（digital-no-reply@amazon.co.jp）
  ├ タイトルを取り出す（本文優先 → 件名のパターン）
  └ 本文の商品ページURL /dp/B0HD6MDBM5 からASINを取り出す
      ├ 同じASINを含むIssueがある   → 💰 購入済み にしてコメントを残す
      ├ ASINがない → タイトルでIssueを探す
      └ 見つからない（未登録の購入） → Issueを新規作成（💰 購入済み）
```

### メールの形式が変わっても動くようにしている

Amazonは注文確認メールの形式を何度も変えています。実際に届いているメールを調べたところ、
2年間で少なくとも3種類ありました。

| 時期 | 件名 | タイトル | ASIN |
| --- | --- | --- | --- |
| 2026年〜 | `Amazon.co.jpでのご注文: タイトル` | 件名・本文の両方にある | ✅ あり |
| 2025年頃 | `タイトルからなる注文Amazon.co.jp。` | 件名にある | ❌ なし |
| 2024年頃 | `Amazon.co.jpでのご注文D01-...（1点）` | **件名にない**（本文の `Kindle版` 直前行） | ❌ なし |

そのため、件名よりも形式変更に強い**本文を先に見て**、ダメなら件名のパターンを順に試します。
ASINがないメールではタイトルでIssueを突き合わせます。

- 処理したメールにはGmailラベル（`book-to-action/処理済み`）を付けるので、二重処理されません
- すでに `📖 読書中` / `✅ 読了` / `🛑 辞めた` に進んでいる本は巻き戻しません
- 登録していない本を買った場合はIssueが自動で作られるので、**買ったのに登録を忘れた本が積読のまま消えません**

## セットアップ（10分）

### 1. GitHubのトークンを作る

[Fine-grained personal access token](https://github.com/settings/personal-access-tokens/new) を作成します。

| 項目 | 設定 |
| --- | --- |
| Repository access | Only select repositories → `book-to-action` |
| Permissions → Issues | **Read and write** |
| Permissions → Metadata | Read-only（自動で付きます） |

生成されたトークンをコピーします（この画面を閉じると二度と見られません）。

### 2. Apps Scriptのプロジェクトを作る

1. [script.google.com](https://script.google.com/home/projects/create) で新規プロジェクトを作る
2. `Code.gs` の中身を、このフォルダの `Code.gs` で全部置き換える
3. プロジェクト名を `book-to-action` などにする

### 3. トークンを登録する

プロジェクトの **歯車（プロジェクトの設定）→ スクリプト プロパティ** で追加します。

| プロパティ | 値 |
| --- | --- |
| `GITHUB_TOKEN` | 手順1でコピーしたトークン |
| `REPO` | `kawafuchieirin/book-to-action`（既定値と同じなら省略可） |

**トークンをコードに直接書かないでください。** スクリプトプロパティはコードと別に保存されます。

### 4. 動作確認する

関数の一覧から **`checkSetup`** を選んで実行します。初回は権限の承認を求められます
（Gmailの読み取りと外部通信）。

ログにこう出れば成功です。

```
リポジトリに接続できました: kawafuchieirin/book-to-action
購入通知メール: 1 件見つかりました
  世界で闘う エンジニア・アウトプット力を鍛える本 / ASIN=B0HD6MDBM5
```

ASINが `(取得失敗)` になる場合は、メールの形式が変わっています。`asinFromBody_` の
正規表現を直してください。

### 5. 自動実行にする

**時計のアイコン（トリガー）→ トリガーを追加** で設定します。

| 項目 | 値 |
| --- | --- |
| 実行する関数 | `syncKindlePurchases` |
| イベントのソース | 時間主導型 |
| 時間ベースのトリガー | 日付ベースのタイマー |
| 時刻 | 任意（深夜帯が無難） |

1日1回で十分です。購入直後に反映したいときは `syncKindlePurchases` を手動実行すればOKです。

## 設定項目

スクリプトプロパティで上書きできます。

| プロパティ | 既定値 | 意味 |
| --- | --- | --- |
| `REPO` | `kawafuchieirin/book-to-action` | 対象リポジトリ |
| `CREATE_IF_MISSING` | `true` | 未登録の購入でIssueを作るか。`false` でログだけ |
| `PROCESSED_LABEL` | `book-to-action/処理済み` | 処理済みメールに付けるGmailラベル |
| `SEARCH_DAYS` | `30` | 何日前までのメールを見るか |

## うまく動かないとき

| 症状 | 原因と対処 |
| --- | --- |
| `GITHUB_TOKEN が未設定です` | 手順3のスクリプトプロパティを確認 |
| `GitHub API 404` | トークンの Repository access に対象リポジトリが入っていない |
| `GitHub API 403` | Issues 権限が Read and write になっていない |
| メールが0件 | 件名が変わった可能性。Gmailで `from:digital-no-reply@amazon.co.jp` を検索して確認 |
| 領収書メールが消えている | **Gmailのゴミ箱は30日で自動削除されます。** 下の「領収書を消さないようにする」を参照 |
| 同じ本が二重にIssueになる | Issueの購入リンクにASINが入っていない。`/dp/<ASIN>` を含むURLに直す |

## 領収書を消さないようにする

**このスクリプトはメールが残っていることが前提です。** Gmailのゴミ箱は30日で自動削除されるため、
領収書メールを消す習慣があると過去の購入は追えなくなります。

Gmailの設定 → フィルタとブロック中のアドレス → 新しいフィルタを作成 で、次のように設定してください。

| 項目 | 値 |
| --- | --- |
| From | `digital-no-reply@amazon.co.jp` |
| 適用する処理 | 「ラベルを付ける」→ `Kindle購入` を選択 |
| | 「削除しない」にもチェック |

これで購入メールが誤って消えず、過去分も追えるようになります。

## 過去の購入をまとめて登録したい

メールが残っていない期間は、Amazon側の記録から取るのが確実です。

| 方法 | 内容 |
| --- | --- |
| [コンテンツと端末の管理](https://www.amazon.co.jp/hz/mycd/myx) | 所有しているKindle本の全一覧。購入日も表示される |
| [データリクエスト](https://www.amazon.co.jp/hz/privacy-central/data-requests/preview.html) | 購入履歴のCSVを公式に取得できる（届くまで数日） |

## 紙の本を買った場合

このスクリプトはKindle（`digital-no-reply@amazon.co.jp`）だけを対象にしています。
紙の本は送信元が違う（`shipment-tracking@amazon.co.jp` など）ので、
必要なら `syncKindlePurchases` の `query` に条件を足してください。
