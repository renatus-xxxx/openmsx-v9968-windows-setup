[日本語](CHANGELOG.ja.md) | English

[Home](../README.md)

# Changelog

## 0.7.4 — 2026-09-25

Update V9968-enabled openMSX to **14215c7 (2026-09-24)** with pinned archive and executable hashes. Official openMSX 21.0 and C-BIOS 0.29 remain unchanged.

- Existing demo and probe ROMs are unchanged. Automatic detection selects R20=0x11 on the new register map.
- Validate scenes, water, headers and probes on both machines; strengthen R20/LRMM regression checks. See [changes and validation](emulator-update-20260924.md).
- Add Scene 3 V9968/V9990 comparison sources and measurement records to the repository. Comparison ROMs and the comparison directory are excluded from the distribution ZIP.
- Clarify register differences, historical measurements, and update/rollback instructions in both languages.

Extract the entire ZIP into a separate folder and run setup; do not overwrite the old environment or reuse its runtime/cache. See [update and rollback](troubleshooting.md#update-and-rollback).

Physical FPGA hardware, the external 0x88 profile, clean OS installations and old save-state compatibility were not retested for this update. The external ROM remains byte-identical to 0.7.3. Performance measurements describe emulation, not physical VDP performance.

## 0.7.3 — 2026-09-18

Add external HRA! V9968 cartridge support at I/O base `0x88`, alongside the existing internal `0x98` profile. Thanks to @herraa1 (ahmsx) for the contribution and hardware reports.

- Include `V9968-TECH-DEMO-external-0x88.rom` in the Release ZIP. The root launch BATs continue to use the internal `V9968-TECH-DEMO.rom` with openMSX.
- Provide matching `internal-0x98` / `external-0x88` profiles in Windows `build.ps1` and Linux `build.py`, with configurable `VDP_BASE`, PORT#4 initialization and internal-VDP interrupt handling for the external cartridge.
- Rebuild both 1 MiB ROMs on Windows and WSL Ubuntu 24.04 with the matching z88dk toolchain; both profiles match byte for byte.
- Retest the final internal ROM on C-BIOS/Z80 and FS-A1GT/R800 in the pinned openMSX fork. Preserve historical benchmark ROMs and measurements.

## 0.7.2

- Wavefront OBJ meshes are now supported. The original octahedron shape remains the default, and Torus/Donut is an optional example. The default octahedron uses radius 88; the torus example explicitly uses radius 74. Rasterization and shading differ from 0.7.1; see the demo documentation before comparing images or performance.
- Preserve the 128 × 4096-byte MESH format; validate capacity, external OBJ paths, water and feedback rendering.

## 0.7.1 — 2026-09-15

- Animated FULL mode improved from **6.43 to 10.07 FPS on Z80** and **8.24 to 12.31 FPS on R800** in the pinned openMSX fork (three 15-second measurement windows). Animation timing is unchanged.
- Reuse the clean scene image, restore only the previous mesh bounds, merge water transfers and mesh rectangles, and reduce command-stream overhead.
- Include the optimized comparison ROM, updated preview GIFs, and detailed Japanese/English PDF documentation. Historical benchmark ROMs and their measurements remain separate.
- Add a selectable C reference implementation for mesh, glow and water command streams, with pixel comparisons against assembly on both machine configurations.
- Update PROBE to Revision 2 for more detailed LRMM and R20 compatibility diagnostics. FPGA retesting remains pending.
- Strengthen water-data bounds/coverage checks and ensure capture tests inspect only the current run.

## 0.7.0

- Add a sixth tech demo scene, 6 AFTERGLOW: a decaying trail that turns into recursive framebuffer feedback, built from VRAM-to-VRAM commands alone.
- Give that opening a greyscale palette in which brightness is the number of bits set in the colour index, and draw the solid flat, so a single AND per frame fades the trail by exactly one even step.
- Magnify the held page of that opening slightly each frame, so the fading copies move out from under the solid rather than being redrawn over and hidden.
- Draw the header of every scene onto the finished picture with a one-dot drop shadow, instead of restoring a strip of the background image behind it. The title is no longer baked into the background images, and the Scene 3 header band now moves with the water like the rest of the picture.
- Upload the palette once per frame and during the vertical blank. Uploading it twice during active display left a band of scanlines drawn with the other palette.
- Choose bit 5 of R20 at boot by running one LRMM and checking whether it happened, to accommodate the reported difference between the pinned fork and FPGA register maps. The FPGA branch remains unverified here.
- Stop with an explanation when the destination has an unsupported reparse point (often associated with cloud synchronization), instead of reporting it as a link or junction, and say where to extract instead.
- If the first LRMM probe fails and R20 switches to 0x31, run the probe again; otherwise retain the successful 0x11 result, so a wrong choice fails the capture test instead of silently costing Scene 6 its feedback. The probe sits behind one switch and can be retired in a single block when the emulators agree with the FPGA.
- Check that the header strip is present and that the picture under it survives the blit, not only that the text lands in the right place, and check that the header never reaches the history page of Scene 6's feedback.
- Require the benchmark results to name the ROM that ships, and require every script a BAT calls to be published, in the release check. Build the release ZIP under a working name and take the final one only after it passes.
- Turn the identification cartridge into a conformance probe. It runs a fixed set of experiments on the machine it boots on and prints what happened, for implementation comparisons. Poll counts are diagnostic observations, not comparable execution times across different CPUs; physical hardware remains unverified.
- Add a page recording where V9968 implementations are known to disagree, with the pinned fork's measurements filled in and the rest left open for reports.

## 0.6.1

- Declare the tech demo ROM as standard ASCII16 instead of ASCII16-X. The bank switching code is unchanged, and the same ROM still runs on ASCII16-X hardware.
- Use the shipped demo ROM by default; developers select their own build with `-UseBuild`.
- Generate frame counts into the bank layout and mask frame indices with them, so a changed count cannot read into the following asset.
- Stop the asset generator when a ROM would exceed the 256-bank ASCII16 limit, naming ASCII16-X as the replacement.
- Match the mapper-failure screen to the V9968-missing screen, and remove an unreachable branch from the demo launcher.

## 0.6.0

- Add V9968 TECH DEMO with MSX 8x8 font, five scenes and PSG music.
- Add SCENE3 BENCHMARK comparing V9968 with a conventional VDP, with FULL/FAST/COMPAT modes and measured results.
- Print setup, launch and BIOS join messages in English and Japanese, and report the measured VDP ID when identification fails.
- Keep two setup BATs and two machine-specific demo BATs at the root.
- Move identification-screen launchers to `tools/verify/`.
- Use independent CPU-switching and keyboard implementations.
- Rework the guides: a route comparison in README, the restored structure of the English dump guide, and troubleshooting grouped by situation.

## 0.5.0 — Initial release

- Setup using C-BIOS or user-owned FS-A1GT BIOS.
- Pinned downloads and hash verification.
- V9968 launch/identification, standard comparison and BASIC startup.
- BIOS joining and probe ROM build tools.
- English/Japanese setup and development instructions.
