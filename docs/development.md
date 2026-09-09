[日本語](development.ja.md) | English

# C development

[Home](../README.md)

Only developers rebuilding the probe need z88dk; setup and launch users do not.

The [official Windows installation guide](https://github.com/z88dk/z88dk/wiki/installation#3-binary-installation-on-windows), checked 2026-09-09, permits a chosen destination and advises avoiding spaces where possible.

Run `tools\dev\build-probe.bat` at the root. Discovery order: explicit `-Z88dk`, Z88DK environment variable, root derived from ZCCCFG, zcc.exe on PATH. If no valid candidate exists, a folder picker opens. Select the root containing bin, lib and include. Invalid explicit paths or selections stop with an explanation. Cancellation creates no build directory.

```bat
tools\dev\build-probe.bat -Z88dk "D:\tools\z88dk"
tools\dev\build-probe.bat -SelectZ88dk
```

Environment changes are process-local. Builds use a fresh directory under build/probe and update probe/PROBE.rom only on success. Paths are quoted, but the compiler toolchain may impose restrictions; an ASCII installation path without spaces is recommended.

```text
zcc +msx -subtype=rom -compiler=sccz80 -O2 -create-app probe.c -o PROBE
```

The 16 KiB cartridge test is built from [probe.c](../probe/probe.c). At fresh startup it disables interrupts, writes R#21=3Ah and R#15=1, reads the ID from S#1 via port 99h, restores R#15=0/R#21=3Bh, and enables interrupts. It is not a general saved-state detection API or an interrupt-handler routine. Both tested machine configurations run this cartridge with the Z80 active; this does not test R800 execution or throughput.

The V9968 fork should report ID=3, while the standard V9958 configuration reports ID=2. The initial compatibility ID alone is insufficient. See [primary references](sources.md) for the author's sample and manual. C-BIOS requires a cartridge route here; a BASIC BLOAD program is not interchangeable with it.

Rebuilds from changed source or a different toolchain may have another hash. Before releasing such a change, test it and update config/versions.json. The installer and launcher intentionally reject an unexpected probe hash.

## Development and packaging commands

These are not required for normal setup or launch. Run them from the repository root or extracted ZIP folder.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\validate-public.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\package.ps1
```

- `validate-public.ps1`: checks the public allowlist for duplicates, missing files and prohibited paths; paired documents and local links; the four root BATs and helper references; and the probe ROM hash. Supply `-ZipPath` to check an existing ZIP as well.
- `package.ps1`: runs those checks, creates a Releases asset ZIP containing only allowlisted files, compares its entries with the source files, and prints SHA-256. It refuses to overwrite an existing output ZIP.

See [maintainer instructions](publishing.md) for output paths, check coverage and attaching the ZIP to Releases.
