[日本語](V9968-PACKETS.ja.md) | [Comparison demo](README.md)

# Pre-generated V9968 water commands

Python now prepares water-body and edge-fill commands. Animated FPS improves by 4.71% on Z80 and 2.39% on R800. ROM size increases from 1 MiB to 2 MiB. Existing reference, V9990, and main-demo ROMs and historical results are preserved.

## Launch and implementation

- Z80: [launch-scene3-v9968-packets-cbios.bat](../../tools/benchmark/launch-scene3-v9968-packets-cbios.bat)
- R800: [launch-scene3-v9968-packets-fsa1gt.bat](../../tools/benchmark/launch-scene3-v9968-packets-fsa1gt.bat)
- ROM: `SCENE3-V9968-PACKETS.rom`. Uses the installed runtime with separate comparison user settings.
- The existing launcher options `-Runtime`, `-UserRoot`, and `-VerifyLaunch` remain available. W toggles water, P holds the pose, and Esc stops and mutes.

`generate-v9968-packets.py` converts the shared ROM's water bands into 15-byte R32..R46 packets. The body uses HMMM (0xD0); a shifted band's edge uses two one-pixel LMMM (0x90) commands, exactly as before. This repeats edge pixels rather than interpolating them. Coordinates, dimensions, opcode, and source page 2 are fixed at generation time.

Each record contains a 16-bit count and packets, padded to 4,096 bytes. At runtime the sender waits for CE completion, sets R17 to 32, sends seven bytes with OTIR, substitutes the destination page byte, and sends the remaining seven bytes with OTIR. Only offset 7 changes. Command count, order, and transfer area are unchanged; VDP work is not omitted.

`v9968-water-packets.inc` includes an adjacent, build-selectable C-language equivalent. `--c-stream` creates a separate diagnostic `SCENE3-V9968-PACKETS-C.rom`. This switch covers the new water sender, not the existing interrupt and rectangle assembly code.

The shared `v9968.c` stays unchanged. The dedicated builder replaces only its water section in the private build directory, checks the expected bank layout, and stops if that layout has changed.

## Memory layout

| Region | Contents |
|---|---|
| ROM bank 0 | Fixed code, checked against the 16 KiB limit |
| Existing banks 1–63 | Original assets, 128 poses, background and HUD; identity record is the exception below |
| Start of bank 54 | Water-off identity converted to the 15-byte packet format |
| Banks 64–127 | 256 phases × 4 KiB; no record crosses a 16 KiB bank boundary |
| Bank 127 tail | `S3WP` marker checked at startup for upper-bank access |
| VRAM | Unchanged: pages 0/1 display, 2 work/pose cache, 3 background/HUD |

Water uses 111–137 commands per phase, averaging 123.27. The 473,882 bytes of records reserve 1,048,576 bytes for simple addressing. Water-off uses one command. No extra image cache was added. Both implementations end BSS at 0xC077, below telemetry at 0xCF00. ASCII16 2 MiB mapping was verified in the pinned emulator; physical cartridge compatibility is untested.

## Measurements

| CPU | Playback | Old V9968 FPS | New V9968 FPS | Gain | V9990 FPS |
|---|---|---:|---:|---:|---:|
| Z80 | animated | 15.82 | 16.56 | +4.71% | 15.13 |
| Z80 | sequence | 15.53 | 16.34 | +5.22% | 14.77 |
| R800 | animated | 15.93 | 16.31 | +2.39% | 20.75 |
| R800 | sequence | 15.73 | 16.06 | +2.09% | 20.46 |

Mean draw / synchronization wait in milliseconds, averaged across three independent runs:

| CPU | Mode | Old draw / sync ms | New draw / sync ms | V9990 draw / sync ms |
|---|---|---:|---:|---:|
| Z80 | animated | 54.86 / 7.69 | 50.05 / 9.65 | 57.25 / 8.16 |
| Z80 | sequence | 55.60 / 7.74 | 50.49 / 9.66 | 58.03 / 8.64 |
| R800 | animated | 54.14 / 8.30 | 52.03 / 8.94 | 37.55 / 10.31 |
| R800 | sequence | 54.57 / 7.96 | 52.52 / 8.71 | 37.75 / 10.11 |

The new V9968 implementation leads V9990 on Z80; V9990 leads on R800. Fixed-work draw time falls from 55.60 to 50.49 ms on Z80 and from 54.57 to 52.52 ms on R800. Increased synchronization waiting offsets part of that saving, so draw-time savings and FPS gains differ. CPU-side preparation was reduced; these measurements do not show a change in the VDP's intrinsic execution speed.

All runs use openMSX 21.0 V9968 fork d884c4b, Z80 3,579,545 Hz / R800 ROM mode 7,159,090 Hz, 512 KiB RAM, speed 100%, `cmdtiming real`, VSync, and `maxframeskip 0`. Renderer none, throttle false, null audio with PSG calculation enabled, no recorder. A five-second warm-up precedes approximately 15 seconds of animation or the same complete 256-frame sequence. Each case uses three independent starts.

FPS is completed frames divided by emulated elapsed time. Draw ends after CE completion; sync wait ends at page switch. Median/P95 values are in [measurements](results-v9968-packets/measurements.json). Animated playback follows the same timeline but samples different poses/phases when throughput differs. Fixed work uses the same 256 pairs.

Old V9968 and V9990 timing results are reused after checking ROM, emulator, machine XML, measurement-script hashes and settings. The 12 new timing runs are for the new V9968 implementation. Old V9968 pixel verification was rerun this time.

Commands, VRAM layout and display timing still differ between VDPs. The inherited V9968 XML includes `timing=0`; its isolated effect was not measured. Preparation methods are more closely aligned, but conditions are not completely identical and this is not isolated VDP performance. No real-hardware performance claim is made.

## Verification

- Generator: all 256 phases plus identity; 12,632,064 destination/source-pixel mappings, no holes or overlaps. Checks coordinates, opcodes, even widths, record/bank boundaries, upper-bank marker, and invalid input rejection.
- Both CPUs: 385 samples each for old, new, and C-language diagnostic ROMs match the independent pixel oracle.
- Both CPUs: old versus new and assembly versus C-language sender match all 128 KiB of VRAM in every one of 385 samples.
- Both CPUs: another 385 new-version samples with a bright grid verify edges, work image, and fixed HUD.
- Settled RGB screenshots and palettes at the same pose/phase were compared with the old version.
- Both CPUs: continuous playback, W, P pause/resume, changing PSG registers, and Esc stop/mute. Listening-based audio comparison was not performed.
- A CPU-fed HMMC with no supplied data is injected immediately before the new sender. Both assembly and C-language builds on both CPUs reach FAULT=1 and mute through the CE watchdog.

The 385 samples cover 128 poses and 256 phases separately, not all 128×256 combinations. Immediate first-frame screenshots can be black under the known capture condition; settled captures render the same request twice. The first diagnostic attempted to read an absent R800 frequency on a Z80 machine and timed out. The diagnostic was corrected and rerun; ROM pixel and timing tests were unaffected.

The inherited V9968 VBlank wait has no timeout and remains unchanged. V9990's FAULT=3 test is not claimed for V9968. CPU command transmission time and CE busy time have not been isolated.

## Rebuild and reproduce

Run from the repository root. Requires Python 3, z88dk, and Pillow for pixel checks. These commands generate only the new and diagnostic ROMs.

```powershell
python demos/scene3-v9990/build-reference-packets.py --z88dk "<z88dk root>"
python demos/scene3-v9990/build-reference-packets.py --z88dk "<z88dk root>" --c-stream
python demos/scene3-v9990/check-v9968-packets.py
python demos/scene3-v9990/suite.py --kind verify --variants reference-packets reference-packets-c --runtimes "<runtime parent>" --output "<new private verify folder>" --timeout 900
python demos/scene3-v9990/suite.py --kind measure --variants reference-packets --runtimes "<runtime parent>" --output "<new private measure folder>" --timeout 900
```

Build both before the verification command. Direct old/new comparison also requires the old ROM's matching map. Preserve `build/reference`; if absent, build `build.py --variant reference` in a separate working copy and use its map only after confirming the ROM hash matches. Do not overwrite the recorded old ROM to make it match.

Run the additional checks for each CPU. Also run the CE fault test with `--variant reference-packets-c`.

```powershell
python demos/scene3-v9990/run-test.py --variant reference-packets --runtime "<runtime>" --script demos/scene3-v9990/edge-fixture.tcl --output "<new private edge folder>" --timeout 900
python demos/scene3-v9990/verify.py "<new private edge folder>" --variant reference-packets --fixture
python demos/scene3-v9990/run-test.py --variant reference-packets --runtime "<runtime>" --script demos/scene3-v9990/integration.tcl --output "<new private input folder>" --display --timeout 900
python demos/scene3-v9990/run-test.py --variant reference-packets --runtime "<runtime>" --script demos/scene3-v9990/fault-v9968-packets.tcl --output "<new private fault folder>"
python demos/scene3-v9990/run-test.py --variant reference-packets --runtime "<runtime>" --script demos/scene3-v9990/capture-v9968-packets.tcl --output "<new private capture folder>" --display
python demos/scene3-v9990/compare-v9968-dumps.py "<old verify session>" "<new verify session>"
```

Raw sessions contain personal paths and owned BIOS copies: use new private output folders outside the repository. Launch BATs accept `-VerifyLaunch -Runtime "<runtime>" -UserRoot "<private folder>"` for automated startup checks.

Records: [summary](results-v9968-packets/summary.json), [direct pixels](results-v9968-packets/direct-pixels.json), [verification](results-v9968-packets/verification.json), [hashes/environment](results-v9968-packets/provenance.json). No release ZIP or public distribution manifest was updated.
