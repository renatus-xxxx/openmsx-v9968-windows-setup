function Test-Z88dkRoot([string]$Root) {
 if(!$Root){return $false}
 foreach($file in @('bin/zcc.exe','bin/z88dk-sccz80.exe','bin/z88dk-z80asm.exe','bin/z88dk-appmake.exe','lib/config/msx.cfg','lib/config/tools.inc','include/stdio.h','lib/target/msx/classic/msx_crt0.asm','lib/clibs/msx_clib.lib')) {
  if(!(Test-Path -LiteralPath (Join-Path $Root $file) -PathType Leaf)){return $false}
 }
 return $true
}
function Select-Z88dkFolder {
 Add-Type -AssemblyName System.Windows.Forms
 $dialog=New-Object Windows.Forms.FolderBrowserDialog
 $dialog.Description='Select the z88dk root folder (contains bin, lib, include) / z88dk のルートフォルダを選択'
 $dialog.ShowNewFolderButton=$false
 try {if($dialog.ShowDialog() -eq 'OK'){return $dialog.SelectedPath};return $null} finally {$dialog.Dispose()}
}
function Resolve-Z88dk {
 param([string]$Explicit,[string[]]$Candidates,[scriptblock]$Picker={Select-Z88dkFolder})
 if($Explicit){
  if(!(Test-Z88dkRoot $Explicit)){throw 'Invalid z88dk folder: required compiler/config/libraries missing / z88dk のコンパイラー・設定・ライブラリが不足しています。'}
  return [IO.Path]::GetFullPath($Explicit)
 }
 foreach($candidate in $Candidates){if(Test-Z88dkRoot $candidate){return [IO.Path]::GetFullPath($candidate)}}
 Write-Host 'z88dk not found. Select its root folder / z88dk が見つかりません。ルートフォルダを選択してください。'
 $selected=& $Picker
 if(!$selected){throw 'Cancelled; no build output created / キャンセルしました。ビルド成果物は作成していません。'}
 if(!(Test-Z88dkRoot $selected)){throw 'Invalid selection: choose a complete z88dk folder containing bin, lib and include / 選択先に必要な z88dk ファイルがありません。'}
 return [IO.Path]::GetFullPath($selected)
}
function Get-Z88dkCandidates {
 if($env:Z88DK){$env:Z88DK}
 if($env:ZCCCFG){Split-Path -Parent (Split-Path -Parent $env:ZCCCFG.TrimEnd('\','/'))}
 foreach($cmd in @(Get-Command zcc.exe -All -CommandType Application -ErrorAction SilentlyContinue)){Split-Path -Parent (Split-Path -Parent $cmd.Source)}
}
