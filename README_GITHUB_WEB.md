# shattered_crown_echo Web移行版（ソロ候補）

Godot 4.7.2 / 元Windows版v1.9.1から独立したWeb移行候補。

**状態：ソース移行と静的検査済み。Godot/ブラウザ実機テストは未完了。**

- EOSネイティブ拡張を除外したため、Windows版のEOS協力プレイはこの版では使用できません。
- iPhone Safariでは横向きを推奨。PC向けの1280x900 UIを使用中で、タッチUI最適化は未完了です。
- ソロプレイの動作・初期装備生成・保存復元をGitHub Actionsと実機で確認する必要があります。
- GitHub Pagesで公開するには、リポジトリ Settings > Pages > Source を GitHub Actions に設定してください。
- 詳細は WEB_MIGRATION_README.md と PRIVACY_AUDIT.md を参照してください。

## Windowsからの登録

この展開済みフォルダ内の `PUBLISH_TO_GITHUB.cmd` をダブルクリックします（Git for Windowsが必要）。
GitHub認証画面が出たら自分のアカウントでサインインしてください。スクリプトは空リポジトリへの最初の登録専用で、既存のmainブランチには強制上書きしません。

GitHub公開予定: https://kobasai19910107.github.io/shattered_crown_echo/
