[日本語](sources.ja.md) | English

# Primary sources and licenses

[Home](../README.md)

Version and hash facts were checked on 2026-09-09. The configuration is pinned and does not track the latest release.

| Subject | Primary source |
|---|---|
| Official release | [openMSX 21.0](https://github.com/openMSX/openMSX/releases/tag/RELEASE_21_0) |
| Official ZIP digest | [GitHub release API](https://api.github.com/repos/openMSX/openMSX/releases/tags/RELEASE_21_0) |
| V9968 fork downloads and hardware differences | [buppu3](https://buppu3.github.io/) |
| Fork source | [v9968 branch](https://github.com/buppu3/openMSX/tree/v9968) |
| C-BIOS status | [C-BIOS Association](https://cbios.sourceforge.net/) |
| Machine/ROM setup | [openMSX setup guide](https://openmsx.org/manual/setup.html) |
| Dump tools | [blueMSX developer resource page](https://www.vik.cc/bluemsx/resource.html) |
| C toolchain | [z88dk MSX platform](https://github.com/z88dk/z88dk/wiki/Platform---MSX) |
| V9968 detection sample | [HRA! devcon](https://github.com/hra1129/V9968_Cartridge/tree/main/fpga/V9968_Cartridge_TangNano20K/src/v9968/devcon) |
| Drawing samples | [HRA! test_pattern](https://github.com/hra1129/V9968_Cartridge/tree/main/fpga/V9968_Cartridge_TangNano20K/src/v9968/test_pattern) |
| V9968 programming manual | [HRA! manual](https://github.com/hra1129/V9968_Cartridge/tree/main/fpga/V9968_Cartridge_TangNano20K/src/v9968/manual) |

URLs, archive sizes and hashes have a single machine-readable source: [config/versions.json](../config/versions.json). SHA-256 measurements do not replace a publisher's digital signature. No ROM download source is provided.

## Licenses

- Newly written scripts and the probe ROM source: [MIT LICENSE](../LICENSE).
- Reference machine XML derives from official openMSX 21.0 and retains GPL terms: [original GPL](../licenses/GPL-openMSX.txt). Changes to VDP/display name and their date are marked in the XML. Setup applies the same transformation to downloaded official definitions.
- C-BIOS is 2-clause BSD: [original notice](../licenses/C-BIOS.txt). The BIOS is downloaded with official openMSX, not redistributed in this package.
- The compiled probe ROM uses z88dk library code: [original z88dk license](../licenses/z88dk.txt). This notice does not replace file-specific upstream terms.
- Third-party dump utilities are linked, not redistributed. Your physical-machine ROMs and generated installations are excluded.

Original legal texts are preserved unchanged. The Japanese companion is an explanatory guide, not a translated replacement license. If you distribute a separately assembled emulator package, assess that package's own source/notice obligations; this helper distribution does not do that for you.
