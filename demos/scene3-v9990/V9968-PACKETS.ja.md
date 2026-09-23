[English](V9968-PACKETS.md) | [比較デモ](README.ja.md)

# V9968の水面コマンド事前生成

Pythonで水面の帯本体と端補完のコマンドを生成し、実行時の準備処理を減らしました。通常再生はZ80で4.71%、R800で2.39%改善しました。ROMは1 MiBから2 MiBへ増えます。旧版・V9990各版・通常デモのROMと過去の測定結果は維持しています。

## 起動と実装

- Z80：[launch-scene3-v9968-packets-cbios.bat](../../tools/benchmark/launch-scene3-v9968-packets-cbios.bat)
- R800：[launch-scene3-v9968-packets-fsa1gt.bat](../../tools/benchmark/launch-scene3-v9968-packets-fsa1gt.bat)
- ROM：`SCENE3-V9968-PACKETS.rom`。既存のセットアップ環境を利用し、ユーザー設定は比較用の別領域に保存します。
- 機種選択・`-Runtime`・`-UserRoot`・`-VerifyLaunch`は既存の比較用ランチャーと同じです。Wで水面を切り替え、Pで姿勢を固定、Escで停止・消音します。

`generate-v9968-packets.py`は既存ROMの帯データを読み、R32〜R46の15バイト列を生成します。帯本体はHMMM (0xD0)、左右の端は従来と同じ1画素幅のLMMM (0x90) を2回送ります。画像の補間ではなく、端画素の繰り返しです。座標・高さ・幅・命令・ソースページ2は生成時に確定します。

各レコードは16bitコマンド数とコマンド列で構成し、4,096バイト境界に配置します。実行時はCE完了待ち後、R17を32へ設定し、OTIRで7バイト、宛先Y上位のページ値1バイト、OTIRで残り7バイトを送ります。変更するのはオフセット7の宛先ページだけです。コマンド数・順序・転送範囲は旧版と同じで、VDPで行う処理を省略していません。

`v9968-water-packets.inc`には切り替えてビルドできる同等のC言語での実装も隣接させています。`--c-stream`は診断用`SCENE3-V9968-PACKETS-C.rom`を別生成します。この切り替えは新しい水面送信処理が対象で、割り込み・矩形描画など既存のアセンブラ全体を置き換えるものではありません。

共有の`v9968.c`は変更せず、専用ビルド先で水面関数部分だけを差し替えます。生成器は既存のバンク配置を検査し、想定外なら停止します。

## メモリー配置

| 領域 | 内容 |
|---|---|
| ROMバンク0 | 固定コード。16 KiB以内を検査 |
| 既存バンク1〜63 | 素材・128姿勢・背景・固定ヘッダーを保持。例外は下記の恒等変換レコード |
| バンク54先頭 | 水面OFF用の恒等変換を15バイトコマンド形式へ変換 |
| バンク64〜127 | 256位相×4 KiB。各レコードは16 KiBバンク境界をまたがない |
| バンク127末尾 | `S3WP`マーカー。起動時に上位バンクへのアクセスを検査 |
| VRAM | 従来どおりページ0/1表示、2作業・姿勢キャッシュ、3背景・ヘッダー |

水面は1位相111〜137コマンド、平均123.27。実データ473,882バイトに対し、アドレス計算を簡単にするため1,048,576バイトを予約します。水面OFFは1コマンドです。追加の画像キャッシュはありません。BSS終端は両実装とも0xC077で、計測領域0xCF00と重なりません。ASCII16の2 MiBマッピングを今回のopenMSXで確認しました。実機・実カートリッジ互換性は未確認です。

## 測定結果

| CPU | 再生方式 | 旧V9968 FPS | 新V9968 FPS | 改善 | V9990 FPS |
|---|---|---:|---:|---:|---:|
| Z80 | 通常再生 | 15.82 | 16.56 | +4.71% | 15.13 |
| Z80 | 固定256フレーム | 15.53 | 16.34 | +5.22% | 14.77 |
| R800 | 通常再生 | 15.93 | 16.31 | +2.39% | 20.75 |
| R800 | 固定256フレーム | 15.73 | 16.06 | +2.09% | 20.46 |

描画時間／同期待ち（ms、各3回の平均）は以下のとおりです。`animated`は通常再生、`sequence`は固定256フレームです。

| CPU | Mode | Old draw / sync ms | New draw / sync ms | V9990 draw / sync ms |
|---|---|---:|---:|---:|
| Z80 | animated | 54.86 / 7.69 | 50.05 / 9.65 | 57.25 / 8.16 |
| Z80 | sequence | 55.60 / 7.74 | 50.49 / 9.66 | 58.03 / 8.64 |
| R800 | animated | 54.14 / 8.30 | 52.03 / 8.94 | 37.55 / 10.31 |
| R800 | sequence | 54.57 / 7.96 | 52.52 / 8.71 | 37.75 / 10.11 |

Z80では新V9968版がV9990版を上回り、R800ではV9990版が上回りました。固定列の描画時間はZ80で55.60→50.49 ms、R800で54.57→52.52 msです。同期待ちの増加が一部を相殺するため、描画時間の短縮率とFPSの改善率は一致しません。CPU側の準備処理を減らした結果であり、VDP自体の実行速度が変わったことを示す測定ではありません。

同じopenMSX 21.0 V9968 fork d884c4b、Z80 3,579,545 Hz／R800 ROMモード7,159,090 Hz、RAM 512 KiB、速度100%、`cmdtiming real`、VSync有効、`maxframeskip 0`で比較しました。録画せずrenderer none、throttle false、音声null（PSG処理は有効）。5秒ウォームアップ後に約15秒、固定列は同じ256組を完了するまで測り、それぞれ独立起動3回です。

FPSは完了フレーム数÷エミュレーター内経過時間です。描画時間はCE完了まで、同期待ちは描画完了からページ切り替えまで。中央値・95パーセンタイルは[測定記録](results-v9968-packets/measurements.json)にあります。通常再生は同じ時間軸で進むため、速度の違いにより描画する姿勢・位相の標本は変わります。固定列では同じ256組を使用します。

旧V9968・V9990の測定値は、ROM・エミュレーター・機種XML・測定スクリプトのハッシュと設定の一致を確認して既存記録を再利用しました。今回新たに実施した性能測定は新V9968版の12回です。旧V9968の画素検査は今回再実施しています。

V9968とV9990では転送命令、VRAM構成、表示タイミングが異なります。また、継承したV9968機種XMLの`timing=0`の影響は分離測定していません。コマンド準備方式の差を減らした比較であり、完全に同一条件でもVDP単体の性能比較でもありません。実機性能への外挿は行いません。

## 検証

- 生成器の全256位相＋恒等変換：12,632,064画素分の転送元対応を検査。穴・重複なし。座標、命令、偶数幅、レコード／バンク境界、上位バンクマーカー、不正な入力の拒否を確認。
- 両CPUで旧版・新版・C言語の送信版をそれぞれ385サンプル検査。独立した画素期待値と一致。
- 旧版対新版、アセンブラ対C言語の送信版について、両CPUの全385サンプルで128 KiB VRAM全体が一致。
- 新版は両CPUで格子背景を用いた385サンプルも検査。左右・上下端、作業画像、固定ヘッダーに不一致なし。
- 同一姿勢・位相の安定表示でRGBスクリーンショットとパレットを旧版と比較。
- 両CPUで連続再生、W切り替え、P停止・再開、PSG更新、Esc停止・消音を確認。音の聴感比較は未実施。
- 新送信処理の開始直前に、CPUからデータを与えないHMMCを注入。アセンブラ・C言語の両方、両CPUでCEタイムアウトによるFAULT=1と消音を確認。

385サンプルは全128姿勢と全256位相の個別網羅であり、128×256組の総当たりではありません。初回フレーム直後のスクリーンショットは黒くなる既知の採取条件があるため、同じ要求を2回描画した安定画面で照合しました。最初の診断スクリプトはZ80機に存在しないR800周波数情報を読みタイムアウトしました。診断側を修正し再実行しています。ROMの画素検査・測定結果に影響はありません。

既存V9968実装の垂直同期待ちにはタイムアウトがありません。今回もその動作を維持しています。V9990側のFAULT=3対応をV9968でも検証済みとは扱いません。純粋なCPU送信時間とCE待ち時間の内訳は未測定です。

## 再ビルド・再検証

リポジトリルートで実行します。Python 3、z88dk、画素検査にはPillowが必要です。既存ROMを作り直さず、新版と診断用だけを生成します。

```powershell
python demos/scene3-v9990/build-reference-packets.py --z88dk "<z88dk root>"
python demos/scene3-v9990/build-reference-packets.py --z88dk "<z88dk root>" --c-stream
python demos/scene3-v9990/check-v9968-packets.py
python demos/scene3-v9990/suite.py --kind verify --variants reference-packets reference-packets-c --runtimes "<runtime parent>" --output "<new private verify folder>" --timeout 900
python demos/scene3-v9990/suite.py --kind measure --variants reference-packets --runtimes "<runtime parent>" --output "<new private measure folder>" --timeout 900
```

上の検査ではC言語版も必要なので先に両方をビルドしてください。旧版との直接比較には、旧版の対応するmapも必要です。既存の`build/reference`を保持し、なくなった場合は別の作業用コピーで`build.py --variant reference`を実行し、ROMハッシュが一致したmapを使ってください。記録済みの旧ROMを上書きして揃える運用は避けてください。

追加検査は以下を各CPUで行います。CE故障検査は`--variant reference-packets-c`でも実施します。

```powershell
python demos/scene3-v9990/run-test.py --variant reference-packets --runtime "<runtime>" --script demos/scene3-v9990/edge-fixture.tcl --output "<new private edge folder>" --timeout 900
python demos/scene3-v9990/verify.py "<new private edge folder>" --variant reference-packets --fixture
python demos/scene3-v9990/run-test.py --variant reference-packets --runtime "<runtime>" --script demos/scene3-v9990/integration.tcl --output "<new private input folder>" --display --timeout 900
python demos/scene3-v9990/run-test.py --variant reference-packets --runtime "<runtime>" --script demos/scene3-v9990/fault-v9968-packets.tcl --output "<new private fault folder>"
python demos/scene3-v9990/run-test.py --variant reference-packets --runtime "<runtime>" --script demos/scene3-v9990/capture-v9968-packets.tcl --output "<new private capture folder>" --display
python demos/scene3-v9990/compare-v9968-dumps.py "<old verify session>" "<new verify session>"
```

生ログには個人パスや所有BIOSコピーが含まれるため、出力はリポジトリ外の新規フォルダへ保存してください。起動BATは`-VerifyLaunch -Runtime "<runtime>" -UserRoot "<private folder>"`で自動確認できます。

記録：[概要](results-v9968-packets/summary.json)、[直接画素比較](results-v9968-packets/direct-pixels.json)、[検証](results-v9968-packets/verification.json)、[ハッシュ・環境](results-v9968-packets/provenance.json)。既存配布ZIPと公開対象一覧への追加は行っていません。
