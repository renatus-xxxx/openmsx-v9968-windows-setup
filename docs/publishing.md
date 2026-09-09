[日本語](publishing.ja.md) | English

# Maintainer publishing instructions

Repository name: openmsx-v9968-windows-setup

Description:
> Unofficial Windows setup scripts for the V9968-enabled openMSX fork, with C-BIOS and user-supplied FS-A1GT BIOS support.

Review the [public allowlist](../config/PUBLIC_FILES.txt), [licenses](sources.md), [verification](verification.md) and [release notes draft](release-notes.md).

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\validate-public.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\package.ps1
```

The ZIP contains only allowlisted files, without an enclosing folder. Default output: dist/openmsx-v9968-windows-setup-0.5.0.zip. Existing ZIPs are not overwritten.

Do not add runtime, cache, private, build, dist or owned BIOS to Git. The only published ROM is the custom probe/PROBE.rom application. Check Git's selected files and archive contents before publication. Preserve original third-party notices.

config/PUBLIC_FILES.txt limits the files included in distribution. It is included in both the repository and ZIP so either can regenerate the package. See the [changelog](CHANGELOG.md).

LICENSE stays unchanged at the root, following the conventional location described by [GitHub's licensing guide](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository).

.gitattributes stays at the root to apply across the tree: CRLF for BAT/PowerShell, LF for Markdown, and binary handling for ROM/PNG. It does not specify encoding or BOM. ZIP extraction does not apply Git attributes, but the file is included for subsequent Git use. See the [official Git specification](https://git-scm.com/docs/gitattributes). References checked 2026-09-09.
