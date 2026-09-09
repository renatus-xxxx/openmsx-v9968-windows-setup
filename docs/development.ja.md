日本語 | [English](development.md)

# C 開発

[トップ](../README.ja.md)

z88dk は再ビルドする開発者だけに必要です。通常のセットアップ・起動には不要です。

[公式 Windows インストール手順](https://github.com/z88dk/z88dk/wiki/installation#3-binary-installation-on-windows)（2026-09-09 確認）は任意の展開先を使用し、可能なら空白を避けるよう案内しています。

ルートで `tools\dev\build-probe.bat` を実行します。検出順は、引数 `-Z88dk`、環境変数 Z88DK、ZCCCFG から求めたルート、PATH 上の zcc.exe です。有効な候補がなければフォルダ選択を表示します。選ぶのは bin・lib・include を含むルートです。明示指定・選択が不正なら理由を表示して停止します。キャンセル時はビルド用フォルダを作成しません。

```bat
tools\dev\build-probe.bat -Z88dk "D:\tools\z88dk"
tools\dev\build-probe.bat -SelectZ88dk
```

環境変数は子プロセス内だけで変更します。ビルドは build/probe 内の新規フォルダで行い、成功時だけ probe/PROBE.rom を更新します。パスは引用符付きで扱いますが、ツールチェーン側の制約もあるため、空白のない英数字の配置先を推奨します。

```text
zcc +msx -subtype=rom -compiler=sccz80 -O2 -create-app probe.c -o PROBE
```

16 KiB の確認 ROM は [probe.c](../probe/probe.c) から生成します。起動直後に割り込みを止め、R#21=3Ah・R#15=1 を設定し、99h から S#1 の ID を読み、R#15=0・R#21=3Bh と割り込みを戻します。任意の状態を保存する汎用識別 API や、割り込みハンドラー用の関数ではありません。検証した両機種ではこの ROM をカートリッジとして Z80 で実行しており、R800 の動作・性能は確認していません。

派生版は ID=3、通常の V9958 構成は ID=2 が期待値です。電源投入時の互換 ID を読むだけでは区別できないため、上記の手順が必要です。[一次資料](sources.ja.md)に作者のサンプルとマニュアルを掲載しています。この C-BIOS 構成ではカートリッジを使い、BASIC の BLOAD 用プログラムとは交換できません。

ソースやツールチェーンを変更するとハッシュが変わる場合があります。配布更新時に動作確認して config/versions.json を更新してください。想定外の確認 ROM は、セットアップとランチャーで拒否します。

## 配布物の作成

配布 ZIP の作成は C 開発とは別の作業です。検査・パッケージのコマンド、検査範囲、Releases への添付方法は[公開担当者向け手順](publishing.ja.md)にまとめています。
