# 読みたい本リスト

気になった本は **GitHub Issue で1冊1件** 登録します。
→ [読みたい本を登録する](../../../issues/new?template=want-to-read.yml) / [一覧を見る](../../../issues?q=is%3Aissue+is%3Aopen+label%3Awant-to-read)

下の表は `./scripts/sync-want-to-read.sh` で Issue から自動生成される一覧です（Obsidian・オフラインで読むため）。
**直接編集しても次回の同期で上書きされます。** 追加・修正は Issue 側で行ってください。

**優先度の目安**

| 絵文字 | ラベル | 意味 |
| --- | --- | --- |
| 🔥 | `🔥 今すぐ` | 今すぐ読みたい（今の課題に直結している） |
| 🌱 | `🌱 そのうち` | そのうち読みたい |
| 🧊 | `🧊 一応メモ` | 一応メモ（忘れないように置いておくだけ） |

## リスト

<!-- BEGIN:issues -->
| 優先度 | 状態 | タイトル | ジャンル | きっかけ・解決したいこと | 手に入れたいもの | 追加日 | Issue |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 🔥 | 📋 読みたい | [［作って学ぶ］ブラウザのしくみ──HTTP、HTML、CSS、JavaScriptの裏側 WEB+DB PRESS plus](https://www.amazon.co.jp/dp/B0DKDHR8BL) | 💻 技術・エンジニアリング | どのようにブラウザが動くのかを理解したい。 仕事で活かせそう | 「URLを入れてから画面が出るまで」を、図を書きながら同僚に5分で説明できるようになりたい （判定：調べながらでなく、何も見ずにホワイトボードに書ける） | 2026-10-12 | #3 |
| 🔥 | 📋 読みたい | [実践理解！Webアプリケーション セキュリティ［固定版］](https://www.amazon.co.jp/実践理解！Webアプリケーション-セキュリティ［固定版］-Malcolm-McDonald-ebook/dp/B0G4QRX378/ref=books_amz-books_mobile_mfs_wsixnhcumxnet_0?_encoding=UTF8&pd_rd_w=C82I2&content-id=amzn1.sym.0280e418-26c5-47a6-98a4-6f59f619f818&pf_rd_p=0280e418-26c5-47a6-98a4-6f59f619f818&pf_rd_r=0Y86AC2NQCZGTB452G0Y&pd_rd_wg=dwj0V&pd_rd_r=f895e808-36b1-458d-b69b-516185843d89) | 💻 技術・エンジニアリング | 昨今のセキュリティーのインシデントが多いので体系的に学びたい | セキュリティーの基礎知識 | 2026-10-12 | #9 |
| 🔥 | 📋 読みたい | [コードレビューの教科書――なんとなく承認から抜け出すための観点と判断基準](https://www.amazon.co.jp/コードレビューの教科書――なんとなく承認から抜け出すための観点と判断基準-佐藤-晶彦-ebook/dp/B0HD5XSC2N/ref=books_amz-books_mobile_mfs_cp_0?_encoding=UTF8&pd_rd_w=I2YMa&content-id=amzn1.sym.bffaaa92-1e0d-4bdb-bf1d-b2a0bf171d2f&pf_rd_p=bffaaa92-1e0d-4bdb-bf1d-b2a0bf171d2f&pf_rd_r=QJQE4949K8R8PDYWYPA7&pd_rd_wg=mKEdO&pd_rd_r=23152307-96a5-40f8-934d-b9c58f07d37c) | 💻 技術・エンジニアリング | コードレビューをなんとなくで行っているので体系的に学びたい | コードレビューの視点 | 2026-10-12 | #10 |
| 🔥 | 💰 購入済み | [世界で闘う エンジニア・アウトプット力を鍛える本](https://www.amazon.co.jp/dp/B0HD6MDBM5) | 💻 技術・エンジニアリング | 技術的に正しいことを書いても読まれないのを変えたい | 書いた技術記事に、読んだ人から具体的な反応が1件返ってくる状態にする | 2026-10-12 | #15 |
<!-- END:issues -->

---

読み始めるときは、その本のIssue番号を指定して実行します（Issueは自動でcloseされます）。

```bash
./scripts/new-book.sh --issue 1
```
