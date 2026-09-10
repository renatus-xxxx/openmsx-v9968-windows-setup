[English](DEVELOPMENT.md)

# 開発・検証

[デモの説明](README.ja.md)

## ビルド

Python 3・Pillow と z88dk が必要です。通常のセットアップ・起動には不要です。このフォルダで実行します。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File build.ps1 -Z88dk "C:\z88dk"
```

`-Z88dk` には実際の配置先を指定します。`generate-fonts.py` と `generate-megarom.py` を毎回実行し、zsdcc で C をコンパイルします。固定領域が16 KiB以内、BSSがCF00未満、ROMが1 MiBであることを検査します。`build/V9968-TECH-DEMO.rom` と配布用 `V9968-TECH-DEMO.rom` を生成します。アセンブリで使う引数の warning 85 と PSG の最適化 warning 110 は残ります。

## 素材と描画

`assets/chamber-source.png`・`assets/seabed-source.png` が編集用の元画像です。`python convert-assets.py` で16色画像を生成します。フォントは [MSX 8x8 font](third-party/fonts/README.ja.md) から変換し、背景タイトルとシーンラベルに合成します。`assets/PROMPT.txt` に画像生成条件を記録しています。

SCREEN 5・256×192・16色で、拡張パレット、HS、LRMMを使用します。ページ0/1で描画と表示を切り替え、ページ3は背景と56×8のシーンラベル、ページ2はテクスチャまたは水の変形元です。Scene 3の上部16行を復元して文字を固定します。

回転・投影、立体の走査線、床・回転パネル・水のパラメーターを事前計算します。固定コードは4000–7FFF、バンク窓は8000–BFFF、64バンクのASCII16-Xです。割り込みはバンクを変更しません。CF00以降は検証情報、D000–D100とD1D1–D1D3はIM2予約領域です。

`platform.c` は独立した実装です。カートリッジ起動時にページ0のBIOSを呼び、turbo Rでのみ CHGCPU(0180h)、A=81h によりR800 ROMモードを選びます。キーボードはPPIのAAh/A9hを使用し、選択レジスターを読み取り後に復元します。ライブラリ由来のコードは含みません。

## 検証

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File test.ps1 -Runtime "C:\path\to\runtime\fsa1gt"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File test-water.ps1 -Runtime "C:\path\to\runtime\fsa1gt"
```

C-BIOSは最後のパスを `cbios` に変更します。`test.ps1` は5シーン、キー1・3・0・W・Esc、VDPエラー、バンク、背景・ラベルを確認します。`test-water.ps1` は無変形と変形時の水処理を独立した参照値と比較します。所有BIOSを含む `test-output/` は公開しません。通常起動の専用データは `runtime/<mode>/user-tech-demo/<SHA-256先頭12文字>/` に保存します。

[0.6.0の検証結果（JSON）](verification.json) を参照してください。実機、別エミュレーター、4 MiB超、18分超の連続再生、音質は未検証です。16ビット時計は約18分で周回します。CPUやフォントの識別成功は、すべての機能の動作保証ではありません。

W キーはキーマトリクスの行5・ビット4です。テストでは Y が切り替えに反応しないこと、W の長押しで再切り替えされないこと、離して押し直すと戻ることを確認します。描画完了時の VRAM も比較し、OFF では退避した画面と一致、ON では変形して異なることを検証します。キー入力はエミュレーターへの注入で、物理キーボードによる操作確認とは区別しています。

## 参考資料

- [Pinned VDP command implementation](https://github.com/buppu3/openMSX/blob/d884c4b/src/video/VDPCmdEngine.cc)
- [Pinned ASCII16-X implementation](https://github.com/buppu3/openMSX/blob/d884c4b/src/memory/RomAscii16X.cc)
- [ASCII16-X](https://www.grauw.nl/projects/ascii-x/ascii16-x/)
- [PPI / keyboard register overview](https://map.grauw.nl/resources/msx_io_ports.php)
- [Keyboard matrices](https://map.grauw.nl/articles/keymatrix.php)

## ティーザー GIF

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File test.ps1 -Runtime "C:\path\to\runtime\fsa1gt" -CaptureScript capture-water.tcl
python make-preview.py "test-output\実行フォルダ\user\screenshots" water-preview.gif
```

最新版ROMのScene 3を16枚撮影し、ニアレストネイバーで2倍（640×480）に拡大、各130msでループします。GIFは無音で約2.08秒の抜粋です。デモ本体のFPSを示すものではありません。`--scale 1` で元のサイズも生成できます。

- [MSX Technical Data Book：1.3.5 キーマトリクス](https://map.grauw.nl/resources/system/msxtech.pdf) (2026-09-10)
