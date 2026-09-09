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

The 16 KiB probe ROM is built from [probe.c](../probe/probe.c). At fresh startup it disables interrupts, writes R#21=3Ah and R#15=1, reads the ID from S#1 via port 99h, restores R#15=0/R#21=3Bh, and enables interrupts. It is not a general saved-state detection API or an interrupt-handler routine. Both tested machine configurations run this ROM as a cartridge with the Z80 active; this does not test R800 execution or throughput.

The V9968 fork should report ID=3, while the standard V9958 configuration reports ID=2. Reading the power-on compatibility ID alone does not tell them apart, which is why the sequence above is needed. See [primary references](sources.md) for the author's sample and manual. C-BIOS requires a cartridge route here; a BASIC BLOAD program is not interchangeable with it.

Rebuilds from changed source or a different toolchain may have another hash. Before releasing such a change, test it and update config/versions.json. The installer and launcher intentionally reject an unexpected probe hash.

## Packaging

Building the distribution ZIP is a separate task from C development. The [maintainer instructions](publishing.md) cover the validation and packaging commands, what they check, and how the ZIP is attached to Releases.
