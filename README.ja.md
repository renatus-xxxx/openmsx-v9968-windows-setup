日本語 | [English](README.md)

# openmsx-v9968-windows-setup

V9968 対応 openMSX 派生版を Windows にセットアップする非公式の補助ツールです。バージョンは **0.5.0**。openMSX 本体や V9968 開発元の公式プロジェクトではありません。

実機 BIOS なしでカートリッジ形式の C プログラムを試す **C-BIOS 版**と、所有実機から取得した ROM を利用する **FS-A1GT 版**を選べます。どちらも検証済みのバージョンをダウンロードし、ハッシュ検査と V9968 の識別まで実行します。

## 最短の使い方

1. ZIP **全体**を新しい書込み可能なフォルダへ展開します。GitHub の **Code → Download ZIP** では自動作成されたリポジトリ名のフォルダを開きます。配布 ZIP では展開先直下に BAT があります。ZIP 内から直接実行しないでください。
2. `setup-cbios-v9968.bat` を実行するか、所有 BIOS フォルダを `setup-fsa1gt-v9968.bat` へドラッグします。
3. **同じ直下のフォルダ**にある `launch-cbios-v9968.bat` または `launch-fsa1gt-v9968.bat` を実行します。

画面の期待値は **VDP ID=3 / V9968 IDENTIFIED**。

| 方式 | セットアップ | 起動 |
|---|---|---|
| C-BIOS | `setup-cbios-v9968.bat` | `launch-cbios-v9968.bat` |
| FS-A1GT | `setup-fsa1gt-v9968.bat` | `launch-fsa1gt-v9968.bat` |

## 補助機能

以下のパスはリポジトリのルートからの相対パスです。

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
- [検証結果と制限](docs/verification.ja.md)
- [一次資料と第三者ライセンス](docs/sources.ja.md)

生成される `runtime/`、`cache/`、`private/` は公開しないでください。FS-A1GT 環境には所有 BIOS が含まれます。

- [変更履歴](docs/CHANGELOG.ja.md)
