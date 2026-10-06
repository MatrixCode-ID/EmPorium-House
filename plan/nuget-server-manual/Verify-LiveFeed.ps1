<#
Purpose: test an enabled local feed with a real robot account, without using any public feed.
Prerequisites: NuPak installed and enabled; registered Prefix; robot has W; .NET 10 SDK; hosts built.
Parameters: Source is the loopback V3 index; RobotName/RobotToken are real credentials; Prefix must exist.
Impact: pushes one uniquely named smoke package and recycles it. Purge it later in NuGet Manager.
No existing package is deleted. Credentials are restored/removed from this process environment on exit.
#>
param(
    [string]$Source = 'http://localhost:5232/nuget/v3/index.json',
    [Parameter(Mandatory)][string]$RobotName,
    [Parameter(Mandatory)][securestring]$RobotToken,
    [string]$Prefix = 'MatrixCode.'
)
$ErrorActionPreference = 'Stop'
$uri = [uri]$Source
if (-not $uri.IsLoopback -or $uri.Scheme -notin @('http', 'https') -or $uri.UserInfo -or $uri.Query -or $uri.Fragment) { throw 'Only a local loopback NuGet feed is allowed.' }
if ($Prefix -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$' -or $Prefix.Length -gt 60) { throw 'Use a registered package prefix of at most 60 characters.' }
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$dll = Join-Path $repo 'src\modules\EmPoriumHouse.NuPak\EmPoriumHouse.NuPak.Models\bin\Debug\net10.0\EmPoriumHouse.NuPak.Models.dll'
if (-not (Test-Path -LiteralPath $dll)) { throw 'Build the backend first.' }
$taskRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('nupak-live-' + [guid]::NewGuid().ToString('N'))
$id = $Prefix + 'Smoke' + [guid]::NewGuid().ToString('N')
$priorApiKey = $env:NUGET_API_KEY
$priorCredentials = $env:NuGetPackageSourceCredentials_EmPoriumHouse
$credential = [pscredential]::new($RobotName, $RobotToken)
New-Item -ItemType Directory -Path $taskRoot | Out-Null
try {
    $env:NUGET_API_KEY = $credential.GetNetworkCredential().Password
    $env:NuGetPackageSourceCredentials_EmPoriumHouse = "Username=$RobotName;Password=$env:NUGET_API_KEY;ValidAuthenticationTypes=Basic"
    $packagePath = Join-Path $taskRoot "$id.1.0.0.nupkg"
    $zip = [System.IO.Compression.ZipFile]::Open($packagePath, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        $writer = [System.IO.StreamWriter]::new($zip.CreateEntry('smoke.nuspec').Open())
        try { $writer.Write("<package><metadata><id>$id</id><version>1.0.0</version><authors>Smoke</authors><description>Local NuGet verification</description></metadata></package>") } finally { $writer.Dispose() }
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $dll, 'lib/net10.0/EmPoriumHouse.NuPak.Models.dll') | Out-Null
    } finally { $zip.Dispose() }
    $escapedSource = [System.Security.SecurityElement]::Escape($Source)
    $escapedPattern = [System.Security.SecurityElement]::Escape($Prefix + '*')
    $config = Join-Path $taskRoot 'nuget.config'
    Set-Content -LiteralPath $config -Encoding utf8 -Value "<configuration><packageSources><clear/><add key=`"EmPoriumHouse`" value=`"$escapedSource`" allowInsecureConnections=`"true`"/></packageSources><packageSourceMapping><packageSource key=`"EmPoriumHouse`"><package pattern=`"$escapedPattern`"/></packageSource></packageSourceMapping></configuration>"
    $project = Join-Path $taskRoot 'restore.csproj'
    Set-Content -LiteralPath $project -Encoding utf8 -Value "<Project Sdk=`"Microsoft.NET.Sdk`"><PropertyGroup><TargetFramework>net10.0</TargetFramework><NuGetAudit>false</NuGetAudit></PropertyGroup><ItemGroup><PackageReference Include=`"$id`" Version=`"1.0.0`"/></ItemGroup></Project>"
    Push-Location -LiteralPath $taskRoot
    try {
        dotnet nuget push $packagePath --source $Source --allow-insecure-connections
        if ($LASTEXITCODE -ne 0) { throw 'Push failed.' }
        dotnet package search $id --configfile $config --format json
        if ($LASTEXITCODE -ne 0) { throw 'Search failed.' }
        dotnet restore $project --configfile $config --packages (Join-Path $taskRoot 'packages') --no-cache --force
        if ($LASTEXITCODE -ne 0) { throw 'Restore failed.' }
        dotnet nuget delete $id 1.0.0 --source $Source --non-interactive
        if ($LASTEXITCODE -ne 0) { throw 'Delete failed.' }
        Write-Output "PASS push/search/restore/delete. Package $id 1.0.0 is now in the recycle bin; purge it in NuGet Manager. Scratch output: $taskRoot"
    } finally { Pop-Location }
} finally {
    $env:NUGET_API_KEY = $priorApiKey
    $env:NuGetPackageSourceCredentials_EmPoriumHouse = $priorCredentials
}
