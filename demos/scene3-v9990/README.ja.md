日本語 | [English](README.md)

# SCENE 3 V9990 比較デモ

## V9968の帯・端補完コマンド事前生成

旧比較版を残したまま、PythonでHMMM/LMMMを事前生成する新しい比較版を追加しました。画素を維持し、通常再生はZ80で4.71%、R800で2.39%改善しています。ROMは2 MiBです。

[実装・起動・測定・再現手順](V9968-PACKETS.ja.md)を参照してください。下表は従来の結果と新しい測定結果を区別してまとめたものです。

| CPU | 再生方式 | 旧V9968 FPS | 新V9968 FPS | 改善 | V9990 FPS |
|---|---|---:|---:|---:|---:|
| Z80 | 通常再生 | 15.82 | 16.56 | +4.71% | 15.13 |
| Z80 | 固定256フレーム | 15.53 | 16.34 | +5.22% | 14.77 |
| R800 | 通常再生 | 15.93 | 16.31 | +2.39% | 20.75 |
| R800 | 固定256フレーム | 15.73 | 16.06 | +2.09% | 20.46 |


既存のSCENE 3と同じ背景・半径88の八面体・128姿勢・水面変形を使う、独立した比較用ROMです。既存デモや公開済みベンチマークを置き換えません。今回は公開ZIPへ追加していません。版Cを含む起動には、リポジトリの成果物一式が必要です。

- **A**：コマンドごとに設定を完結させる移植。
- **B**：V9990のレジスター自動連続書き込みと、不変なARG・WMの設定省略。画像・転送量・素材容量はAと同じ。
- **C**：V9990専用パケットの事前生成とOTIR送信。画素とVRAM配置を維持し、ROMは2 MiB。
- **reference**：今回専用のV9968高速モード＋RGB5比較版。

## 起動

比較用ROMはこのリポジトリに含めていません。配布対象ではないため、数MiBのバイナリを履歴へ残す利点がないからです。先に[開発・再測定](#開発再測定)の手順でビルドしてください。`launch.ps1` は各ROMを `roms.json` と照合し、見つからない場合やハッシュが一致しない場合は再ビルドを促して停止します。

リポジトリ直下の対応するsetup BATで環境を用意し、以下を実行してください。`cbios`はZ80、`fsa1gt`はR800 ROMモードです。通常起動にPythonやz88dkは不要です。
- `tools/benchmark/launch-scene3-v9990-a-{cbios,fsa1gt}.bat`
- `tools/benchmark/launch-scene3-v9990-b-{cbios,fsa1gt}.bat`
- `tools/benchmark/launch-scene3-v9990-c-{cbios,fsa1gt}.bat`
- `tools/benchmark/launch-scene3-v9968-reference-{cbios,fsa1gt}.bat`
- `tools/benchmark/launch-scene3-v9968-packets-{cbios,fsa1gt}.bat`

A/B/Cは通常VDPの機種設定へ`gfx9000`拡張を追加し、GFX9000出力を表示します。referenceは既存のV9968機種設定を使います。同じ固定バージョンのエミュレーターを使い、通常VDPのままではA/B/Cは動きません。

P：一時停止／再開（姿勢と位相を0へ戻す）。W：水面変形ON/OFF。Esc：描画を停止し音を消す。終了はエミュレーターのウィンドウを閉じてください。

設定・作業コピーは `%LOCALAPPDATA%/openmsx-v9968-windows-setup/scene3-v9990/<mode>/<variant>/<ROM hash>` に分離します。`launch.ps1 -Runtime <path> -UserRoot <path>` で変更できます。所有BIOSはこの専用領域へローカルコピーします。元runtime、BIOS、通常デモの設定は変更しません。削除時は全ウィンドウを閉じ、この専用領域だけを削除してください。

## 測定結果

固定256フレーム、5秒ウォームアップ、独立起動3回。単位は表示FPSです。

| CPU | V9968 | V9990 A | V9990 B | B / A |
|---|---:|---:|---:|---:|
| Z80 | 15.53 | 3.03 | 5.42 | 1.79x |
| R800 | 15.73 | 6.44 | 10.48 | 1.63x |


A・Bを対象とした従来の比較ではV9968比較版が最速です。版Cの追加結果は次節に示します。実機性能の比較ではありません。通常再生と詳細時間は[検証結果の詳細（JSON）](results/measurements.json)、再現条件・ハッシュは[provenance.json](results/provenance.json)を参照してください。

## 版Cの追加測定

| CPU | V9968比較版 | V9990 B | V9990 C | C / B | C / V9968 |
|---|---:|---:|---:|---:|---:|
| Z80 | 15.53 | 5.42 | 14.77 | 2.72x | 0.95x |
| R800 | 15.73 | 10.48 | 20.46 | 1.95x | 1.30x |

固定256フレーム列・独立起動3回の平均FPS。版Cは最終ROMで再測定しました。BとV9968はROMハッシュ・実行条件が一致する既存結果を再利用しています。Z80ではV9968に近づき、R800では上回りました。エミュレーター内の実装比較であり、実機の性能を保証しません。

[版Cの最適化・検証・再現手順](OPTIMIZATION-C.ja.md) / [比較結果（JSON）](results-c/comparison.json) / [版Cの検証記録](results-c/provenance.json)。A・B・V9968のROMと従来のresults/は維持しています。

## 描画条件

B1/BP4、256×212の上256×192を比較領域に使用し、下20行はパレット色0の暗色です。16色RGB5を共有します。背景、作業、表裏、HUDを論理VRAM先頭128 KiBへ配置し、残り384 KiBは未使用です。色番号0を透明とする固定HUDは水面処理の後に重ねます。左右は端画素を反復し、上下は元の2行単位のクランプ計算を再現します。

全128姿勢と全256位相の計385サンプルで、作業・表示画像を独立した参照モデルと比較しました（全組み合わせの総当たりではありません）。3版×2機種で差0。さらに明るい格子背景の385サンプル×3版でも差0です。[画素検証](results/pixels.json)、[端処理](results/edges.json)、[入力・PSG・連続再生](results/integration.json)。A/Bの両CPUで16色のRGB5パレットを自動照合しました。1色を意図的に変更した検査も、不一致として検出しました。

## 開発・再測定

リポジトリのルートから実行します。ビルドにz88dkとPython 3、素材再生成・画素検証にPillowが必要です。追加ライブラリをROMへ導入していません。

```powershell
python demos/scene3-v9990/build.py --z88dk "<z88dk root>"
python demos/scene3-v9990/build.py --z88dk "<z88dk root>" --regenerate-assets
python demos/scene3-v9990/suite.py --kind verify --runtimes "<runtime parent>" --output "<new private folder>"
python demos/scene3-v9990/suite.py --kind measure --runtimes "<runtime parent>" --output "<new private folder>"
```

`--variant a/b/c/reference`で単独ビルド。`build.ps1 -Z88dk <path>`も利用できます。既定では既存デモROMの素材領域を再利用し、`--regenerate-assets`では専用`build/asset-source`へ素材生成処理をコピーして実行します。元素材は変更しません。A・B・V9968比較版のROMはASCII16・1 MiB、CはASCII16・2 MiBです。未使用シーンのデータも含む既存素材領域を同一のまま使うため、このサイズになっています。

テストの出力先にはROMやFS-A1GT BIOSの私有コピーが含まれます。必ずリポジトリ外の新しい非公開フォルダを指定し、ログをそのまま公開しないでください。公開可能な測定TSVのみ[results/timings](results/timings)へ抜き出しています。再ビルドでROMが変わった場合、過去の測定値を新ROMの結果として扱わず再測定してください。

`main.c`は共通進行、`v9990.c/.h`はVDP固有処理。比較元VDP、マッパー、入力・CPU切替、音楽は隣の`v9968-tech-demo`からビルド時に読み込みます。IM2割り込み・atomicなtick読取り・DIはABI上必要なアセンブラで、隣接コメントに意味を記しています。

## 測定方法・限界

共通RAM 512 KiB、Z80 3,579,545 Hz／R800 7,159,090 Hz（起動後の読戻しで確認）、速度設定100%。同じopenMSX 21.0 V9968 fork d884c4b、`cmdtiming real`、VSyncあり、`maxframeskip 0`、renderer none、録画なし。音声出力はnullでもPSG計算は有効です。通常再生は5秒後から約15秒、固定処理量は5秒後から同じ256組（姿勢=番号mod128、位相=番号）を完了するまで測ります。固定版の要求遅延は1 ms。処理範囲を揃えるため、従来のA・B・V9968比較版の固定測定は約16〜85秒となります。

FPSは完了数÷エミュレーター内経過時間。描画時間はコマンド完了まで、同期待ちは別集計。中央値／P95は描画開始〜表示切り替えであり入力・要求受渡しの間隔を除きます。FPSの分母にはその間隔も含みます。全版共通のvolatileマーカー4箇所に小さなCPU負荷があります。デバッガー停止中のホスト経過時間はFPSに用いません。純粋な送信時間とVDP実行待ちは分離していません。版Cでは別途、ストリーム内のポーリング区間を診断計測しました。3回同値は決定的な再現性の確認であり、実機の誤差範囲ではありません。

Bは連続書き込みと不変レジスター省略を一つの変更単位として測定しました。両変更の寄与は分離していません。追加キャッシュ案は未実装・未測定であり、採用済み最適化として扱いません。実機、Windows 11、全128×256組の総当たり、音声の聴感一致は未検証です。PSGレジスターの変化とEsc後の無音レジスターは確認済みです。

## 出典・謝辞

- [Yamaha V9990マニュアル](https://map.grauw.nl/resources/video/yamaha_v9990.pdf)
- [openMSX GFX9000](https://openmsx.org/manual/user.html#gfx9000) / [cmdtiming](https://openmsx.org/manual/commands.html#cmdtiming)
- [openMSX V9990実装](https://github.com/openMSX/openMSX/tree/master/src/video/v9990)
- MSX 8x8 font：1re1氏。[元デモのフォントの出典と利用条件](../v9968-tech-demo/third-party/fonts/README.ja.md)を保持します。

新規コードは[リポジトリのLICENSE](../../LICENSE)に従います。第三者資料の本文・BIOS・エミュレーターをこのディレクトリに同梱していません。

## 起動直後のキャプチャ

要求駆動で最初の1フレーム直後に停止した場合、VRAM・表示レジスター・パレットが一致していても、エミュレーターのスクリーンショットが部分描画になるケースを確認しました。`screenshot.tcl`は同じ姿勢・位相を2フレーム描画し、ページ切り替え後に取得します。この条件のA/BスクリーンショットはRGB画素も一致しました。通常再生中の連続したページ更新と区別し、この起動時の現象をVDP実機の挙動とは断定しません。

## 比較の解釈と追加検証

旧V9968比較版は、準備済みの矩形コマンドをOTIRで転送し、帯データは実行時に展開して送信します。V9990 A/Bは個別のOUTでレジスターを設定します。今回のFPS差には、このCPU側の送信方式差も含まれます。Bは連続レジスター書き込みと不変設定の省略を施した実装であり、V9990の性能上限やVDP単体の速度を示すものではありません。CPU処理とVDP実行時間の内訳は直接測定していないため、両CPUの結果から推定した時間を実測値として扱いません。この差を減らすため、版Cに事前生成パケットとOTIR送信を追加しました。上記のA・B測定記録は変更していません。

`fps_excluding_request_gaps` は完了フレーム数を、各フレームの描画開始から表示切り替えまでの時間の合計で割った補助指標です。通常の`fps`には要求の受け渡しなどフレーム間隔も含まれます。表示FPSの主指標は引き続き`fps`です。

追加検証は以下のコマンドで再現できます。`<variant>`は`a`、`b`、`c`、`reference`、`<runtime>`は対応するセットアップ済み環境です。毎回、新しい非公開の出力フォルダを指定してください。画像取得と入力検査には`--display`が必要です。低速ホストでは`--timeout 900`などでホスト実時間の上限を延長できます（測定するエミュレーター内時間は変わりません）。

```powershell
python demos/scene3-v9990/run-test.py --variant <variant> --runtime "<runtime>" --script demos/scene3-v9990/edge-fixture.tcl --output "<new edge folder>"
python demos/scene3-v9990/verify.py "<new edge folder>" --variant <variant> --fixture
python demos/scene3-v9990/run-test.py --variant <variant> --runtime "<runtime>" --script demos/scene3-v9990/integration.tcl --output "<new input folder>" --display
python demos/scene3-v9990/run-test.py --variant <variant> --runtime "<runtime>" --script demos/scene3-v9990/screenshot.tcl --output "<new capture folder>" --display
```

V9990の入力検査は16色のRGB5値も期待値と照合し、不一致なら失敗します。CE停止はFAULT=1、非対応VDPはFAULT=2、垂直同期停止はFAULT=3として記録します。

```powershell
python demos/scene3-v9990/run-test.py --variant a --runtime "<runtime>" --script demos/scene3-v9990/fault.tcl --fault 1 --output "<new fault folder>"
python demos/scene3-v9990/run-test.py --variant a --runtime "<runtime>" --script demos/scene3-v9990/missing-device.tcl --without-target --display --output "<new missing-device folder>"
```

`--fault 3`で垂直同期停止を検査できます。

検証の補足：通常再生での`fps_excluding_request_gaps`も、入力などフレーム間処理を除外します。[異常系と再試行を含む検証結果](results/review-checks.json)も参照してください。`smoke.tcl`は初期化・フレーム数・レジスターを調べる初期診断用です。CE停止検査は、デバッガーからLMMCを開始して入力を与えない故障注入で、通常の描画コマンド列とは区別しています。
