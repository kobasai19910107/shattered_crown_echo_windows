# shattered_crown_echo — STEP 22 統合済みGodotプロジェクト

これは **STEP 1〜22を適用したプロジェクト一式** です。個別のSTEP ZIPを順に適用する必要はありません。

## 使用する本体

- 元となる本体: 以前の `shattered_crown_echo_v1_9_1_web_privacy_checked.zip` (Web Solo v1.9.1候補)
- 適用済み: STEP 1〜22の全パッチ
- Godot: 4.7系を前提とする既存プロジェクト設定（Compatibility Renderer）
- 今回のZIPは**ソロ用Web版コードを基準にしたGodotソース**です。最新のWindows/EOS協力版ではありません。
- テスト用に `config/name` を `shattered_crown_echo STEP22 TEST (Web Solo)` に変更し、元のゲームの `user://` 保存領域を分離しました。
- オンライン協力やEOS通信の動作を、このZIPで保証・検証したものではありません。

## 使い方（Windows）

1. このZIPを**すべて解凍**してください。ZIPの中から直接Godotで開かないでください。
2. Godotの「プロジェクトマネージャー」→「インポート」から、**このフォルダの `project.godot`** を選びます。
3. Godotが素材のインポートを完了したら、左上の「シーン」から `res://ui_trial/battle_ui_step21_lab.tscn` を開き、**F6** を押します。R1-B01とのカード戦闘試験です。
4. **F5** は `main.tscn` のゲーム全体起動です。拠点からのソロ試験をする場合に使います。
5. STEP22のヘッドレス検証は `RUN_STEP22_AUTOTEST.bat` にGodot本体の **exeファイルをドラッグ＆ドロップ**して実施できます。結果はこのプロジェクト内の `STEP22_import_log.txt` と `STEP22_runtime_log.txt` に書き出されます。

## 重要な注意

- 本プロジェクトは、個別パッチの適用条件と静的なリソース参照を検査し、全22STEPの統合に成功したものです。
- **この制作環境にはGodot本体がないため、Godotエディタでのインポート・起動、実戦闘、30連続動作までは確認できていません。**
- 実行後にエラーが出た場合は、`STEP22_import_log.txt` と `STEP22_runtime_log.txt` またはGodotのエラー画面をチャットへ送ってください。
- 実機で確認するまで、現在使っているWindows版・Web公開版のプロジェクトを置き換えないでください。
- フォルダに含まれる `ui_trial` は段階別検証用です。古いSTEPの場面も残っていますが、主な確認画面はSTEP21のボス戦ラボです。
- STEP23の厳密テストは **未適用**です。STEP22が正常起動することを確認後にSTEP23を追加してください。

## 統合チェックで実施したこと

- STEP 1〜22各パッチの検証・適用処理の成功
- `res://` の静的な参照先の存在確認
- `BattleController`、120枚カードマスター、Region1〜6敵データ、`CampaignController`、`main.tscn` が元のWebソースとバイナリ一致することを確認
- STEP21のボス戦ラボ、STEP22の自動テストスクリプトが存在することを確認

**検証状態は「静的・統合チェック合格／Godot実行未確認」です。**
