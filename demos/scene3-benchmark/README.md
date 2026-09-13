[日本語](README.ja.md)

# SCENE3 BENCHMARK

A separate demo comparing the underwater ruins, moving geometry and water distortion on V9968 and conventional VDPs. It uses the same 1 MiB ROM with the ASCII16 mapper on both emulators. The existing six-scene demo remains available separately.

## Launch

Run the corresponding setup BAT at the repository root, then open one of these BATs. z88dk is not required to run the demo.

| Environment | V9968 | Standard V9958 |
|---|---|---|
| C-BIOS / Z80 | [launch-cbios-v9968.bat](../../tools/benchmark/launch-cbios-v9968.bat) | [launch-cbios-standard.bat](../../tools/benchmark/launch-cbios-standard.bat) |
| FS-A1GT / R800 | [launch-fsa1gt-v9968.bat](../../tools/benchmark/launch-fsa1gt-v9968.bat) | [launch-fsa1gt-standard.bat](../../tools/benchmark/launch-fsa1gt-standard.bat) |

FS-A1GT uses the user's own BIOS from the installed runtime. Benchmark settings are isolated in user-scene3-benchmark under runtime. Existing demo settings are unchanged. Close the emulator before deleting this benchmark user directory to reset its settings.

## Controls and modes

| Key | Action |
|---|---|
| F | Cycle FULL, FAST, COMPAT, FULL on V9968 |
| P | Freeze geometry and water phase / resume animation. Rendering, BGM and FPS measurement continue |
| Esc | Stop video and BGM. Close the window and launch again to restart |

| Mode | Fast commands | Palette |
|---|---|---|
| FULL | ON | 5 bits per RGB component, 16 colors selected from 32,768 |
| FAST | ON | 3 bits per RGB component, 16 colors selected from 512 |
| COMPAT | OFF | 3 bits per RGB component, 16 colors selected from 512 |

Conventional VDPs remain in COMPAT. The screen shows the mode at the top and VDP, CPU and FPS at the bottom. FPS updates after approximately two seconds following a mode change. Input is sampled once per rendered frame, so hold keys slightly longer in slow modes.

The standard palette uses round(original component × 7 / 31). The screen still has 16 colors, but hues and shading may change. Switching temporarily blanks the display while rewriting the palette, which may cause a brief dark flash.

| FULL: extended palette | FAST: standard palette |
|---|---|
| ![FULL](images/full.png) | ![FAST](images/fast.png) |

## Measurements

Checked on 2026-09-10 on Windows 10 x64 using openMSX 21.0 and fork d884c4b. Each sample uses the same ROM, 60 Hz, a fixed pose and water phase selected with P, and approximately 12 seconds. All drawing still runs, including HUD, BGM and VSync waits. Timing uses emulated time, not host PC processing speed.

| Configuration | C-BIOS / Z80 FPS | FS-A1GT / R800 FPS |
|---|---:|---:|
| V9968 FULL | 6.00 | 7.50 |
| V9968 FAST | 6.00 | 7.50 |
| V9968 COMPAT | 1.94 | 2.07 |
| Standard V9958 | 1.67 | 1.76 |

FPS = completed page flips × 60 / elapsed VBlank count. The HUD uses approximately two-second windows; the table uses approximately twelve-second windows, with actual completed-frame timestamps at the boundaries. F and P reset the measurement window. During animation, drawing work varies with the pose and so does FPS.

V9968 COMPAT and standard V9958 do not have identical performance. The comparison also includes differences between emulator implementations. These numbers do not guarantee physical hardware performance or a speed ratio for every command. The rendered scene region in FAST and COMPAT was pixel-identical at the fixed pose. Physical hardware, V9938 and other fork revisions remain untested.

[Detailed test results (JSON)](results.json) / [Technical slides (Japanese PPTX)](technical-notes.ja.pptx) / [Technical slides (Japanese PDF)](technical-notes.ja.pdf)

## C source and rebuilding

Run from the repository root, replacing the z88dk placeholder with your installation directory. Python 3 and Pillow are also required.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File demos\scene3-benchmark\build.ps1 -Z88dk "<z88dk directory>"
```

main.c renders only Scene 3. The benchmark shares v9968.c, mapper.c, platform.c, music.c and precomputed data with the existing demo. SCENE3_BENCHMARK enables the standard palette and conventional VDP startup paths. Rebuilding updates the benchmark ROM and rom.json, but does not replace the existing demo ROM. The shipped ROM is the one the published measurements were taken on, and results.json records its hash. A rebuild from the current sources picks up the shared code and assets as they are now, so it produces a ROM with a different hash; no measurements are published for a rebuilt one. The commit and toolchain the shipped ROM was built from are not recorded, so treat the pair of ROM and results.json as the reference rather than trying to reproduce it.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File demos\scene3-benchmark\test.ps1 -Runtime runtime\cbios
powershell.exe -NoProfile -ExecutionPolicy Bypass -File demos\scene3-benchmark\test.ps1 -Runtime runtime\cbios -Standard
```

Use runtime\fsa1gt for FS-A1GT. Tests save results and screenshots in a separate test-output directory. They inject F, P and Esc through the emulator keyboard matrix and check mode changes, R20, continued rendering and FPS. This is distinct from manually pressing a physical keyboard. FS-A1GT test directories contain local BIOS copies and must not be published.

## Implementation and sources

HMMM handles background copies, capture and water bands; LMMV draws polygon spans; LMMM fills the horizontal edges. LRMM is not used. Four pages require 128 KiB of VRAM. Rotation and projection use the existing demo's precomputed tables.

- [Fork VDP.hh](https://github.com/buppu3/openMSX/blob/d884c4b/src/video/VDP.hh): R20 HS=0x01 and EPAL=0x10.
- [Fork VDP.cc](https://github.com/buppu3/openMSX/blob/d884c4b/src/video/VDP.cc): extended palettes use three R/G/B bytes; standard palettes use two RB/G bytes.
- [Fork command implementation](https://github.com/buppu3/openMSX/blob/d884c4b/src/video/VDPCmdEngine.cc): fast command behavior.
- [openMSX ASCII16](https://github.com/openMSX/openMSX/blob/RELEASE_21_0/src/memory/RomAscii16kB.cc): bank switching used here.
- Thanks to the author of [MSX 8x8 font](../v9968-tech-demo/third-party/fonts/README.md), also used by the existing demo. That document provides attribution and usage terms.

Primary sources checked on 2026-09-10. Register values target the pinned fork and must not be assumed to match other implementations.
