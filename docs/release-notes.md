[日本語](release-notes.ja.md) | English

# Release notes — 0.6.0

[Home](../README.md)

Add the five-scene V9968 TECH DEMO using MSX 8x8 font. Solids, a perspective-style floor, underwater distortion and rotating panels play with PSG music.

Add SCENE3 BENCHMARK, a separate ROM that draws the same scene on V9968 and on a conventional VDP so the two can be compared. F cycles the FULL, FAST and COMPAT modes, and the screen reports VDP, CPU and FPS.

Setup, launch and the BIOS join helper now print every progress and error message in English and Japanese. A failed VDP identification also reports the value that was actually read.

Extract the entire 0.6.0 ZIP from Release Assets and run the matching setup BAT. Launch with `launch-v9968-tech-demo-fsa1gt.bat` or `launch-v9968-tech-demo-cbios.bat`. Identification-screen launchers have moved to `tools/verify/launch-*-v9968.bat`.

Keep existing 0.5.0 environments intact; extract 0.6.0 into another folder and set it up there. Advanced users may pass `-Runtime "existing runtime machine directory"` to a demo BAT. No existing environment is moved or overwritten by setup.

BIOS and emulator executables are not bundled. See [demo limitations](../demos/v9968-tech-demo/README.md) and [benchmark measurements](../demos/scene3-benchmark/README.md).
