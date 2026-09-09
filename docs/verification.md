[日本語](verification.ja.md) | English

# Verification — 0.5.0

[Home](../README.md) | [Detailed test results (JSON)](../tests/verification.json)

Checked 2026-09-09 on Windows 10 x64 build 19045, Windows PowerShell 5.1.19041.7725, curl 8.13.0 and z88dk classic/sccz80.

## Checks in this pass

- No fixed z88dk candidate; explicit, Z88DK, ZCCCFG and PATH discovery passed.
- Invalid automatic candidates are skipped; invalid explicit paths stop.
- Missing-tool selection, cancellation and invalid selection used simulated picker input, not manual native-dialog interaction.
- C ROM rebuilt from an independent ZIP extraction in a Japanese/space path; SHA-256 matches config/versions.json.
- Paired links, public allowlist, four root BATs and ZIP contents checked.

## Evidence retained from earlier checks on the same date

These were not rerun after the current z88dk discovery change. Setup/emulator logic and the probe ROM have not changed.

- Both setup/verify/launch routes reported VDP ID=3; standard comparisons reported ID=2.
- FS-A1GT BASIC reached MSX BASIC 4.1 / Disk BASIC 2.01 / Ok.
- Japanese/space paths, a working directory outside the repository and identical duplicate ROM candidates worked.
- BIOS joining restored matching bytes and rejected existing output, missing or altered parts. Input was generated locally from an owned image.
- Missing/wrong BIOS, unmanaged existing output, altered cache, unreachable proxy and changed managed settings/ROMs were rejected. Repeated setup preserved user settings.

Temporary Tcl captured launch screen text and exited. Test Tcl and owned BIOS are not distributed. The C program ran on z80.

![C-BIOS](images/cbios-v9968.png)

![FS-A1GT](images/fsa1gt-v9968.png)

## Unverified conditions and limitations

Windows 11, a clean OS, missing VC runtime, manual Explorer/native picker operation, physical BIOS dumping, the alternative accepted firmware starting with SHA-1 5fa3, and a compiler installation path containing Japanese characters/spaces remain untested. Individual HTTP 404, partial-disconnect, concurrency and disk-full fault injection was not performed.

Physical V9968, R800, all graphics features, games, FPS, sound and peripheral compatibility are unverified. Successful identification does not guarantee all features.
