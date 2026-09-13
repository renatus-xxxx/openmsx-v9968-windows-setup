param([string]$OutputZip)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSHOME 'Modules/Microsoft.PowerShell.Utility/Microsoft.PowerShell.Utility.psd1') -ErrorAction Stop
$root=Split-Path -Parent $PSScriptRoot
& (Join-Path $root 'tests/validate-public.ps1') -Root $root
$m=Get-Content -LiteralPath (Join-Path $root 'config/versions.json') -Raw | ConvertFrom-Json
if(!$OutputZip){$OutputZip=Join-Path $root "dist/openmsx-v9968-windows-setup-$($m.release).zip"}
$OutputZip=[IO.Path]::GetFullPath($OutputZip)
if(Test-Path -LiteralPath $OutputZip){throw 'Output ZIP already exists. Use a new filename; no overwrite.'}
[IO.Directory]::CreateDirectory((Split-Path -Parent $OutputZip)) | Out-Null
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$list=@(Get-Content -LiteralPath (Join-Path $root 'config/PUBLIC_FILES.txt') | Where-Object {$_ -and !($_.StartsWith('#'))})
# Build under a working name and take the final one only once the archive has
# passed its own check. Writing straight to the release name leaves a rejected
# or half-written ZIP sitting there under the name people download, and the
# refusal to overwrite then blocks the next attempt as well.
$pending="$OutputZip.$([guid]::NewGuid().ToString('N')).partial"
try{
 $zip=[IO.Compression.ZipFile]::Open($pending,[IO.Compression.ZipArchiveMode]::Create)
 try {
  foreach($rel in $list){
   [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,(Join-Path $root $rel),$rel.Replace('\','/'),[IO.Compression.CompressionLevel]::Optimal) | Out-Null
  }
 }finally{$zip.Dispose()}
 & (Join-Path $root 'tests/validate-public.ps1') -Root $root -ZipPath $pending
 Move-Item -LiteralPath $pending -Destination $OutputZip
}catch{
 if(Test-Path -LiteralPath $pending){Remove-Item -LiteralPath $pending -Force}
 throw
}
Get-FileHash -LiteralPath $OutputZip -Algorithm SHA256
