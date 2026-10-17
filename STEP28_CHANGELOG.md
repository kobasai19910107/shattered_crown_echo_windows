# STEP28 戦闘画面レイアウト・UI完成

## 変更内容

- 上部HUDを80pxへ整理し、P1 HP/Block、敵名・HP、敵別Intent、TURNを集約。
- 1280×900で戦場を `Y=80〜685`、下部UIを `Y=685〜900` に配置。
- 1280×720の基準座標と既存 `_vertical_extra` を維持し、全表示倍率を等方スケールに限定。
- 本編キャンペーン戦闘ではSTEP番号、Battle Core説明、プリセット切替を含む検証ツールバーを非表示化。検証シーンの機能は維持。
- 下部UIを左のMana/山札/捨て札、中央の手札5枚、右の使用/解除/ターン終了へ整理。
- `ui_trial/step28_battle_card.gd` を追加。Cost、カードID/役割、種別、属性/武器、効果本文を表示する共通カード部品とした。
- 属性別フレーム色、金属調の濃紺フレーム、選択時の10px上昇・発光、敵対象の金色強調を追加。
- 6枚以上の手札ページ切替、全文ツールチップ、選択・確定・解除の既存操作を維持。
- 通常カードではカットインを表示せず、C012を含む決着技だけ既存カットインを表示する構成を維持。
- 1280×900と1280×720のWeb実画面を `step28_artifacts/` に保存。

## 変更していない範囲

- `scripts/battle_controller.gd` を含むBattle Core
- カード120枚、敵、装備のデータと計算
- 敵AI、ターン、Intent、セーブ・ロード、報酬、進行
- 3頭身プレイヤー、R1-B01の13パーツリグ、Tween、属性演出
- Web Soloのエクスポート方式とWindows/EOS協力コード

## 変更ファイル

- `.gitignore`
- `ui_trial/battle_ui_step9.gd`
- `ui_trial/step28_battle_card.gd`
- `tests/step28_battle_layout_test.gd`
- `STEP28_CHANGELOG.md`
- `STEP28_TEST_REPORT.md`
- `step28_artifacts/STEP28_1280x900.png`
- `step28_artifacts/STEP28_1280x720.png`
