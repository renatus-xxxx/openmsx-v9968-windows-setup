日本語 | [English](README.md)

# openmsx-v9968-windows-setup

V9968 対応 openMSX 派生版を Windows にセットアップする非公式の補助ツールです。バージョンは **0.5.0**。openMSX 本体や V9968 開発元の公式プロジェクトではありません。

V9968 は MSX 用の VDP（映像表示プロセッサー）です。派生版 openMSX は、本体内蔵の VDP を V9968 に置き換えて動作します。この補助ツールは、検証済みのバージョンをダウンロードし、ハッシュを検査し、V9968 の識別テストまで行って、すぐ動く環境を作ります。

## どちらを選ぶか

| | C-BIOS | FS-A1GT |
|---|---|---|
| 事前に必要なもの | なし（すべて自動取得） | 所有する実機から取得した ROM 2本（[取得手順](docs/bios-dump.ja.md)） |
| 動かせるもの | カートリッジ形式のプログラム | BASIC・ディスクを含む実機相当の環境 |
| 所要時間 | 数分 | 先に ROM の取得作業が必要 |

## 最短の使い方

1. [GitHub Releases](https://github.com/renatus-xxxx/openmsx-v9968-windows-setup/releases) の **Assets** から `openmsx-v9968-windows-setup-0.5.0.zip` をダウンロードし、ZIP **全体**を新しい書込み可能なフォルダへ展開します。ZIP 内から直接 BAT を実行しないでください。
2. `setup-cbios-v9968.bat` を実行するか、所有 BIOS フォルダを `setup-fsa1gt-v9968.bat` へドラッグします。
3. **同じ直下のフォルダ**にある `launch-cbios-v9968.bat` または `launch-fsa1gt-v9968.bat` を実行します。

| 方式 | セットアップ | 起動 |
|---|---|---|
| C-BIOS | `setup-cbios-v9968.bat` | `launch-cbios-v9968.bat` |
| FS-A1GT | `setup-fsa1gt-v9968.bat` | `launch-fsa1gt-v9968.bat` |

直下にあるのはこの4つだけです。環境を作成する `setup-*` が2つ、作成済み環境を起動する `launch-*` が2つです。

成功すると、画面に **VDP ID=3 / V9968 IDENTIFIED** が表示されます。

![C-BIOS で確認 ROM を実行した画面](docs/images/cbios-v9968.png)

これ以外が表示された場合は[トラブル対処](docs/troubleshooting.ja.md)を参照してください。

ダウンロードするのは Assets の [0.5.0 の ZIP](https://github.com/renatus-xxxx/openmsx-v9968-windows-setup/releases/download/v0.5.0/openmsx-v9968-windows-setup-0.5.0.zip) です。**Source code (zip)** と **Source code (tar.gz)** は GitHub が自動生成するリポジトリの控えで、配布用 ZIP ではありません。

## 補助ツール

以下のパスは ZIP 展開先からの相対パスです。

| 用途 | ファイル |
|---|---|
| C-BIOS 確認 | `tools\verify\verify-cbios-v9968.bat` |
| FS-A1GT 確認 | `tools\verify\verify-fsa1gt-v9968.bat` |
| C-BIOS 通常版比較 | `tools\verify\launch-cbios-standard.bat` |
| FS-A1GT 通常版比較 | `tools\verify\launch-fsa1gt-standard.bat` |
| BIOS 結合 | `tools\bios\join-fsa1gt-dump.bat` |
| FS-A1GT BASIC 起動 | `tools\bios\launch-fsa1gt-basic.bat` |
| C ROM 再ビルド | `tools\dev\build-probe.bat` |

## 動作条件と制限

Windows 10/11 x64、標準の Windows PowerShell 5.1 と curl.exe、ネット接続、動作する画面ドライバーが必要です。セットアップには管理者権限・7-Zip・Python・Git・z88dk は不要です。

この構成の C-BIOS は BASIC・Disk BASIC・通常のディスク起動を提供しません。FS-A1GT 版には 4 MiB の統合ファームウェアと 256 KiB の漢字 ROM が必要で、どちらも同梱しません。同梱の `probe/PROBE.rom` は識別テスト用の確認 ROM で、BIOS ではありません。

**VDP ID=3 は、エミュレートした機種が V9968 を返したことの確認です。** 個別のゲーム、描画機能、フレームレート、音源、周辺機器、R800 のコードが動作することを保証するものではありません。

セットアップと起動は、進行状況とエラーを英日併記で表示します。各条件の意味は[トラブル対処](docs/troubleshooting.ja.md)を参照してください。

## 説明書

- [セットアップと構成](docs/setup.ja.md)
- [FS-A1GT ROM の取得・結合](docs/bios-dump.ja.md)
- [C 開発](docs/development.ja.md)
- [トラブル対処・削除](docs/troubleshooting.ja.md)
- [一次資料と第三者ライセンス](docs/sources.ja.md)
- [変更履歴](docs/CHANGELOG.ja.md)

生成される `runtime/`、`cache/`、`private/` は手元に残ります。FS-A1GT の環境には所有 BIOS の複製が含まれるため、配布・公開しないでください。

## 公開担当者向け

パッケージ作成・検査・リリース手順は[公開担当者向け手順](docs/publishing.ja.md)にあります。通常のセットアップ・起動には不要です。
