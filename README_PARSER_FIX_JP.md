# STEP22 パーサー修正版 v1

このZIPは「shattered_crown_echo_STEP22_COMPLETE_GODOT.zip」の完全統合版をもとに、Godot 4.7.2で確認された `scripts/main.gd` 722行目の未宣言変数エラーを修正したものです。

## 修正内容
- `web_touch` (未宣言) を `OS.has_feature("web")` に変更しました。
- Windowsでは最小高さ172、Webでは148という表示意図を維持します。
- 他の `.gd`、`.tscn`、カード、画像、セーブデータ、設定ファイルは変更していません。

## 起動
1. 古いフォルダとは別の場所へZIPを展開します。
2. Godot 4.7.2のプロジェクトマネージャーで展開先の `project.godot` をインポートします。
3. メインシーンの起動はF5、R1-B01試験のシーン `res://ui_trial/battle_ui_step21_lab.tscn` はF6で実行します。
4. Godotでエラーが続く場合はエラー一覧と行番号をスクリーンショットで共有してください。

## テスト状況
ZIP内のファイル内容・差分および整合性を検査しています。Godot 4.7.2による実起動はこの環境では確認していません。
