[日本語](release-notes.ja.md) | English

# Release notes — 0.7.5

Add **Scene 7 — Shallow Water** to V9968 TECH DEMO. Press **7** to view it, or **0** for the seven-scene automatic sequence.

- Perspective stone floor, independently animated caustics, refraction and RGB5 Sprite mode3 reflections.
- A central sun-glitter path combines 20 white glints, 10 soft glare shoulders and eight translucent ribbons. Wave motion and lighting approximations are precomputed in Python; the MSX combines the assets at runtime.
- Stream sprite attributes with OTIR; retain an equivalent C-language implementation for validation.
- Expand the demo to an **8 MiB ASCII16-X ROM**. The launcher, mapper, build scripts and checks support the larger image. Plain ASCII16 mapping is insufficient. Existing benchmark ROMs remain unchanged.
- Keep pinned V9968 openMSX **14215c7**, openMSX 21.0 and C-BIOS 0.29 unchanged.

Scene 7 measures **9.00 fps on C-BIOS/Z80** and **11.20 fps on FS-A1GT/R800** in the pinned emulator (5-second warm-up, 15-second samples, three independent runs). These are emulator results, not hardware measurements. Both CPUs pass scene/pixel regression checks; external 0x88 and physical FPGA operation are not verified for this build. Transparency and glare are approximations, not additive HDR or a full fluid simulation.

See [Scene 7 details](../demos/v9968-tech-demo/SHALLOW.md). Extract the entire ZIP into a new folder and run the matching setup BAT. Keep your existing environment and BIOS separate; no proprietary BIOS is included.
