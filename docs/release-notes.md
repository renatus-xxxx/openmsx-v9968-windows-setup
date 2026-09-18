[日本語](release-notes.ja.md) | English

# Release notes — 0.7.3

Add external HRA! V9968 cartridge support at I/O base `0x88`, alongside the existing internal `0x98` profile. Thanks to @herraa1 (ahmsx) for the contribution and hardware reports.

- Include `V9968-TECH-DEMO-external-0x88.rom` in the Release ZIP. The root launch BATs continue to use the internal `V9968-TECH-DEMO.rom` with openMSX.
- Provide matching `internal-0x98` / `external-0x88` profiles in Windows `build.ps1` and Linux `build.py`, with configurable `VDP_BASE`, PORT#4 initialization and internal-VDP interrupt handling for the external cartridge.
- Rebuild both 1 MiB ROMs on Windows and WSL Ubuntu 24.04 with the matching z88dk toolchain; both profiles match byte for byte.
- Retest the final internal ROM on C-BIOS/Z80 and FS-A1GT/R800 in the pinned openMSX fork. Preserve historical benchmark ROMs and measurements.

The contributor-tested HRA! bitstream revision, path and SHA-256 are recorded in the [development guide](../demos/v9968-tech-demo/DEVELOPMENT.md). The final 0.7.3 external ROM was not separately retested by the contributor before release. Hardware reports using this release artifact are welcome.

Download `openmsx-v9968-windows-setup-0.7.3.zip` from Release Assets and extract it into a new folder. For Windows/openMSX, run the matching setup BAT, then the demo launch BAT. Linux support here is for rebuilding the demo ROM, not the Windows setup tools.
