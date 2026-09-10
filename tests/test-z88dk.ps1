param([Parameter(Mandatory=$true)][string]$Toolchain)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/../scripts/find-z88dk.ps1"
$Toolchain=[IO.Path]::GetFullPath($Toolchain)
if(!(Test-Z88dkRoot $Toolchain)){throw 'Test needs a complete toolchain supplied with -Toolchain'}
$saved=@{};foreach($name in @('PATH','Z88DK','ZCCCFG')){$saved[$name]=[Environment]::GetEnvironmentVariable($name,'Process')}
try {
 $env:Z88DK=$null;$env:ZCCCFG=$null;$env:PATH="$env:SystemRoot/System32"
 if(@(Get-Z88dkCandidates).Count -ne 0){throw 'Unexpected fixed candidate'}
 try {Resolve-Z88dk -Candidates @(Get-Z88dkCandidates) -Picker {$null};throw 'Unexpected success'}catch{if($_ -notmatch 'Cancelled'){throw}}
 if((Resolve-Z88dk -Explicit $Toolchain) -ne $Toolchain){throw 'Explicit failed'}
 foreach($source in @('Z88DK','ZCCCFG','PATH')){
  $env:Z88DK=$null;$env:ZCCCFG=$null;$env:PATH="$env:SystemRoot/System32"
  switch($source){Z88DK {$env:Z88DK=$Toolchain};ZCCCFG {$env:ZCCCFG=Join-Path $Toolchain 'lib/config'};PATH {$env:PATH=(Join-Path $Toolchain 'bin')+';'+$env:PATH}}
  if((Resolve-Z88dk -Candidates @(Get-Z88dkCandidates) -Picker {throw 'Unexpected picker'}) -ne $Toolchain){throw "Detection failed: $source"}
 }
 $env:Z88DK='missing';$env:ZCCCFG=Join-Path $Toolchain 'lib/config'
 if((Resolve-Z88dk -Candidates @(Get-Z88dkCandidates)) -ne $Toolchain){throw 'Invalid auto candidate was not skipped'}
 if((Resolve-Z88dk -Candidates @() -Picker {$Toolchain}) -ne $Toolchain){throw 'Selection failed'}
 try {Resolve-Z88dk -Explicit 'missing';throw 'Unexpected success'}catch{if($_ -notmatch 'Invalid z88dk'){throw}}
 try {Resolve-Z88dk -Candidates @() -Picker {'missing'};throw 'Unexpected success'}catch{if($_ -notmatch 'Invalid selection'){throw}}
 Write-Host 'PASS: no fixed candidate; explicit, environment, PATH, invalid/cancel branches (simulated picker)'
}finally{foreach($name in $saved.Keys){[Environment]::SetEnvironmentVariable($name,$saved[$name],'Process')}}
