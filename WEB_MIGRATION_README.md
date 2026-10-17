# shattered_crown_echo v1.9.1 — Webソロ移行候補（未起動検証）

これはアップロードされたWindows版 v1.9.1 ZIPを **一切変更せず** 生成した、独立したWeb移行用のソース候補です。
正式完成品・iPhone実機動作確認済みではありません。

## 何を保持したか
- 基本の `main.tscn`, `scripts/` (EOS固有2本を除く), `data/`, `assets/`
- 戦闘・120枚カード・装備・拠点・敵・セーブ処理のコード
- 1280x900の元UI（当面はiPhone横向き推奨、タッチ最適化は未実施）

## 変更した内容
- Webで利用できないEOSGネイティブ拡張とAutoloadをWeb版から除外
- 協力ロビーは既存のWebSocket中継方式に限定。ただし **公開WSS中継サーバー未設定につきオンライン協力は使えません**
- 初期デッキ生成の `Thread.start` をWeb時には同じ処理のメインスレッド遅延実行へ置き換え。**重い計算中にSafariが固まる懸念あり。実用化前に段階分割が必要**
- Web export preset とGitHub Pages用GitHub Actionsを追加
- GitHubへ余計なSDKバイナリ・過去ZIP・機密ローカル設定を登録しないよう整理

## Web公開の前提
1. 新規の *別リポジトリ* を作成すること（nine-frontsへ上書きしない）。
2. GitHubにこのZIPの **展開後の中身** をそのリポジトリのルートへ登録すること。
3. Actions `Godot import` と `Main-scene smoke test` および `Web export` が全て成功したことを確認。
4. Settings → Pages → Build and deployment → GitHub Actions を設定。
5. iPhone Safariで実プレイ・初期6装備取得・HUD/カードタップ・拠点・戦闘・保存復帰を試す。

## 制約と注意
- EOS Windowsオンライン協力はWeb候補に存在しません。Windows版は変更していません。
- 初期装備生成のWeb用処理は原則同アルゴリズムですが、メインスレッド上で重く、Safariが操作不能になる可能性があります。
- Windowsの `user://` セーブデータはブラウザに自動引き継がれません。
- Web側のデータはSafariのサイトデータ削除、プライベートブラウズ等で消える場合があります。
- GitHubのPublicリポジトリに置くとソース・画像等を第三者が閲覧できます。権利関係を確認してください。
- `addons` を除外しているため、Windows側のEOS機能をこのZIPで代替しないでください。
- この環境にGodot実行環境がないため、Godot構文・実起動・Web exportは **未テスト** です。GitHub Actionsで初めて実行判定します。

## Public repository safety pass
- Windows absolute personal workspace paths in 5 test files were replaced with portable `user://test_outputs/` paths.
- Blank EOS credentials template included for documentation only. Never commit a populated `eos_client.cfg`.
- For reduced iPhone download sizes, monster PNG artwork in this Web copy was downscaled to at most 1024px and converted to WebP quality 82, maintaining transparency. Original full-resolution artwork remains in the private original ZIP.
- No email addresses, phone numbers, or non-empty EOS secrets detected by static scans; audit does not guarantee absence of all confidential data.
