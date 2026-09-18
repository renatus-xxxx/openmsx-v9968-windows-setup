日本語 | [English](release-notes.md)

# リリースノート — 0.7.3

既存の internal `0x98` プロファイルに加え、I/O base `0x88` の外付け HRA! V9968 カートリッジに対応しました。コード提供と実機報告をいただいた @herraa1（ahmsx）さんに感謝します。

- Release ZIP に `V9968-TECH-DEMO-external-0x88.rom` を同梱します。ルートの起動 BAT は引き続き internal の `V9968-TECH-DEMO.rom` を openMSX で使用します。
- Windows の `build.ps1` と Linux の `build.py` で `internal-0x98` / `external-0x88` のプロファイルを統一しました。`VDP_BASE` の指定、PORT#4 の初期化、外付けカートリッジ使用時の内蔵 VDP 割り込み処理に対応します。
- 同一の z88dk ツールチェーンで Windows と WSL Ubuntu 24.04 から各1 MiBの ROM を再生成し、両プロファイルともバイト単位で一致しました。
- 最終 internal ROM を固定バージョンの openMSX 派生版上の C-BIOS/Z80 と FS-A1GT/R800 で再検証しました。既存のベンチマーク ROM と測定値は保持しています。

コントリビューターが試験した HRA! bitstream のリビジョン・パス・SHA-256 は[開発手順](../demos/v9968-tech-demo/DEVELOPMENT.ja.md)に記載しています。最終 0.7.3 external ROM の公開前の実機再確認は依頼していません。公開 ROM を使用した実機での動作報告を歓迎します。

Release Assets から `openmsx-v9968-windows-setup-0.7.3.zip` を取得し、新しいフォルダへ展開してください。Windows/openMSX では対応する setup BAT、続いてデモ起動 BAT を実行します。Linux 対応はデモ ROM の再ビルドを対象とし、Windows 用セットアップツールの対応 OS を変更するものではありません。
