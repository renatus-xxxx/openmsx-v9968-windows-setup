日本語 | [English](README.md)

**2026-09-24 更新:** 以下の固定派生版の仕様・実測は d884c4b 当時の記録です。現在の 14215c7 では、同じ Revision 2 ROM が off=1/on=1、R20SEL=11 を報告します。[新エミュレーターの検証記録](../docs/emulator-update-20260924.ja.md)を参照してください。元の表・ソース参照は当時の根拠として保持しています。

# V9968 PROBE Revision 2

Revision 2は0.7.1に同梱しています。FPGA実機での再試験は未実施です。

ROM SHA-256: `3527684d4cdaf58659ff7a6363d4cdce263e10959686dc93f091d918ea8287d2`

[検証結果の詳細（JSON）](verification.json)

[ビルド手順](../docs/development.ja.md)

## V9968 適合性確認プローブ

- Revision 2 | 2026-09-14
- R21互換設定の修正と、LRMM診断の切り分け
- C / z88dk / 固定openMSX派生版
- 改良したROMのFPGA実機再試験は未実施

## 実機から届いた結果

- 公開0.7.0のプローブ: off=0 / on=0、LRMM試験をスキップ
- 同じ実機では、デモが0x11を選択しScene 6を実行したとの報告
- R20SEL=31は成功値ではなく、旧コードのフォールバック
- HMMVのCE観測とVRAMマーカーは完了。LRMM成功の証拠ではない

## R21の互換設定が試験条件を変えていた

- 旧プローブ: R21=0x3aで識別 → 直後に0x3bへ戻す → LRMM試験
- 動作したデモ: R21=0x3aを維持してLRMMを実行
- 公開FPGAソースではbit0が互換フラグ。拡張コマンド許可はその反転
- 改良版: 拡張設定を維持し、試験直前にEXTID=3を確認

## R20とR21は別の役割

| 設定 | 固定fork | 公開FPGA仕様 |
| --- | --- | --- |
| R21 bit0 | 識別への影響あり | 1=V9958互換 / 0=拡張 |
| R20 bit5 | 拡張コマンドのゲート | フラットインタレース |
| R20 0x11 | HS + EPAL | HS + EPAL |
| R20 0x31 | 上記 + bit5 | 上記 + FIL |

## Revision 2の実行順

- 識別 → SCREEN 5・表示停止・割り込み禁止
- EXTID確認 → 低位VRAMでR20両設定を試験
- 成功値を選択 → 高位VRAM・透明転送・ステップを試験
- HMMVのCE観測 → VRAM4点 → 正常化・INITXT・結果表示

## 低位VRAMでデモと条件をそろえる

- 転送元 (0,0) → 転送先 (16,0)、8×2画素、等倍、透明LRMM 0x38
- 色15で転送元を、色0で転送先をLMMV初期化
- クリップ: X=0..255、Y=0..191。R14=0で読み返す
- 準備データと転送後の16画素すべてを照合。先頭1バイトだけで成功にしない

## R20の選択ルール

| off | on | 選択 / 解釈 |
| --- | --- | --- |
| 1 | 0 または 1 | 0x11を選ぶ。bit5なしを優先 |
| 0 | 1 | 0x31を選ぶ |
| 0 | 0 | NONE。LRMM後続試験を省略 |

## 結果とCE観測を分けて残す

- LRRAW: off/onそれぞれの転送先先頭バイトを16進表示
- LRCE: 各LRMMの開始待ちでCE=1を一度でも読めたか
- LRCE=0でも転送全体の照合が成功することがある
- 固定fork実測: LRRAW off=00 on=ff / LRCE off=0 on=0

## CEの待機と上限

- S#2 bit0: 1=コマンド実行中、0=非実行中
- 発行前: idle()で前コマンドの完了を確認
- 発行後: 最大1024回の開始猶予 → 最大20000回の完了待ち
- 完了待ち超過: ABRT、fault=1、後続試験停止。固定回数は実機保証ではない

## CE行はHMMVの診断

- HMMV 0xc0で256×192画素の領域を塗り潰す
- rise: CE=1になる前に読んだ0の回数。上限20000
- fall: CE=0になる前に読んだ1の回数。上限60000
- CPU、コンパイラー、表示状態、R20に依存。14対15を速度差と解釈しない

## 高位VRAMのLRMMを独立試験にする

- 選んだR20で、同じ8×2画素をY=256で転送
- クリップY=256..1023、読み返しR14=2
- LRHIGH ok=1なら透明転送とステップ試験へ進む
- 低位成功・高位失敗なら、LRMM全体の未対応とせずアドレス条件を調べる

## 透明転送と不透明転送

- Y=258で転送元を色0、転送先を色15に準備
- 0x38: 透明演算なら転送先0xffを保持
- 0x30: 不透明演算なら転送先0x00へ上書き
- timp=ff / imp=00はこの色0条件での観測。全論理演算の保証ではない

## ソース座標の進め方

- Y=260の入力画素を1,2,3,4,5,6,7,8にする
- 等倍・不透明で4画素を転送し、先頭2画素を表示
- d0=1 / d1=2: 先頭を読む前に1画素進める挙動ではない
- d0=2 / d1=3なら先行更新を疑う。他の値は別要因も含めて調査

## VRAMの4点とアドレス計算

| R14 | 下位14bit | 要求アドレス |
| --- | --- | --- |
| 2 | 0 | 0x08000 |
| 4 | 0 | 0x10000 |
| 6 | 0 | 0x18000 |
| 7 | 0 | 0x1c000 |

## 画面復帰と実行条件

- 新規カートリッジ起動専用。実験中はVRAM・レジスタを上書き
- 終了時にABRT、R20/R14/R15/R16/R17を0へ、R21を0x3bへ戻す
- BIOS INITXT (0x006c) → 割り込み許可 → テキスト表示
- ディスク・フラッシュは書かない。実行前の画面やアプリ状態は復元しない

## Revision 2の正常出力例

- PROBE REV=2 / EXTID=3 R21=3a
- R20B5 off=0 on=1 / R20SEL value=31
- LRRAW off=00 on=ff / LRCE off=0 on=0
- LRHIGH ok=1 raw=ff / LRMMOP timp=ff imp=00
- LRMMST d0=1 d1=2 / CE rise=0 fall=15 / CESEEN value=1
- VRAM a1 a2 a3 a4 / REPORT THESE LINES

## 停止・スキップの意味

| 表示 | 意味 |
| --- | --- |
| PROBE ERROR code=1 | コマンド完了待ちの上限超過 |
| PROBE ERROR code=2 | 転送前の準備データが不一致 |
| PROBE ERROR code=3 | 実験直前のEXTIDが3ではない |
| R20SEL NONE | 両R20条件で転送確認が失敗 |
| LRMM TESTS SKIPPED | 選択不能または高位転送失敗 |

## エミュレーターでの確認

| 構成 | CPU | 結果 |
| --- | --- | --- |
| C-BIOS + V9968 fork | Z80 | Revision 2全項目完走 |
| FS-A1GT + V9968 fork | Z80 | 同じ出力・画面復帰 |
| C-BIOS + openMSX 21.0 | Z80 | ID=2 / 実験省略 |
| FS-A1GT + openMSX 21.0 | Z80 | ID=2 / 実験省略 |

## 異常系は別ROMで検証する

- LRMM発行をABRTへ置換 → NONE・スキップを確認
- 実験直前にR21=0x3b → エラー3を確認
- HMMV完了待ち上限を1へ → エラー1を確認
- 0x11選択分岐を人工的に通す → 選択・高位失敗処理を確認

## 実機へ再試験を依頼する手順

- Revision 2 ROMを使い、表示のPROBE REV=2を確認する
- 電源投入から起動し、設定を書き換えず画面全体を撮影する
- 機器・FPGAファームウェア版、MSX機種、CPUモード、ROMハッシュを添える
- NONEやエラーもそのまま送る。期待値に合わせてR20を書き換えない

## Cでのビルドと再現情報

- zcc +msx -subtype=rom -compiler=sccz80 -O2 -create-app probe.c -o PROBE
- 出力は16KiB ROM。z88dkは開発者の再ビルド時だけ必要
- scripts/build-probe.ps1 -Z88dk <toolchain> を使用できる
- ソース・ROM・verification.json・設定ハッシュを同じ改訂にそろえる

## 未確認事項と一次資料

- FPGA再試験、R800、外付け88h/89hポート、待機上限の実機保証は未確認
- 256KiB容量、負のステップ、分数丸め、クリップ境界、パレット読み返しは対象外
- FPGA Register Map: R20 Mode5 / R21 Mode6（本文p.10）
- 固定FPGAソース: vdp_cpu_interface.v / 固定fork: VDP.cc、VDPCmdEngine.cc

## 一次資料

- [Source 1](https://github.com/hra1129/V9968_Cartridge/blob/9c2eb1d1445bbc23a3bdac3916cfa147519452f8/fpga/V9968_Cartridge_TangNano20K/src/v9968/vdp_cpu_interface.v)
- [Source 2](https://github.com/hra1129/V9968_Cartridge/blob/9c2eb1d1445bbc23a3bdac3916cfa147519452f8/fpga/V9968_Cartridge_TangNano20K/src/v9968/manual/v9968_programmers_manual_register_map.pdf)
- [Source 3](https://github.com/buppu3/openMSX/blob/d884c4b/src/video/VDP.cc)
- [Source 4](https://github.com/buppu3/openMSX/blob/d884c4b/src/video/VDPCmdEngine.cc)
