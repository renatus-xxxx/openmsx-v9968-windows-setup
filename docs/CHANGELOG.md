[日本語](CHANGELOG.ja.md) | English

[Home](../README.md)

# Changelog

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
