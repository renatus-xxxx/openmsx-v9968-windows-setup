param([Parameter(Mandatory=$true)][string]$Z88dk,[ValidateSet('all','a','b','c','reference')][string]$Variant='all',[switch]$RegenerateAssets)
$ErrorActionPreference='Stop'
$args=@('-X','utf8',(Join-Path $PSScriptRoot 'build.py'),'--z88dk',$Z88dk,'--variant',$Variant)
if($RegenerateAssets){$args+='--regenerate-assets'}
& python @args
if($LASTEXITCODE){throw 'Scene 3 build failed.'}
