# STEP22 完全統合版 v2：戦闘演出の不具合修正

このZIPは `STEP22_COMPLETE_GODOT_FIXED_v1.zip` のソースへアニメーション修正だけを統合したGodotプロジェクトです。最初からSTEP別パッチを順に適用する必要はありません。

## 修正したファイル

- `ui_trial/actors/actor3h.gd`：防御カードで剣を振らず、ガード姿勢＋青いシールド枠を再生する `play_guard` を追加。
- `ui_trial/actors/region1_unique_enemy_visual.gd`：表示中の `UniqueR1Art` を直接被弾アニメーションさせるよう変更。非表示の旧モブに反応を送る不具合を修正。
- `ui_trial/battle_ui_step9.gd`：Attack／防御カード／その他Skill・Powerでモーションを分離。敵にヒットする非Attackカードでも表示専用の被弾演出を再生。
- `ui_trial/live_bridge.gd`：従来UI内のプレビュードックにも防御専用モーションを反映。

カード効果・Mana消費・HP・敵Intent・セーブ・オンライン通信ロジックは変更していません。

## 手順
1. 元のGodotプロジェクトは残し、このZIPを別フォルダに展開する。
2. Godot 4で `project.godot` をインポートし、F5でタイトル画面を起動する。
3. 「最初から」または試験用のセーブからソロで戦闘を開始する。
4. C061のようなBlockカードで「ガード姿勢（剣を振らない）＋青いシールド枠」を確認する。
5. C089などAttackを敵に当て、表示中のR1モブが後退・赤く点滅・復帰するかを確認する。
6. ターン終了で敵攻撃とHP変化を確認する。
7. 必要に応じて `ui_trial/battle_ui_step21_lab.tscn` をF6で実行し、ボスを確認する。

## テスト状態
- ZIPの整合性と修正箇所の静的検査は実施。
- Godotでの実起動／動作検証はユーザー側のWindows環境で必要。
- 既存のセーブを上書きしないよう、試験は別フォルダ／試験専用データで実施する。
