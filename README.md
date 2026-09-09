[日本語](README.ja.md) | English

# openmsx-v9968-windows-setup

Unofficial Windows setup helpers for the V9968-enabled openMSX fork. Version **0.5.0**. This is an independent helper project, not the official openMSX or V9968 project.

Choose **C-BIOS** to try cartridge-based C programs without a physical machine BIOS, or **FS-A1GT** to use ROMs dumped from your own machine. Both options download tested emulator versions, check hashes, and run a V9968 identification test.

## Quick start

1. Extract the **whole ZIP** to a new writable folder. For GitHub **Code → Download ZIP**, open the automatically created repository folder. For the release ZIP, extract to a new folder; the BAT files are directly inside it. Do not run BAT files inside a ZIP viewer.
2. Run `setup-cbios-v9968.bat`, or drag your FS-A1GT BIOS folder onto `setup-fsa1gt-v9968.bat`.
3. Run `launch-cbios-v9968.bat` or `launch-fsa1gt-v9968.bat` in **the same top-level folder**.

Expected screen: **VDP ID=3 / V9968 IDENTIFIED**.

| Mode | Setup | Launch |
|---|---|---|
| C-BIOS | `setup-cbios-v9968.bat` | `launch-cbios-v9968.bat` |
| FS-A1GT | `setup-fsa1gt-v9968.bat` | `launch-fsa1gt-v9968.bat` |

## Additional tools

Paths below are relative to the repository root.

| Purpose | File |
|---|---|
| Verify C-BIOS | `tools\verify\verify-cbios-v9968.bat` |
| Verify FS-A1GT | `tools\verify\verify-fsa1gt-v9968.bat` |
| Compare standard C-BIOS | `tools\verify\launch-cbios-standard.bat` |
| Compare standard FS-A1GT | `tools\verify\launch-fsa1gt-standard.bat` |
| Join BIOS dump | `tools\bios\join-fsa1gt-dump.bat` |
| Start FS-A1GT BASIC | `tools\bios\launch-fsa1gt-basic.bat` |
| Rebuild C ROM | `tools\dev\build-probe.bat` |

Requires Windows 10/11 x64, built-in Windows PowerShell 5.1 and curl.exe, network access, and a working graphics driver. Setup needs no administrator privileges, 7-Zip, Python, Git or z88dk.

C-BIOS does **not** provide BASIC, Disk BASIC or normal disk boot in this configuration. The FS-A1GT option requires a 4 MiB firmware image and 256 KiB Kanji font ROM. Neither is supplied. The bundled `probe/PROBE.rom` is our test application, not a BIOS.

## Documentation

- [Setup and layout](docs/setup.md)
- [Dump and join your FS-A1GT ROMs](docs/bios-dump.md)
- [C development](docs/development.md)
- [Troubleshooting and removal](docs/troubleshooting.md)
- [Verification and limitations](docs/verification.md)
- [Sources and third-party licenses](docs/sources.md)

Do not publish generated `runtime/`, `cache/` or `private/` directories. FS-A1GT runtime directories contain your BIOS.

- [Changelog](docs/CHANGELOG.md)
