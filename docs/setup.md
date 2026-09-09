[日本語](setup.ja.md) | English

# Setup and layout

[Home](../README.md)

## Download

Download the distribution ZIP from **Assets** on [GitHub Releases](https://github.com/renatus-xxxx/openmsx-v9968-windows-setup/releases) and extract it completely into a new writable folder. Run the BATs below from that folder. Do not select the **Source code** archives.

## C-BIOS

Run `setup-cbios-v9968.bat`. It downloads the official openMSX 21.0 Windows x64 ZIP and the V9968 fork **d884c4b**, then checks archive sizes/SHA-256 and executable SHA-256 before execution. C-BIOS **0.29** comes from the official ZIP. Network downloads total about 18 MB; allow around 200 MB per installed environment, plus any retained failed attempts.

The generated C-BIOS_MSX2+_JP derivative uses an internal V9968 and a Japanese 60 Hz configuration. It runs cartridge images; it supplies no BASIC or disk environment.

## FS-A1GT

Drag a folder with your compatible ROMs onto `setup-fsa1gt-v9968.bat`. Double-clicking without an argument opens a folder picker. From Command Prompt:

```bat
setup-fsa1gt-v9968.bat "D:\MSX BIOS\FS-A1GT"
```

Required: `fs-a1gt_firmware.rom` (4,194,304 bytes) and `fs-a1gt_kanjifont.rom` (262,144 bytes). Names may differ: identification uses file sizes and the SHA-1 values in [versions.json](../config/versions.json). Files in subdirectories are scanned without following reparse-point directories. Identical duplicates are accepted once; different supported firmware versions together cause a stop. Split files require the [join step](bios-dump.md).

The official FS-A1GT machine keeps its CPU, 512 KiB RAM, disk and other devices, while its internal VDP block is replaced by V9968 with ports 98h–9Ch and timing=0. This is an experimental machine configuration, not a stock FS-A1GT. The original VDP is V9958. This package does not set up an external V9968 cartridge. The fork ignores the XML vram size; do not interpret vram=128 as the physical V9968 capacity.

## Directory map

```text
repository root: four setup / launch BAT files
tools/verify/    verification and standard comparison BATs
tools/bios/      BIOS joining and BASIC launcher
tools/dev/       C build BAT
scripts/         implementation and runtime templates
probe/           C source and compiled test application
config/          pinned versions and reference machine XML
licenses/        unchanged third-party notices
docs/           paired English/Japanese guides and images
tests/          packaging/link validation
runtime/cbios/   generated C-BIOS installation (private)
runtime/fsa1gt/  generated FS-A1GT installation (private; contains BIOS)
cache/           verified downloaded ZIPs (private)
private/         locally joined BIOS (private)
build/          developer build output (excluded from Git)
```

Launchers always target these standard runtime locations. Each installation separates user-v9968, user-standard and user-selftest. Its emulator files, ROM copies, config.json, installation.json and logs remain inside that installation. Root BAT files call the nested runtime launcher automatically.

Setup uses a fresh staging directory and commits it only after the C test reports ID=3. Interrupted attempts and partial downloads remain for diagnosis. Re-running validates managed files, keeps user settings and reuses valid cache; it stops if a managed file changed. Re-running does not automatically rerun the boot test: use the verification BAT in tools/verify.

Hash provenance is in versions.json. The official ZIP matches the GitHub release API digest; the fork hashes are local measurements. No hash mismatch is ignored, and no automatic latest-version upgrade occurs.

BAT files select standard Windows PowerShell modules. Execution-policy bypass and environment settings are process-local; no global PATH or registry setting is changed. Setup does not install dependencies with administrator privileges. Some detailed legacy console messages are Japanese; this guide and [troubleshooting](troubleshooting.md) explain the corresponding conditions in English.

## Confirmation screen and limitations

Expect **VDP ID=3 / V9968 IDENTIFIED** with V9968 and **ID=2** in the standard comparison. Identification does not guarantee all graphics features, games, FPS, sound, peripherals or R800 operation. The probe cartridge runs on the Z80.

![C-BIOS](images/cbios-v9968.png)

![FS-A1GT](images/fsa1gt-v9968.png)
