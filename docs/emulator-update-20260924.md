[日本語](emulator-update-20260924.ja.md) | English

# V9968 openMSX update — 2026-09-24

[Home](../README.md) | [Update and rollback](troubleshooting.md#update-and-rollback)

The unchanged probe and demo ROMs work with the newly pinned fork on both C-BIOS/Z80 and FS-A1GT/R800. The automatic R20 selection now chooses **0x11**, instead of 0x31 on the former fork. No ROM rebuild or machine XML change was required. This is a local source-tree update; the project version and published release ZIPs have not changed.

## Exact downloads

| Item | Previous | New |
|---|---|---|
| V9968 fork commit | d884c4b29d7e736d6e488aca5f28e124a410c19f | 14215c7395649c3981fcc56733d0720acc11c1fd |
| Publisher date | 2026-01-18 | 2026-09-24 |
| ZIP bytes | 4,746,404 | 4,788,114 |
| ZIP SHA-256 | `6c44f0ae3c58c6fbe6f7f450be44b89997062f795f2d333db721d4fb38130f95` | `489281c373089ccd71a06cc0fb5e7772b6473e38c6417ad567c306b2cf65a548` |
| EXE SHA-256 | `b5de3932c0e486002c2ca1fb0d858ad27fc10e97bc5a6b1b277f988f7b7454b9` | `d6d451a3311528b61c928fa11420ce65979dbee7c2543ca52368bac682f53e88` |

[New fixed ZIP](https://buppu3.github.io/openMSX/derived/openmsx-21.0-v9968-14215c7-x64-VC-Release.zip) / [source at the fixed commit](https://github.com/buppu3/openMSX/tree/14215c7395649c3981fcc56733d0720acc11c1fd).

The new archive contains only `openmsx.exe` (16,737,280 bytes). Its version string is **openMSX 21.0-unknown**: the filename, publisher commit and executable hash are required to identify this build. The version string alone is insufficient. The fork checksums above were calculated locally from HTTPS downloads; no publisher checksum was found.

Official openMSX **21.0** remains the source of shared data, libraries and C-BIOS **0.29**. Its ZIP and EXE hashes are unchanged in [versions.json](../config/versions.json). The fork download does not add DLLs. No license-file changes were found in the source comparison; existing third-party notices remain. No additional runtime installer was needed on the tested host. A clean Windows installation was not tested.

## Relevant upstream changes

The [publisher page](https://buppu3.github.io/) and [fixed source comparison](https://github.com/buppu3/openMSX/compare/d884c4b29d7e736d6e488aca5f28e124a410c19f...14215c7395649c3981fcc56733d0720acc11c1fd) were checked on 2026-09-24. The range contains 65 commits, including upstream merges; this is not a claim of 65 V9968 changes.

- September 20: new register definitions, palette reset correction and a fix to the rightmost part of a 256-dot screen (`bf1f46b`).
- September 21: LFMC R44 handling (`74e0067`) and SP3/VRAM planar behavior (`194a769`).
- September 22–24: V58 handling of EVR/FID, expanded masks and display pages (`1d0ac55`, `c620b69`, `f4c5a45`).
- September 24: Sprite Mode 2 palette-set support with EPAL (`14215c7`). The bitmap demo does not exercise this sprite feature.

`<version>V9968</version>` now selects the new register map. The publisher also documents `V9968_OLD` for the former map. The existing machine XML keeps `V9968` and `timing=0`; it does not force old behavior. In the new implementation, `VDP.hh` functions `isECOM()`, `isEVR()` and `isFID()` return **enabled when R21 bit 0 (V58) is 0, disabled when it is 1**. The R20 bit 5 command gate and bit 6 EVR gate apply to the old map. The demo leaves R20 bit 6 clear, so EVR changes from disabled on the old fork to enabled with V58=0 on the new one. The independent pixel-oracle tests passed with this state change; this does not establish compatibility for every display mode or address. With the demo's R21=0x3a, LRMM succeeds under R20=0x11. The unchanged ROM's actual-transfer probe selects that value.

The source still distinguishes V9968 command timing (`timing=0`) from the compatibility timing option. Successful emulation and CE polling do not establish cycle accuracy or FPGA performance. The existing register probes and command-completion waits were retained.

## Validation

Host: Windows 10 Pro 22H2, build 19045.7725, x64; Windows PowerShell 5.1. Each new environment was installed outside the repository. Old runtimes, caches, settings and owned BIOS files were retained. The new archive was downloaded separately and hash-verified, then reused by setup's cache validation. Existing ROMs and their matching maps/data were used without rebuilding.

| Check | C-BIOS / Z80 | FS-A1GT / R800 |
|---|---|---|
| Fresh setup and ID=3 | PASS | PASS |
| Probe Revision 2, LRMM and high-VRAM probe | PASS | PASS |
| All six scenes, transitions, header checks, controls and Escape | PASS | PASS |
| Water regression and 130 work/cache pixel samples | PASS | PASS |
| Glow raster: 128 poses, alternating destination pages | PASS on isolated retry | PASS |
| Scene 3 V9968 packets: 385 oracle samples | PASS | PASS |
| Scene 3 V9990/GFX9000: 385 oracle samples | PASS | PASS |
| V9990 controls, RGB5 palette and PSG activity | PASS | PASS |
| V9968 comparison CE fault injection | PASS | PASS |
| Old emulator full-scene regression (R20=0x31) | PASS | PASS |

The Z80 glow test first hit its 180-second host watchdog during concurrent testing, after 127 captures. An isolated rerun passed all 128 with the **same script, ROM and timeout**; the initial failure remains in the record. This was not resolved by relaxing pixel expectations. Test staging also initially lacked an untracked asset payload and inherited an unsuitable PowerShell module path; both harness issues were corrected before the successful runs. The asset payload was recovered from the published ROM, not regenerated.

The general demo test now accepts an explicit R20 expectation and a host watchdog duration. The new default is 0x11; old-fork runs specify 0x31. No test accepts either value indiscriminately. The default host watchdog is 180 seconds rather than 60; this changes only the harness deadline, not emulated command timing or pixel assertions.

New probe output includes `R20B5 off=1 on=1`, `R20SEL value=11`, `LRHIGH ok=1 raw=ff`, and `CESEEN value=1`. Historical probe tables retain their original emulator/ROM context. The same applies to `probe/verification.json`, `demos/v9968-tech-demo/verification.json` and the comparison demo's `results*/provenance.json`. Historical hashes and R20 results are not rewritten to match the current manifest.

Pixel coverage is 128 poses and 256 phases **separately**, plus the fixture sample, not all 128×256 combinations. Whole-scene old/new screenshot identity was not asserted. Input and PSG state were checked automatically; subjective audio quality was not assessed. No FPGA, external 0x88 cartridge, old save-state compatibility or exhaustive LFMC/SP3/sprite/V58 testing was performed.

## Performance

Each cell is the mean of three independent runs. All three repetitions matched within each tested condition. This demonstrates deterministic reproduction, not an estimate of hardware variance or confidence intervals. The previous values are reused from the preserved [measurement record](https://github.com/renatus-xxxx/openmsx-v9968-windows-setup/blob/df922d62415cb9b0eb9da74c6df30f9640cceb07/demos/scene3-v9990/results-v9968-packets/measurements.json), with matching ROM hashes. The new values are fresh measurements. Five emulated seconds of warmup precede approximately 15 seconds of animation or a fixed 256-frame sequence. Measurements use emulated time, `cmdtiming real`, no frame skipping, normal ROM synchronization and no recording. Sound output is null; the ROM's music processing remains active.

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


The V9968 difference is within about ±0.11%; V9990 values are unchanged. These results do not demonstrate a meaningful general speedup or slowdown. They describe these ROMs and this emulator configuration, not physical VDP performance. Drawing and synchronization times, repeats, ROM hashes and machine XML hashes are in [Detailed test results (JSON)](../tests/emulator-update-20260924.json).

## Reproduce

Use a complete developer checkout, existing hash-matched comparison ROMs/maps and separate new runtimes. The comparison ROMs are not part of the release ZIP. Run from the repository root, replacing paths below with your isolated runtime/output locations:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\test-probe.ps1 -Runtime D:\V9968-test\runtime\cbios -ExpectedR20 11
powershell.exe -NoProfile -ExecutionPolicy Bypass -File demos\v9968-tech-demo\test.ps1 -Runtime D:\V9968-test\runtime\cbios -ExpectedR20 11 -TimeoutSeconds 240
python demos/scene3-v9990/suite.py --kind verify --variants reference-packets c --runtimes D:\V9968-test\runtime --output D:\V9968-test\pixels --timeout 900
python demos/scene3-v9990/suite.py --kind measure --variants reference-packets c --runtimes D:\V9968-test\runtime --output D:\V9968-test\measure --timeout 900
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\validate-public.ps1
```

Repeat the first two commands with `fsa1gt`; the suites run both machines. For a retained d884c4b runtime use `-ExpectedR20 31`. Run rendering regressions, including water and glow, individually to avoid host watchdog timeouts. The separate `test-water.ps1` watchdog remains 60 seconds. Existing water/glow scripts remain in the demo directory. No release ZIP was created or modified for this update. The current allowlist has 150 entries, while the published 0.7.3 ZIP has 147; `-ZipPath` validation against that old ZIP therefore fails. Before releasing this change, select a release version separately and create the corresponding package instead of replacing the published 0.7.3 asset under the same name. Do not copy raw runtime or capture directories into a public package; they can contain owned BIOS files.
