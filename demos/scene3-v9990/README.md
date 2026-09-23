[日本語](README.ja.md) | English

# SCENE 3 V9990 comparison

## Pre-generated V9968 body and edge commands

A separate comparison ROM now pre-generates HMMM/LMMM packets in Python while preserving pixels and the old ROM. Animated FPS improves by 4.71% on Z80 and 2.39% on R800; ROM size is 2 MiB.

See [implementation, launch, measurements and reproduction](V9968-PACKETS.md). The table distinguishes the retained baseline from the new measurements.

| CPU | Playback | Old V9968 FPS | New V9968 FPS | Gain | V9990 FPS |
|---|---|---:|---:|---:|---:|
| Z80 | animated | 15.82 | 16.56 | +4.71% | 15.13 |
| Z80 | sequence | 15.53 | 16.34 | +5.22% | 14.77 |
| R800 | animated | 15.93 | 16.31 | +2.39% | 20.75 |
| R800 | sequence | 15.73 | 16.06 | +2.09% | 20.46 |


Independent ROMs using the current SCENE 3 background, radius-88 octahedron, 128 poses and water distortion. Existing demos and published benchmark ROMs remain unchanged. These files are not added to the release ZIP.

- **A** specifies command settings for each operation.
- **B** uses consecutive V9990 register writes and keeps invariant ARG/WM settings. It uses the same images, transfer workload and asset capacity as A.
- **C**: pre-generated V9990 packets sent with OTIR; identical pixels and VRAM layout, with a 2 MiB ROM.
- **reference** is a new V9968 fast-command/RGB5 comparison ROM.

## Launch

The comparison ROMs are not kept in this repository. They are not part of the
distribution, so committing several megabytes of binaries would only enlarge the
history. Build them first with the commands under [Build and reproduce](#build-and-reproduce).
`launch.ps1` checks each ROM against `roms.json` and stops with a rebuild message
when one is missing or does not match.

Complete the corresponding setup at the repository root, then run:
- `tools/benchmark/launch-scene3-v9990-a-{cbios,fsa1gt}.bat`
- `tools/benchmark/launch-scene3-v9990-b-{cbios,fsa1gt}.bat`
- `tools/benchmark/launch-scene3-v9990-c-{cbios,fsa1gt}.bat`
- `tools/benchmark/launch-scene3-v9968-reference-{cbios,fsa1gt}.bat`
- `tools/benchmark/launch-scene3-v9968-packets-{cbios,fsa1gt}.bat`

`cbios` uses Z80; `fsa1gt` uses R800 ROM mode. Launch requires neither Python nor z88dk. A/B/C add `gfx9000` to the standard-VDP machine and select the GFX9000 output. The reference uses the configured V9968 machine. All use the same pinned emulator executable.

P pauses/resumes, resetting pose and phase to zero. W toggles water distortion. Esc stops rendering and mutes sound; close the emulator window to exit.

Private settings and working copies go to `%LOCALAPPDATA%/openmsx-v9968-windows-setup/scene3-v9990/<mode>/<variant>/<ROM hash>`. Override with `launch.ps1 -Runtime <path> -UserRoot <path>`. User-owned BIOS files are copied locally into this private area. Existing runtime, BIOS and demo settings are unchanged. Close the emulator before removing only this private area.

## Results

Displayed FPS: the same 256 frames, 5-second warm-up, three independent starts.

| CPU | V9968 | V9990 A | V9990 B | B / A |
|---|---:|---:|---:|---:|
| Z80 | 15.53 | 3.03 | 5.42 | 1.79x |
| R800 | 15.73 | 6.44 | 10.48 | 1.63x |


In the original A/B comparison, V9968 was fastest. The additional C results follow below. These are not hardware performance results. See [Detailed test results (JSON)](results/measurements.json) and [conditions and hashes](results/provenance.json).

## Additional C results

| CPU | V9968 reference | V9990 B | V9990 C | C / B | C / V9968 |
|---|---:|---:|---:|---:|---:|
| Z80 | 15.53 | 5.42 | 14.77 | 2.72x | 0.95x |
| R800 | 15.73 | 10.48 | 20.46 | 1.95x | 1.30x |

Mean FPS for the fixed 256-frame sequence, three independent starts. C was measured again with its final ROM. B and V9968 reuse existing measurements after matching ROM hashes and execution conditions. C approaches V9968 on Z80 and exceeds it on R800 in this emulator configuration; this is not a hardware performance guarantee.

[C optimization, verification and reproduction](OPTIMIZATION-C.md) / [Comparison results (JSON)](results-c/comparison.json) / [C provenance](results-c/provenance.json). Existing A/B/reference ROMs and results/ are unchanged. C is an additional 2 MiB ASCII16 ROM and requires the complete repository artifacts; it has not been added to the public ZIP.

## Rendering

B1/BP4 displays 256×212; the common comparison region is the upper 256×192. The bottom 20 rows retain dark palette index 0. All variants use 16 RGB5 colors. Display buffers, work image, background and HUD use the first 128 KiB of logical VRAM. The remaining 384 KiB is unused. The fixed HUD overlays the water result with index 0 transparent. Horizontal edges repeat edge pixels; vertical clamping follows the original two-row calculation.

385 samples cover all 128 poses and all 256 phases separately, not their full Cartesian product. Work and display pixels match an independent oracle for all three variants on both CPUs. Another 385 samples per variant with a bright grid verify edge repetition. See [pixels](results/pixels.json), [edges](results/edges.json), and [input, PSG and continuous playback](results/integration.json). The integration checks automatically compare all 16 RGB5 palette entries for both A/B and both CPUs. A deliberately changed palette entry was rejected.

## Build and reproduce

Run from the repository root. Building requires z88dk and Python 3; asset regeneration and pixel verification require Pillow. No new library is linked into the ROM.

```powershell
python demos/scene3-v9990/build.py --z88dk "<z88dk root>"
python demos/scene3-v9990/build.py --z88dk "<z88dk root>" --regenerate-assets
python demos/scene3-v9990/suite.py --kind verify --runtimes "<runtime parent>" --output "<new private folder>"
python demos/scene3-v9990/suite.py --kind measure --runtimes "<runtime parent>" --output "<new private folder>"
```

Use `--variant a/b/c/reference` for one build, or `build.ps1 -Z88dk <path>`. The default build reuses the current demo ROM's asset payload. `--regenerate-assets` copies generators into private `build/asset-source` and regenerates there. Original assets are never modified. A/B/reference ASCII16 ROMs are 1 MiB and retain data for unused scenes. C is 2 MiB with its own generated command packets.

Test output includes private ROM/FS-A1GT BIOS copies. Always select a new private directory outside the repository; do not publish raw session logs. Only anonymous timing TSVs are collected under [results/timings](results/timings). Rebuilding a different ROM requires new measurements; existing results stay associated with their recorded hashes.

`main.c` handles common sequencing; `v9990.c/.h` own VDP-specific behavior. The reference VDP implementation, mapper, keyboard/CPU helpers and music are read from the sibling `v9968-tech-demo` directory at build time. IM2, atomic tick reads and DI need assembly for interrupt ABI correctness; adjacent comments describe their meaning.

## Measurement and limitations

Both machines have 512 KiB RAM. Startup readback confirms Z80 3,579,545 Hz / R800 7,159,090 Hz; speed setting is 100%. Same openMSX 21.0 V9968 fork d884c4b, `cmdtiming real`, VSync enabled, `maxframeskip 0`, renderer none, no recorder. The null audio driver leaves PSG computation enabled. Animated playback measures about 15 seconds after a 5-second warm-up. Fixed work runs the same 256 pairs (pose=index mod128, phase=index) after warm-up, with a 1 ms request delay. For the original A/B/reference runs it takes about 16–85 seconds to finish, deliberately replacing a fixed duration with a fixed workload.

FPS is completed frames divided by emulated elapsed time. Draw time ends after command completion; VBlank waiting is separate. Median/P95 cover draw start through display switch, excluding input/request gaps; the FPS denominator includes those gaps. Four shared volatile markers add a small CPU cost. Host debugger pause time is not used for FPS. Pure command transmission and VDP busy time were not isolated. C adds a separate diagnostic of stream polling intervals; see its optimization notes. Identical repeats demonstrate deterministic reproduction, not hardware confidence intervals.

B's consecutive writes and invariant-register elimination were measured as one change; their individual contributions were not isolated. Extra caches are unimplemented, unmeasured future ideas. Hardware, Windows 11, all 128×256 combinations, and listening-based audio equality are untested. PSG register changes and mute registers after Esc were verified.

## Sources and credits

- [Yamaha V9990 manual](https://map.grauw.nl/resources/video/yamaha_v9990.pdf)
- [openMSX GFX9000](https://openmsx.org/manual/user.html#gfx9000) / [cmdtiming](https://openmsx.org/manual/commands.html#cmdtiming)
- [openMSX V9990 implementation](https://github.com/openMSX/openMSX/tree/master/src/video/v9990)
- MSX 8x8 font by **1re1**. Retain the [original font credits and terms](../v9968-tech-demo/third-party/fonts/README.md).

New code follows the [repository LICENSE](../../LICENSE). Third-party manual text, BIOS files and emulator executables are not included here.

## Startup captures

Freezing request-driven playback after its very first frame can produce a partial emulator screenshot despite matching VRAM, display registers and palette. `screenshot.tcl` renders the same pose/phase twice and captures after a page switch. A/B screenshot RGB pixels then match exactly. This startup condition differs from continuously updated playback and is not established hardware behavior.

## Interpretation and additional verification

The old V9968 reference streams prepared rectangle packets with OTIR but expands compact water-band data at runtime. V9990 A/B issue individual OUT instructions to configure registers. The FPS differences therefore include this CPU-side transmission difference. B optimizes consecutive register writes and invariant settings; it does not establish the V9990 performance ceiling or isolated VDP speed. CPU and VDP execution times were not measured separately, so estimates derived from the two CPUs are not presented as measurements. C now adds pre-generated packets and OTIR transmission; the historical A/B results above remain unchanged.

`fps_excluding_request_gaps` divides completed frames by the sum of draw-start-to-display-switch durations. The primary `fps` metric also includes inter-frame gaps such as request handoff. It remains the displayed FPS result.

Reproduce the additional checks with the following commands. Replace `<variant>` with `a`, `b`, `c` or `reference`, and `<runtime>` with the corresponding installed environment. Use a new private output directory for every session. Captures and input checks require `--display`. On slower hosts, increase the host-time watchdog with e.g. `--timeout 900`; this does not change the emulated measurement interval.

```powershell
python demos/scene3-v9990/run-test.py --variant <variant> --runtime "<runtime>" --script demos/scene3-v9990/edge-fixture.tcl --output "<new edge folder>"
python demos/scene3-v9990/verify.py "<new edge folder>" --variant <variant> --fixture
python demos/scene3-v9990/run-test.py --variant <variant> --runtime "<runtime>" --script demos/scene3-v9990/integration.tcl --output "<new input folder>" --display
python demos/scene3-v9990/run-test.py --variant <variant> --runtime "<runtime>" --script demos/scene3-v9990/screenshot.tcl --output "<new capture folder>" --display
```

The V9990 input test also compares all 16 RGB5 colors against expected values and fails on mismatch. FAULT=1 indicates a stuck CE, FAULT=2 an unsupported VDP, and FAULT=3 a stalled VBlank.

```powershell
python demos/scene3-v9990/run-test.py --variant a --runtime "<runtime>" --script demos/scene3-v9990/fault.tcl --fault 1 --output "<new fault folder>"
python demos/scene3-v9990/run-test.py --variant a --runtime "<runtime>" --script demos/scene3-v9990/missing-device.tcl --without-target --display --output "<new missing-device folder>"
```

Use `--fault 3` to test a stalled VBlank.

Additional notes: in animated playback, `fps_excluding_request_gaps` also excludes inter-frame work such as input handling. See [fault checks and retry results](results/review-checks.json). `smoke.tcl` is an initial diagnostic for initialization, frame count and registers. The CE-stall test injects an LMMC from the debugger without supplying input; it tests the watchdog separately from the normal drawing command sequence.
