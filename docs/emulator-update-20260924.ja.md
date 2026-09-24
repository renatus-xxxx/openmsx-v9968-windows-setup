日本語 | [English](emulator-update-20260924.md)

# V9968 対応 openMSX の更新 — 2026-09-24

[トップ](../README.ja.md) | [更新と復旧](troubleshooting.ja.md#更新と復旧)

既存のプローブとデモの ROM を変更せず、新しく固定した派生版で C-BIOS/Z80・FS-A1GT/R800 の動作を確認しました。R20 の自動選択は、以前の 0x31 から **0x11** になります。ROM の再ビルドや機種 XML の変更は不要でした。この2026-09-24の検証結果を基に、更新を0.7.4へ収録しました。以下の測定日時・値は当時の記録です。

## 配布物の識別

| 項目 | 以前 | 今回 |
|---|---|---|
| V9968 派生版コミット | d884c4b29d7e736d6e488aca5f28e124a410c19f | 14215c7395649c3981fcc56733d0720acc11c1fd |
| 配布元の日付 | 2026-01-18 | 2026-09-24 |
| ZIP バイト数 | 4,746,404 | 4,788,114 |
| ZIP SHA-256 | `6c44f0ae3c58c6fbe6f7f450be44b89997062f795f2d333db721d4fb38130f95` | `489281c373089ccd71a06cc0fb5e7772b6473e38c6417ad567c306b2cf65a548` |
| EXE SHA-256 | `b5de3932c0e486002c2ca1fb0d858ad27fc10e97bc5a6b1b277f988f7b7454b9` | `d6d451a3311528b61c928fa11420ce65979dbee7c2543ca52368bac682f53e88` |

[新しい固定 ZIP](https://buppu3.github.io/openMSX/derived/openmsx-21.0-v9968-14215c7-x64-VC-Release.zip) / [固定コミットのソース](https://github.com/buppu3/openMSX/tree/14215c7395649c3981fcc56733d0720acc11c1fd)。

新アーカイブは `openmsx.exe`（16,737,280 バイト）のみを含みます。実行時のバージョン表記は **openMSX 21.0-unknown** です。これだけでは識別できないため、配布ファイル名、配布元コミット、実行ファイルのハッシュを併用します。派生版の公式チェックサムは見つからず、上記は HTTPS で取得したファイルから計算した値です。

共有データ・ライブラリ・C-BIOS **0.29** の供給元は、引き続き通常版 openMSX **21.0** です。その ZIP・EXE ハッシュは [versions.json](../config/versions.json) で変更していません。派生版 ZIP に追加 DLL はありません。ソース比較でライセンスファイルの変更は確認されず、既存の第三者表示を維持します。検証ホストで追加のランタイム導入は不要でした。クリーン OS は未検証です。

## 関係する上流の変更

2026-09-24 に[配布元](https://buppu3.github.io/)と[固定した新旧ソースの比較](https://github.com/buppu3/openMSX/compare/d884c4b29d7e736d6e488aca5f28e124a410c19f...14215c7395649c3981fcc56733d0720acc11c1fd)を確認しました。通常版からのマージを含む65コミットであり、V9968 固有の変更が65件という意味ではありません。

- 9月20日：新レジスター定義、パレット初期化、256ドット画面右端の修正（`bf1f46b`）。
- 9月21日：LFMC の R44 処理（`74e0067`）、SP3 と VRAM プレーナー動作（`194a769`）。
- 9月22～24日：V58 による EVR/FID、拡張マスク、表示ページの処理修正（`1d0ac55`、`c620b69`、`f4c5a45`）。
- 9月24日：EPAL 使用時の Sprite Mode 2 パレットセット対応（`14215c7`）。今回のビットマップデモは、このスプライト機能を使いません。

`<version>V9968</version>` は新レジスターマップを選択します。配布元には旧マップ用の `V9968_OLD` も記載されています。既存の機種 XML は `V9968` と `timing=0` を維持し、旧動作には固定しません。新実装の `VDP.hh` にある `isECOM()`・`isEVR()`・`isFID()` は、R21 bit0（V58）が **0 のとき有効、1 のとき無効**を返します。拡張コマンドの R20 bit5 と EVR の R20 bit6 による判定は旧マップ用になりました。デモは R20 bit6 を立てないため、EVR は旧版では無効、新版の V58=0 では有効となります。今回の独立期待画像との画素検査はこの状態変化を含めて成功しましたが、全画面モード・全アドレスの互換性を保証するものではありません。デモの R21=0x3a では R20=0x11 で LRMM が動くため、既存 ROM の実転送による判定がこの値を選びます。

ソースには引き続き V9968 コマンドタイミング（`timing=0`）と互換タイミングの区別があります。エミュレーターでの成功や CE の監視は、サイクル精度や FPGA の速度を保証しません。既存のレジスター判定とコマンド完了待ちは維持しました。

## 検証

ホストは Windows 10 Pro 22H2、ビルド 19045.7725、x64、Windows PowerShell 5.1 です。新環境はリポジトリ外に構築し、旧 runtime・キャッシュ・設定・所有 BIOS は保持しました。新 ZIP を別途ダウンロードしてハッシュ確認後、セットアップのキャッシュ検証を経て使用しています。既存 ROM と対応するマップ・データを使い、再ビルドしていません。

| 検査 | C-BIOS / Z80 | FS-A1GT / R800 |
|---|---|---|
| 新規セットアップ・ID=3 | PASS | PASS |
| プローブ Revision 2・LRMM・上位 VRAM | PASS | PASS |
| 全6シーン・遷移・ヘッダー・操作・Escape | PASS | PASS |
| 水面回帰・作業領域とキャッシュ130サンプルの画素検査 | PASS | PASS |
| 残光ラスタ128姿勢・転送先ページ交互 | 単独再試行で PASS | PASS |
| Scene 3 V9968 事前生成版・独立期待画像385サンプル | PASS | PASS |
| Scene 3 V9990/GFX9000・独立期待画像385サンプル | PASS | PASS |
| V9990 操作・RGB5 パレット・PSG 動作 | PASS | PASS |
| V9968 比較版 CE 障害注入 | PASS | PASS |
| 旧エミュレーター全シーン回帰（R20=0x31） | PASS | PASS |

Z80 の残光検査は並行実行中、127枚の取得後にホスト側180秒の制限に達しました。**同じスクリプト・ROM・制限時間**で単独再実行すると128枚すべて成功しました。初回の失敗も記録に残し、画素の期待値は緩和していません。また、最初の検証用コピーには未追跡の素材データが不足し、Windows PowerShell のモジュールパス継承にも問題がありました。成功した検証の前に環境を修正し、素材は再生成せず公開 ROM の内容から復元しました。

全シーン検査には R20 の期待値とホスト側制限時間の引数を追加しました。新しい既定値は0x11、旧派生版には0x31を指定します。どちらでも通る検査にはしていません。ホスト側制限の既定値を60秒から180秒に延長しましたが、エミュレーター内のコマンド時間や画素条件は変更していません。

今回のプローブでは `R20B5 off=1 on=1`、`R20SEL value=11`、`LRHIGH ok=1 raw=ff`、`CESEEN value=1` を確認しました。過去のプローブ表は当時の ROM・エミュレーターの記録として保持しています。`probe/verification.json`、`demos/v9968-tech-demo/verification.json`、比較デモの `results*/provenance.json` も同様に当時の記録です。現在のマニフェストに合わせて過去のハッシュ・R20結果を書き換えていません。

画素検査は128姿勢と256位相を**個別に網羅**し、追加の固定サンプルを含めたものです。128×256組の総当たりではありません。全シーンの新旧スクリーンショット完全一致は検査していません。入力・PSG は自動検査で確認し、聴感上の品質は未確認です。FPGA 実機、外付け0x88構成、旧セーブステート互換性、LFMC/SP3/スプライト/V58の全組み合わせも未検証です。

## 性能

各値は独立起動3回の平均です。今回の各条件では3回の値が一致しました。これは決定論的な再現性を示し、実機性能のばらつきや信頼区間の推定ではありません。旧値は保持済みの[測定記録](https://github.com/renatus-xxxx/openmsx-v9968-windows-setup/blob/df922d62415cb9b0eb9da74c6df30f9640cceb07/demos/scene3-v9990/results-v9968-packets/measurements.json)を ROM ハッシュ一致確認のうえ再利用し、新値は今回測定しました。エミュレーター内時間で5秒ウォームアップ後、約15秒の通常アニメーション、または固定256フレーム列を処理します。`cmdtiming real`、フレームスキップなし、ROM の通常同期、録画なしの条件です。音声出力先は null ですが、ROM の音楽処理は動かしています。

| VDP | CPU | Mode | d884c4b FPS | 14215c7 FPS | Change |
|---|---|---|---:|---:|---:|
| V9968 | Z80 | animated | 16.5610 | 16.5496 | -0.069% |
| V9968 | Z80 | sequence | 16.3379 | 16.3553 | +0.107% |
| V9968 | R800 | animated | 16.3120 | 16.2997 | -0.075% |
| V9968 | R800 | sequence | 16.0641 | 16.0473 | -0.105% |
| V9990 | Z80 | animated | 15.1299 | 15.1299 | +0.000% |
| V9990 | Z80 | sequence | 14.7653 | 14.7653 | +0.000% |
| V9990 | R800 | animated | 20.7523 | 20.7523 | +0.000% |
| V9990 | R800 | sequence | 20.4553 | 20.4553 | +0.000% |


V9968 の差は約±0.11%以内で、V9990 は同じ値でした。一般的な高速化・低速化を示す結果とは扱いません。今回の ROM とエミュレーター構成の結果であり、実機 VDP の性能ではありません。描画・同期待ち時間、反復測定、ROM と機種 XML のハッシュは[検証結果の詳細（JSON）](../tests/emulator-update-20260924.json)に記載しています。

## 再確認方法

完全な開発用ソース一式、ハッシュが一致する既存の比較 ROM・マップ、新しい独立 runtime を使います。比較 ROM は配布 ZIP に含まれません。リポジトリ直下で、以下の保存先を自分の独立検証環境に置き換えて実行してください。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\test-probe.ps1 -Runtime D:\V9968-test\runtime\cbios -ExpectedR20 11
powershell.exe -NoProfile -ExecutionPolicy Bypass -File demos\v9968-tech-demo\test.ps1 -Runtime D:\V9968-test\runtime\cbios -ExpectedR20 11 -TimeoutSeconds 240
python demos/scene3-v9990/suite.py --kind verify --variants reference-packets c --runtimes D:\V9968-test\runtime --output D:\V9968-test\pixels --timeout 900
python demos/scene3-v9990/suite.py --kind measure --variants reference-packets c --runtimes D:\V9968-test\runtime --output D:\V9968-test\measure --timeout 900
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\validate-public.ps1
```

最初の2コマンドは `fsa1gt` でも実行します。比較スイートは両機種を検査します。旧 d884c4b の runtime には `-ExpectedR20 31` を指定してください。ホスト側の時間切れを避けるため、水面・残光を含む描画回帰検査は単独実行を推奨します。`test-water.ps1` の制限は引き続き60秒です。既存の水面・残光検査はデモのディレクトリ内にあります。0.7.4のZIPは150件を収録します。147件だった0.7.3のZIPは保持しており、現在の一覧との `-ZipPath` 照合では不一致になります。検査には対応するバージョンのソースとZIPを使用してください。runtime や生のキャプチャ用フォルダには所有 BIOS が含まれるため、そのまま公開物へ入れないでください。
