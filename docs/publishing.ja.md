日本語 | [English](publishing.md)

# 公開担当者向け手順

リポジトリ名：openmsx-v9968-windows-setup

Description:
> Unofficial Windows setup scripts for the V9968-enabled openMSX fork, with C-BIOS and user-supplied FS-A1GT BIOS support.

[公開対象一覧](../config/PUBLIC_FILES.txt)、[ライセンス](sources.ja.md)、[検証結果](verification.ja.md)、[リリースノート案](release-notes.ja.md)を確認してください。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\validate-public.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\package.ps1
```

ZIP は一覧にあるファイルだけを含み、外側のフォルダは付けません。既定出力は dist/openmsx-v9968-windows-setup-0.5.0.zip です。既存 ZIP は上書きしません。

runtime・cache・private・build・dist と所有 BIOS は Git 管理へ追加しないでください。公開対象の ROM は自作 probe/PROBE.rom だけです。公開前に Git の対象ファイルと ZIP 内容を確認してください。第三者ライセンスは原文を保持してください。

config/PUBLIC_FILES.txt は配布対象を制限する一覧です。ZIP からも再生成できるよう、リポジトリと ZIP の両方に含めます。変更履歴は [CHANGELOG](CHANGELOG.ja.md) にあります。

LICENSE は本文を変更せずルートに保持します。[GitHub のライセンス案内](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository)でもルートへの配置が示されています。

.gitattributes は全体に適用するためルートに保持します。BAT・PowerShell は CRLF、Markdown は LF、ROM・PNG はバイナリ扱いです。文字コード・BOM は指定していません。ZIP 展開自体では Git 属性は実行されませんが、Git で扱う場合にも同じ設定を使用できるよう同梱します。[Git の公式仕様](https://git-scm.com/docs/gitattributes)を参照してください。参照確認日：2026-09-09。
