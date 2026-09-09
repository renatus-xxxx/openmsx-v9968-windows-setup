日本語 | [English](publishing.md)

# 公開担当者向け手順

リポジトリ名：openmsx-v9968-windows-setup

Description:
> Unofficial Windows setup scripts for the V9968-enabled openMSX fork, with C-BIOS and user-supplied FS-A1GT BIOS support.

[公開対象一覧](../config/PUBLIC_FILES.txt)、[ライセンス](sources.ja.md)、[リリースノート](release-notes.ja.md)を確認してください。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\validate-public.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\package.ps1
```

ZIP は一覧にあるファイルだけを含み、外側のフォルダは付けません。既定出力は dist/openmsx-v9968-windows-setup-0.5.0.zip です。既存 ZIP は上書きしません。

runtime・cache・private・build・dist と所有 BIOS は Git 管理へ追加しないでください。公開対象の ROM は自作の probe/PROBE.rom だけです。公開前に Git の対象ファイルと ZIP 内容を確認してください。第三者ライセンスは原文を保持してください。

config/PUBLIC_FILES.txt は配布対象を制限する一覧です。ZIP からも再生成できるよう、リポジトリと ZIP の両方に含めます。変更履歴は [CHANGELOG](CHANGELOG.ja.md) にあります。

LICENSE は本文を変更せずルートに保持します。[GitHub のライセンス案内](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository)でもルートへの配置が示されています。

.gitattributes は全体に適用するためルートに保持します。BAT・PowerShell は CRLF、Markdown は LF、ROM・PNG はバイナリ扱いです。文字コード・BOM は指定していません。ZIP 展開自体では Git 属性は実行されませんが、Git で扱う場合にも同じ設定を使用できるよう同梱します。[Git の公式仕様](https://git-scm.com/docs/gitattributes)を参照してください。参照確認日：2026-09-09。

## コマンドの処理と検査範囲

リポジトリルートで実行します。`-NoProfile` は個人の PowerShell プロファイルを読み込まず、`-ExecutionPolicy Bypass` はそのプロセスの実行ポリシーを指定します。恒久的な実行ポリシー変更は行いません。

- `validate-public.ps1`：公開対象一覧の重複・不足・禁止パス、日英文書とローカルリンク、4つのルート BAT と補助スクリプトへの参照、確認 ROM のハッシュを検査します。完成済み ZIP も検査するには `-ZipPath` を指定します。
- `package.ps1`：上記検査後、公開対象一覧のファイルだけで Releases 添付用 ZIP を作成し、収録内容と元ファイルの一致を検査して SHA-256 を表示します。既存の出力 ZIP は上書きしません。

公開対象検査は `config/PUBLIC_FILES.txt` を使用します。ルート外のパス、禁止対象の導入済み環境・生成物、確認 ROM 以外の ROM、テキスト内の個人パス等の特定パターンも検査します。日英文書の冒頭の言語リンクと、BAT から entry.ps1 への参照を確認します。

`-ZipPath` 指定時は ZIP の収録パス・重複・ファイル数を公開対象一覧と比較し、各ファイルの SHA-256 を元ファイルと比較します。省略時は既存 ZIP を検査しません。静的検査であり、外部リンクの到達性、あらゆる個人情報・秘密情報の検出、エミュレーター実行、Git 履歴の検査は行いません。公開対象と Git 差分は別途確認してください。

パッケージ生成では `config/versions.json` の release 値から既定の ZIP 名を決めます。`-OutputZip` で出力先を変更できます。既存 ZIP はリポジトリ外へ保管するか別名を指定してください。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\validate-public.ps1 -ZipPath dist\openmsx-v9968-windows-setup-0.5.0.zip
```

## GitHub Releases での配布

1. 検査済みの `dist/openmsx-v9968-windows-setup-0.5.0.zip` を添付用アセットとして用意します。`dist/` はローカルの生成先で、Git 管理には追加しません。
2. 公開担当者が最終コミットを確認した後、Releases のリリース作成画面で対象コミット、タグ `v0.5.0`、タイトル `0.5.0`、日英のリリース本文を設定します。
3. ZIP を添付し、ファイル名・内容・SHA-256 を確認して公開します。Source code のアーカイブと混同しないでください。
4. 公開後、README のリンクから ZIP を取得し、SHA-256 が最終 ZIP と一致することを確認します。

上記のコマンドが行うのは、公開対象の検査と ZIP の作成だけです。commit・push・タグ作成・リリース作成は、公開担当者が GitHub 上で行う手順です。
