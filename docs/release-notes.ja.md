日本語 | [English](release-notes.md)

# リリースノート — 0.6.0

[トップ](../README.ja.md)

MSX 8x8 font を使用する5シーンの V9968 TECH DEMO を追加しました。立体、遠近感のある床、水中の揺らぎ、回転する大型パネルを PSG BGM とともに再生します。

同じシーンを V9968 と従来 VDP で描画して比較できる別 ROM、SCENE3 BENCHMARK を追加しました。F で FULL・FAST・COMPAT を切り替え、画面に VDP・CPU・FPS を表示します。

セットアップ・起動・BIOS 結合の各処理が、進行状況とエラーをすべて英日併記で表示するようになりました。VDP の識別に失敗した場合は、実際に読めた値もあわせて表示します。

Releases の Assets から 0.6.0 の ZIP 全体を展開し、対応する setup BAT を実行してください。起動は `launch-v9968-tech-demo-fsa1gt.bat` または `launch-v9968-tech-demo-cbios.bat` です。識別画面は `tools/verify/launch-*-v9968.bat` に移動しました。

0.5.0 の環境はそのまま残せます。0.6.0 は別フォルダへ展開してセットアップしてください。既存環境を使う上級者はデモ BAT へ `-Runtime "既存 runtime の機種フォルダ"` を指定できます。旧環境の移動や上書きは行いません。

BIOS・エミュレーター実行ファイルは同梱しません。[デモの制限](../demos/v9968-tech-demo/README.ja.md)と[ベンチマークの測定条件](../demos/scene3-benchmark/README.ja.md)も参照してください。
