日本語 | [English](sources.md)

# 一次資料とライセンス

[トップ](../README.ja.md)

バージョン・ハッシュは2026-09-09に確認しました。配布元の最新バージョンへ自動追従する構成ではありません。

| 内容 | 一次資料 |
|---|---|
| 公式リリース | [openMSX 21.0](https://github.com/openMSX/openMSX/releases/tag/RELEASE_21_0) |
| 公式 ZIP の digest | [GitHub リリース API](https://api.github.com/repos/openMSX/openMSX/releases/tags/RELEASE_21_0) |
| 派生版配布と実機との差 | [buppu3](https://buppu3.github.io/) |
| 派生版ソース | [v9968 ブランチ](https://github.com/buppu3/openMSX/tree/v9968) |
| C-BIOS の状況 | [C-BIOS Association](https://cbios.sourceforge.net/) |
| 機種・ROM の設定 | [openMSX セットアップガイド](https://openmsx.org/manual/setup.html) |
| ダンプツール | [blueMSX 開発元リソース](https://www.vik.cc/bluemsx/resource.html) |
| C ツールチェーン | [z88dk MSX](https://github.com/z88dk/z88dk/wiki/Platform---MSX) |
| V9968 識別例 | [HRA! devcon](https://github.com/hra1129/V9968_Cartridge/tree/main/fpga/V9968_Cartridge_TangNano20K/src/v9968/devcon) |
| 描画サンプル | [HRA! test_pattern](https://github.com/hra1129/V9968_Cartridge/tree/main/fpga/V9968_Cartridge_TangNano20K/src/v9968/test_pattern) |
| プログラミングマニュアル | [HRA! manual](https://github.com/hra1129/V9968_Cartridge/tree/main/fpga/V9968_Cartridge_TangNano20K/src/v9968/manual) |

URL・ZIP サイズ・ハッシュは [config/versions.json](../config/versions.json) を単一の機械処理用情報として管理します。SHA-256 の照合は配布元の電子署名の代わりにはなりません。実機 BIOS ROM のダウンロード先は提供しません。

## ライセンス

- 新規スクリプト・確認 ROM・デモのソース：[MIT LICENSE](../LICENSE)。
- 参考機種 XML は公式 openMSX 21.0 由来で GPL を保持：[GPL 原文](../licenses/GPL-openMSX.txt)。VDP・表示名の変更内容と日付を XML に記載しています。セットアップでも公式定義へ同じ変換を適用します。
- C-BIOS は2条項BSD：[原文表示](../licenses/C-BIOS.txt)。BIOS は公式 openMSX とともに取得し、この配布 ZIP には同梱しません。
- 確認 ROM とデモ ROM には z88dk のライブラリコードを利用：[z88dk 原文](../licenses/z88dk.txt)。個別ファイルの条件がある場合に、この説明が置き換えるものではありません。
- 第三者のダンプツールはリンクのみで再配布しません。所有実機の ROM と導入済み環境も除外します。

原文ライセンスは変更せず保持しています。この日本語説明は補足であり、ライセンスの翻訳正文ではありません。別途エミュレーター一式を再配布する場合は、そのパッケージのソース提供・表示等の条件を確認してください。本ツールの公開準備は、その別パッケージの条件確認を代行するものではありません。

- デモの MSX 8x8 font は 1re1 さんの作品です。[出典・利用条件](../demos/v9968-tech-demo/third-party/fonts/README.ja.md)を参照してください。フォントの条件はリポジトリの MIT ライセンスとは別です。
