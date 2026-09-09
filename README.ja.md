日本語 | [English](README.md)

# openmsx-v9968-windows-setup

V9968 対応 openMSX 派生版を Windows にセットアップする非公式の補助ツールです。バージョンは **0.5.0**。openMSX 本体や V9968 開発元の公式プロジェクトではありません。

実機 BIOS なしでカートリッジ形式の C プログラムを試す **C-BIOS 版**と、所有実機から取得した ROM を利用する **FS-A1GT 版**を選べます。どちらも検証済みのバージョンをダウンロードし、ハッシュ検査と V9968 の識別まで実行します。

## 最短の使い方

1. [GitHub Releases](https://github.com/renatus-xxxx/openmsx-v9968-windows-setup/releases) の **Assets** から `openmsx-v9968-windows-setup-0.5.0.zip` をダウンロードし、ZIP **全体**を新しい書込み可能なフォルダへ展開します。ZIP 内から直接 BAT を実行しないでください。
2. `setup-cbios-v9968.bat` を実行するか、所有 BIOS フォルダを `setup-fsa1gt-v9968.bat` へドラッグします。
3. **同じ直下のフォルダ**にある `launch-cbios-v9968.bat` または `launch-fsa1gt-v9968.bat` を実行します。

画面の期待値は **VDP ID=3 / V9968 IDENTIFIED**。

| 方式 | セットアップ | 起動 |
|---|---|---|
| C-BIOS | `setup-cbios-v9968.bat` | `launch-cbios-v9968.bat` |
| FS-A1GT | `setup-fsa1gt-v9968.bat` | `launch-fsa1gt-v9968.bat` |

[0.5.0 の ZIP](https://github.com/renatus-xxxx/openmsx-v9968-windows-setup/releases/download/v0.5.0/openmsx-v9968-windows-setup-0.5.0.zip)。**Source code (zip)** / **Source code (tar.gz)** は配布用 ZIP ではありません。直下には環境を作成する `setup-*` が2つ、作成済み環境を起動する `launch-*` が2つあります。

## 補助機能

以下のパスは ZIP 展開先からの相対パスです。

| 用途 | ファイル |
|---|---|
| C-BIOS 自動確認 | `tools\verify\verify-cbios-v9968.bat` |
| FS-A1GT 自動確認 | `tools\verify\verify-fsa1gt-v9968.bat` |
| C-BIOS 通常版比較 | `tools\verify\launch-cbios-standard.bat` |
| FS-A1GT 通常版比較 | `tools\verify\launch-fsa1gt-standard.bat` |
| BIOS 結合 | `tools\bios\join-fsa1gt-dump.bat` |
| FS-A1GT BASIC 起動 | `tools\bios\launch-fsa1gt-basic.bat` |
| C ROM 再ビルド | `tools\dev\build-probe.bat` |

Windows 10/11 x64、標準の Windows PowerShell 5.1 と curl.exe、ネット接続、動作する画面ドライバーが必要です。セットアップには管理者権限・7-Zip・Python・Git・z88dk は不要です。

この構成の C-BIOS は BASIC・Disk BASIC・通常のディスク起動を提供しません。FS-A1GT 版には4 MiBの統合ファームウェアと256 KiBの漢字 ROM が必要で、どちらも同梱しません。`probe/PROBE.rom` は自作の確認アプリで、BIOS ではありません。

## 説明書

- [セットアップと構成](docs/setup.ja.md)
- [FS-A1GT ROM の取得・結合](docs/bios-dump.ja.md)
- [C 開発](docs/development.ja.md)
- [トラブル対処・削除](docs/troubleshooting.ja.md)
- [一次資料と第三者ライセンス](docs/sources.ja.md)

生成される `runtime/`、`cache/`、`private/` は公開しないでください。FS-A1GT 環境には所有 BIOS が含まれます。

- [変更履歴](docs/CHANGELOG.ja.md)

## 開発・配布用のコマンド

通常のセットアップ・起動には不要です。リポジトリまたは ZIP 展開先のルートで実行します。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\validate-public.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\package.ps1
```

- `validate-public.ps1`：公開対象一覧の重複・不足・禁止パス、日英文書とローカルリンク、4つのルート BAT と補助スクリプトへの参照、確認 ROM のハッシュを検査します。完成済み ZIP も検査するには `-ZipPath` を指定します。
- `package.ps1`：上記検査後、公開対象一覧のファイルだけで Releases 添付用 ZIP を作成し、収録内容と元ファイルの一致を検査して SHA-256 を表示します。既存の出力 ZIP は上書きしません。

出力先、検査範囲、Releases への添付方法は[公開担当者向け手順](docs/publishing.ja.md)を参照してください。
