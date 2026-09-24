[日本語](release-notes.ja.md) | English

# Release notes — 0.7.4

Update V9968-enabled openMSX to **14215c7 (2026-09-24)** with pinned archive and executable hashes. Official openMSX 21.0 and C-BIOS 0.29 remain unchanged.

- Existing demo and probe ROMs are unchanged. Automatic detection selects R20=0x11 on the new register map.
- Validate scenes, water, headers and probes on both machines; strengthen R20/LRMM regression checks. See [changes and validation](emulator-update-20260924.md).
- Add Scene 3 V9968/V9990 comparison sources and measurement records to the repository. Comparison ROMs and the comparison directory are excluded from the distribution ZIP.
- Clarify register differences, historical measurements, and update/rollback instructions in both languages.

Extract the entire ZIP into a separate folder and run setup; do not overwrite the old environment or reuse its runtime/cache. See [update and rollback](troubleshooting.md#update-and-rollback).

Physical FPGA hardware, the external 0x88 profile, clean OS installations and old save-state compatibility were not retested for this update. The external ROM remains byte-identical to 0.7.3. Performance measurements describe emulation, not physical VDP performance.
