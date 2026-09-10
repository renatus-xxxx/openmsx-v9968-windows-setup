[日本語](release-notes.ja.md) | English

# Release notes — 0.6.1

[Home](../README.md)

A maintenance release. The scenes, controls, music and measurements are unchanged from 0.6.0; what changes is how the demo ROM is declared and how the project guards against future mistakes.

The tech demo ROM is now declared as standard **ASCII16** rather than ASCII16-X. The bank switching code was already writing bank numbers in a form both mappers accept, so the ROM itself behaves identically and still runs unchanged on ASCII16-X hardware. ASCII16 is declared because it is far more widely implemented and nothing in the demo needs the extension. In practice this is future headroom rather than something most people can exercise today: V9968 exists in hardware only as a small-run FPGA cartridge, so the emulator remains the realistic way to run this.

The demo launcher now uses the ROM shipped in the ZIP by default. Previously a local `build/` output took priority, so a developer who had built once could keep running a stale ROM after upgrading without noticing. Developers select their own build with `-UseBuild`.

Frame counts are now generated alongside the bank layout and used as the runtime masks, so changing the number of generated frames can no longer read into the next asset. The asset generator also refuses to build a ROM that would exceed the 256-bank ASCII16 limit, and its error names ASCII16-X as the replacement.

Extract the entire 0.6.1 ZIP from Release Assets into a new folder and run the matching setup BAT. Existing 0.5.0 and 0.6.0 environments keep working; setup stops rather than overwriting one.

BIOS and emulator executables are not bundled. See [demo limitations](../demos/v9968-tech-demo/README.md) and [benchmark measurements](../demos/scene3-benchmark/README.md).
