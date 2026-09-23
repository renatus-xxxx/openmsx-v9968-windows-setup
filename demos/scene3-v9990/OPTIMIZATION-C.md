[日本語](OPTIMIZATION-C.ja.md) | English

# V9990 C: pre-generated packets and OTIR

## Results

Mean FPS for the fixed 256-frame sequence, after a 5-second warm-up, three independent starts. B/V9968 reuse existing results with matching hashes and conditions; C uses the final ROM measured in this iteration.

| CPU | V9968 | B | Packets + C loop (diagnostic) | C: packets + OTIR |
|---|---:|---:|---:|---:|
| Z80 | 15.53 | 5.42 | 7.59 | 14.77 |
| R800 | 15.73 | 10.48 | 12.94 | 20.46 |

C/B is 2.72x / 1.95x; C/V9968 is 0.95x / 1.30x. The diagnostic build defines `V9990_C_STREAM_REFERENCE` to consume the same packets through C loops. Its 385 Z80 samples also match the independent pixel oracle. It is a separate ROM, not the normal C release candidate.

Adopted changes are (1) dedicated packets removing coordinate decoding and calls, and (2) assembly packet traversal with OTIR. These are staged implementation comparisons, not an isolated measurement of the OTIR instruction alone. Band/rectangle merging, padded edge sources and VRAM pose caches remain unimplemented and unmeasured; they are not claimed as adopted optimizations.

## Data and rendering

- Generate a separate 2 MiB ROM from the original 1 MiB ROM; shared assets and A/B/reference ROMs stay unchanged.
- C banks10–41: 128 poses, 4096 bytes each. A 16-bit count precedes 10-byte rectangle records (R36–43, R48–49). The bounding box remains at offset4092.
- C banks64–127: 256 water phases, 4096 bytes each. A 16-bit count precedes 12-byte copy records (R32–43). Only the display-page byte is replaced at runtime.
- Bank54 contains the water-OFF packet. A signature in unused padding at the end of bank127 verifies upper-bank access at startup.
- 104–296 rectangles per pose; 111–137 water commands per phase including edge copies. Rectangle/band counts and copied pixels are unchanged from B.
- ROM capacity increases by1 MiB; the reserved1 MiB water table includes padding. VRAM remains128 KiB with384 KiB unused. BSS ends at0xc075, unchanged from B.
- Same16 RGB5 colors, background, radius88 octahedron, water equations, repeated edge pixels, fixed header, music and controls.

The assembly streams in `v9990.c` have adjacent equivalent C implementations under `V9990_C_STREAM_REFERENCE`. The ISR preserves registers and leaves command ports and mapper banks alone. A65535-poll CE watchdog ends in FAULT=1; stalled vertical sync ends in FAULT=3. Both disable interrupts and mute sound.

## Build and verification

Run from the repository root. Use a new private directory for each test output.

```powershell
python demos/scene3-v9990/build.py --z88dk "<z88dk root>" --variant c
python demos/scene3-v9990/suite.py --kind verify --variants c --runtimes "<runtime parent>" --output "<new private folder>" --timeout 900
python demos/scene3-v9990/suite.py --kind measure --variants c --runtimes "<runtime parent>" --output "<new private folder>" --timeout 900
```

Launch `tools/benchmark/launch-scene3-v9990-c-cbios.bat` or `launch-scene3-v9990-c-fsa1gt.bat`. Neither Python nor z88dk is needed for normal playback.

To build the C stream reference, copy the generated `build/c` into a separate private directory and add `-DV9990_C_STREAM_REFERENCE` to the same zcc options. Pad the fixed bank to16384 bytes and append bytes16384 onward from the production C ROM. Do not replace the production ROM, map or roms.json. See the [separate diagnostic record](results-c/c-stream-reference.json).

See [provenance](results-c/provenance.json), [measurements](results-c/comparison.json), [fault and input checks](results-c/checks.json) and [B/C VRAM comparison](results-c/b-c-pixels.json).

Each CPU passes385 samples covering all128 poses and256 phases; all captured B/C VRAM bytes match. This is not the full128×256 Cartesian product. A bright grid adds385 edge samples. Screenshots at pose37/phase37 also match in decoded RGB pixels.

Checks cover an intentionally incorrect palette, missing external VDP, stalled CE, stalled VBlank, and a stalled CE inside the assembly stream. Controls, changing PSG registers,75 seconds of continuous operation and Esc muting were verified. Actual hardware and exhaustive listening-based audio equivalence remain untested.

## Timing and limitations

Final C fixed-sequence draw time is58.03 ms on Z80 and37.75 ms on R800. Separate VBlank waits average8.64 /10.11 ms. Displayed FPS includes request-handoff gaps.

A separate32-sample diagnostic observes about15.60 /15.89 ms inside stream CE polling. This includes status reads and interrupt servicing. The remaining42.11 /21.88 ms includes transmission, CPU work and other waits; it is not pure transfer time. See [diagnostic results](results-c/profile.json). C-only `profile-c.tcl` verifies the instruction bytes before using debugger breakpoints; it adds no instrumentation instructions to the ROM.

The inherited V9968 machine XML contains `timing=0`; its isolated effect has not been measured. Results compare implementations in the pinned openMSX configuration, not isolated VDP speed or real hardware. Both V9968 and C use OTIR, but command formats and required settings differ.

## Comparison videos

Labels use separately measured normal-playback FPS: Z80 V9968 15.82 / C15.13, R800 V9968 15.93 / C20.75. These differ from the fixed-sequence table because the sampled pose/phase sequences differ.

V9968 is on top and C below. Capture15 seconds at original speed after5 seconds of warm-up; a30-second combined clip shows Z80 then R800. White English labels, H.264/yuv420p/AAC,640×1080. The60fps container rate is not the demo's rendering FPS. Audio comes only from V9968 and fades out over the last2 seconds. Recording and timing measurements are separate. Videos and raw private test outputs stay outside the repository.
