[日本語](README.ja.md) | English

# openmsx-v9968-windows-setup

Unofficial Windows setup helpers for the V9968-enabled openMSX fork. Version **0.5.0**. This is an independent helper project, not the official openMSX or V9968 project.

Choose **C-BIOS** to try cartridge-based C programs without a physical machine BIOS, or **FS-A1GT** to use ROMs dumped from your own machine. Both options download tested emulator versions, check hashes, and run a V9968 identification test.

## Quick start

1. Download `openmsx-v9968-windows-setup-0.5.0.zip` from **Assets** on [GitHub Releases](https://github.com/renatus-xxxx/openmsx-v9968-windows-setup/releases). Extract the **whole ZIP** into a new writable folder. Do not run BAT files inside a ZIP viewer.
2. Run `setup-cbios-v9968.bat`, or drag your FS-A1GT BIOS folder onto `setup-fsa1gt-v9968.bat`.
3. Run `launch-cbios-v9968.bat` or `launch-fsa1gt-v9968.bat` in **the same top-level folder**.

Expected screen: **VDP ID=3 / V9968 IDENTIFIED**.

| Mode | Setup | Launch |
|---|---|---|
| C-BIOS | `setup-cbios-v9968.bat` | `launch-cbios-v9968.bat` |
| FS-A1GT | `setup-fsa1gt-v9968.bat` | `launch-fsa1gt-v9968.bat` |

[0.5.0 ZIP](https://github.com/renatus-xxxx/openmsx-v9968-windows-setup/releases/download/v0.5.0/openmsx-v9968-windows-setup-0.5.0.zip). **Source code (zip)** / **Source code (tar.gz)** are not the distribution ZIP. The root has two `setup-*` BATs to create environments and two `launch-*` BATs to start them.

## Additional tools

Paths below are relative to the extracted ZIP folder.

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
- [Sources and third-party licenses](docs/sources.md)

Do not publish generated `runtime/`, `cache/` or `private/` directories. FS-A1GT runtime directories contain your BIOS.

- [Changelog](docs/CHANGELOG.md)

## Development and packaging commands

These are not required for normal setup or launch. Run them from the repository root or extracted ZIP folder.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\validate-public.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\package.ps1
```

- `validate-public.ps1`: checks the public allowlist for duplicates, missing files and prohibited paths; paired documents and local links; the four root BATs and helper references; and the probe ROM hash. Supply `-ZipPath` to check an existing ZIP as well.
- `package.ps1`: runs those checks, creates a Releases asset ZIP containing only allowlisted files, compares its entries with the source files, and prints SHA-256. It refuses to overwrite an existing output ZIP.

See [maintainer instructions](docs/publishing.md) for output paths, check coverage and attaching the ZIP to Releases.
