[日本語](release-notes.ja.md) | English

# Release notes — 0.7.0

[Home](../README.md)

A tech demo release. The setup and launch steps are unchanged. Setup diagnostics, destination/cache checks and the identification cartridge have also been improved. The demo gains a sixth scene and a new way of drawing its header, and now sets one VDP register by asking the hardware rather than assuming.

**Scene 6 AFTERGLOW** is new. It opens on a bare frame with no header at all: the solid is drawn flat white into a page that is held between frames, and a single full-screen LMMV with the AND operation dims that page one step every frame. The palette there defines brightness as the number of bits set in the colour index, so clearing any one bit is exactly one step darker whatever the pixel started from, and the trail fades evenly to black. The held page is also magnified a little each frame: the solid covers almost the same pixels every time, so a trail that stayed put would simply be redrawn over, and growing the page walks the fading copies out from under it. After three seconds the header appears and the same page becomes the history frame of a recursive feedback: the previous picture is shifted with HMMM or zoomed and rotated with LRMM, the current solid is drawn over it, and the result is captured back. No CPU framebuffer processing and no runtime trigonometry are involved; the whole effect is VRAM-to-VRAM commands.

**Every scene now draws its header onto the finished picture** with a one-dot black drop shadow, in a single transparent blit. Previously the title was baked into the background images and the header area was a restored strip of one of them. That is why the Scene 3 header band used to stand still while the rest of the picture waved: restoring it was the only way to stop the baked title rippling as a ghost. The band is part of the distortion now, and the shadow keeps the text readable over it and over the busier parts of the other backgrounds.

**Bit 5 of R20 is chosen at boot.** It does not mean the same thing on every V9968 implementation: the pinned openMSX fork uses it to enable the extended commands, without which LRMM does nothing, while the FPGA map reported from a MSXimus uses it for flat interlace and runs LRMM without it. Rather than pick one, the demo writes the byte without the bit, runs one LRMM, reads the destination back, and only sets the bit if nothing moved. Thanks to MSX Barcelona for testing on real hardware and reporting the difference.

Extract the entire 0.7.0 ZIP from Release Assets into a new folder and run the matching setup BAT. Existing 0.5.0, 0.6.0 and 0.6.1 environments keep working; setup stops rather than overwriting one.

Physical hardware remains untested here: the demo is verified on the pinned emulator only, on both C-BIOS/Z80 and FS-A1GT/R800. BIOS and emulator executables are not bundled. See [demo limitations](../demos/v9968-tech-demo/README.md) and [benchmark measurements](../demos/scene3-benchmark/README.md).
