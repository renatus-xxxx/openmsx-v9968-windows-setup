[English](README.md)

# 画面表示用フォント

- **MSX 8x8 font**：1re1 さんの [MSXPen 公開ソース](https://msxpen.com/codes/-Nq8q6wabU6mJ4onDmYE) を使用。`msx8x8-ascii.asm` に PGT1/PGT2 の元データを抜粋しています。[作者](https://twitter.com/1re1)が示した条件は「公序良俗に反しない限り、ご自由にお使いください」です。本リポジトリのライセンスに置き換えるものではありません。[紹介記事](https://gigamix.hatenablog.com/entry/devmsx/msx-font-gallery)も参照してください。

確認日：2026-09-10。`sources.json` に取得データの SHA-256（ローカル計算値）を記録しています。MSX8x8 は ASCII の字形を使用します。

デモのフォルダで `python generate-fonts.py` を実行すると `assets/fonts.json` を生成します。`build.ps1` からも自動実行します。`generate-megarom.py` はこの共通データからタイトルとシーン番号を生成します。タイトルとシーン番号は、ビルド時に影付きヘッダー帯として HUDLINE の ROM データへ合成します。毎フレーム、完成した画面へ帯を重ね、Scene 3 では文字を固定したまま、その背後の背景が歪みます。編集用の背景 PNG は変更しません。
