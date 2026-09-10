param([string]$Root=(Split-Path -Parent $PSScriptRoot),[string]$ZipPath)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSHOME 'Modules/Microsoft.PowerShell.Utility/Microsoft.PowerShell.Utility.psd1') -ErrorAction Stop
$Root=[IO.Path]::GetFullPath($Root)
$list=@(Get-Content -LiteralPath (Join-Path $Root 'config/PUBLIC_FILES.txt') | Where-Object {$_ -and !($_.StartsWith('#'))})
if(@($list | Select-Object -Unique).Count -ne $list.Count){throw 'Duplicate public path'}
foreach($rel in $list){
 $full=[IO.Path]::GetFullPath((Join-Path $Root $rel))
 if(!$full.StartsWith($Root.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)){throw "Unsafe path: $rel"}
 if(!(Test-Path -LiteralPath $full -PathType Leaf)){throw "Missing public file: $rel"}
 if($rel -match '^(runtime|cache|private|build|dist)/|(^|/)(cache|private|build|dist|user|test-output|__pycache__)/|^demos/[^/]+/runtime/' -or $rel -match '\.(exe|dll|dsk|part|zip|log)$'){throw "Private/generated path: $rel"}
 if($rel -match '\.rom$' -and $rel -cnotin @('probe/PROBE.rom','demos/v9968-tech-demo/V9968-TECH-DEMO.rom','demos/scene3-benchmark/SCENE3-BENCHMARK.rom')){throw "Unexpected ROM: $rel"}
 if($rel -notmatch '\.(png|rom|gif|bin|pptx|pdf)$'){
  $text=[IO.File]::ReadAllText($full)
  if($text -match 'C:\\Users\\' -or $text -match ('MSX'+'PLAYer')){throw "Personal path or unrelated product reference: $rel"}
 }
 if($rel -match '\.md$'){
  $other=if($rel -match '\.ja\.md$'){$rel.Replace('.ja.md','.md')}else{$rel.Replace('.md','.ja.md')}
  if($list -notcontains $other){throw "Missing translation: $rel"}
  $text=[IO.File]::ReadAllText($full)
  if(($text -split "`n")[0] -notmatch [regex]::Escape((Split-Path -Leaf $other))){throw "Missing top language link: $rel"}
  foreach($match in [regex]::Matches($text,'\]\(([^)]+)\)')){
   $link=$match.Groups[1].Value
   if($link -match '^(https?://|mailto:|#)'){continue}
   $target=[uri]::UnescapeDataString(($link -split '#')[0])
   $dest=[IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $full) $target))
   if(!(Test-Path -LiteralPath $dest)){throw "Broken local link: $rel -> $link"}
   $prefix=$Root.TrimEnd('\')+'\'
   if(!$dest.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)){throw "Link outside package: $rel -> $link"}
   $destRel=$dest.Substring($prefix.Length).Replace('\','/')
   if((Test-Path -LiteralPath $dest -PathType Leaf) -and $list -cnotcontains $destRel){throw "Link target excluded from ZIP: $rel -> $link"}
  }
 }
}
$manifest=Get-Content -LiteralPath (Join-Path $Root 'config/versions.json') -Raw | ConvertFrom-Json
if((Get-FileHash -LiteralPath (Join-Path $Root 'probe/PROBE.rom')).Hash -ne $manifest.probeSha256){throw 'Probe hash mismatch'}


$expectedRoot=@('setup-cbios-v9968.bat','setup-fsa1gt-v9968.bat','launch-v9968-tech-demo-cbios.bat','launch-v9968-tech-demo-fsa1gt.bat')
$demoPath=Join-Path $Root 'demos/v9968-tech-demo/V9968-TECH-DEMO.rom'
if((Get-Item -LiteralPath $demoPath).Length -ne 1048576 -or (Get-FileHash -LiteralPath $demoPath).Hash -ne $manifest.demo.sha256){throw 'Demo ROM size/hash mismatch'}
$benchmarkPath=Join-Path $Root 'demos/scene3-benchmark/SCENE3-BENCHMARK.rom'
$benchmarkInfo=Get-Content -LiteralPath (Join-Path $Root 'demos/scene3-benchmark/rom.json') -Raw | ConvertFrom-Json
if((Get-Item -LiteralPath $benchmarkPath).Length -ne 1048576 -or (Get-FileHash -LiteralPath $benchmarkPath).Hash -ne $benchmarkInfo.sha256){throw 'Benchmark ROM size/hash mismatch'}
$actualRoot=@(Get-ChildItem -LiteralPath $Root -Filter '*.bat' -File | ForEach-Object {$_.Name})
if(Compare-Object $expectedRoot $actualRoot){throw 'Root must contain exactly four setup/launch BATs'}
foreach($rel in $list | Where-Object {$_ -like '*.bat'}){
 $batPath=Join-Path $Root $rel
 $bat=[IO.File]::ReadAllText($batPath)
 foreach($match in [regex]::Matches($bat,'%~dp0([^"\r\n]*\.ps1)')){
  $target=[IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $batPath) $match.Groups[1].Value))
  if(!(Test-Path -LiteralPath $target -PathType Leaf)){throw "Missing BAT target: $rel"}
 }

}

if($ZipPath){
 Add-Type -AssemblyName System.IO.Compression.FileSystem
 $archive=[IO.Compression.ZipFile]::OpenRead([IO.Path]::GetFullPath($ZipPath))
 try {
  $names=@($archive.Entries | ForEach-Object {$_.FullName})
  if($names.Count -ne $list.Count -or @($names | Select-Object -Unique).Count -ne $names.Count -or (Compare-Object $list $names -CaseSensitive)){throw 'ZIP entries differ from public allowlist'}
  foreach($entry in $archive.Entries){
   $stream=$entry.Open(); $sha=[Security.Cryptography.SHA256]::Create()
   try {$hash=([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','')}finally{$stream.Dispose();$sha.Dispose()}
   if($hash -ne (Get-FileHash -LiteralPath (Join-Path $Root $entry.FullName) -Algorithm SHA256).Hash){throw "ZIP content mismatch: $($entry.FullName)"}
  }
 }finally{$archive.Dispose()}
 Write-Host "PASS: ZIP entries and SHA-256 match $($list.Count) public files."
}
Write-Host "PASS: $($list.Count) public files; local links, language pairs, content, probe hash and BAT layout checked."
