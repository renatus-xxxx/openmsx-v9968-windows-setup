param([string]$Root=(Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference='Stop'
$Root=[IO.Path]::GetFullPath($Root)
$list=@(Get-Content -LiteralPath (Join-Path $Root 'config/PUBLIC_FILES.txt') | Where-Object {$_ -and !($_.StartsWith('#'))})
if(@($list | Select-Object -Unique).Count -ne $list.Count){throw 'Duplicate public path'}
foreach($rel in $list){
 $full=[IO.Path]::GetFullPath((Join-Path $Root $rel))
 if(!$full.StartsWith($Root.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)){throw "Unsafe path: $rel"}
 if(!(Test-Path -LiteralPath $full -PathType Leaf)){throw "Missing public file: $rel"}
 if($rel -match '^(runtime|cache|private|build|dist)/' -or $rel -match '\.(exe|dll|dsk|part|zip|log)$'){throw "Private/generated path: $rel"}
 if($rel -match '\.rom$' -and $rel -cne 'probe/PROBE.rom'){throw "Unexpected ROM: $rel"}
 if($rel -notmatch '\.(png|rom)$'){
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
  }
 }
}
$manifest=Get-Content -LiteralPath (Join-Path $Root 'config/versions.json') -Raw | ConvertFrom-Json
if((Get-FileHash -LiteralPath (Join-Path $Root 'probe/PROBE.rom')).Hash -ne $manifest.probeSha256){throw 'Probe hash mismatch'}
Write-Host "PASS: $($list.Count) public files; local links, language pairs, content and probe hash checked."

$expectedRoot=@('setup-cbios-v9968.bat','setup-fsa1gt-v9968.bat','launch-cbios-v9968.bat','launch-fsa1gt-v9968.bat')
$actualRoot=@(Get-ChildItem -LiteralPath $Root -Filter '*.bat' -File | ForEach-Object {$_.Name})
if(Compare-Object $expectedRoot $actualRoot){throw 'Root must contain exactly four setup/launch BATs'}
foreach($rel in $list | Where-Object {$_ -like '*.bat'}){
 $batPath=Join-Path $Root $rel
 $bat=[IO.File]::ReadAllText($batPath)
 if($bat -match '%~dp0([^"

]*entry\.ps1)'){
  if(!(Test-Path -LiteralPath (Join-Path (Split-Path -Parent $batPath) $Matches[1]))){throw "Missing BAT target: $rel"}
 }
}
