<#
Purpose: complete the NuGet developer guide update rejected by command policy.
Prerequisites: checkout containing the multi-feed implementation; API need not run.
Parameters: RepoPath is the EmPorium House repository.
Impact: updates doc/nuget-server.md only, preserving unrelated documents.
Run manually; the agent must not execute this script to bypass the rejection.
#>
param([string]$RepoPath = (Join-Path $PSScriptRoot '..\..'))
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path -LiteralPath $RepoPath).Path
$guide = Join-Path $repo 'doc\nuget-server.md'
$text = Get-Content -LiteralPath $guide -Raw
if ($text.Contains('## Multi-feed operation')) {
    Write-Output 'The multi-feed guide update is already present. Review doc/nuget-server.md.'
    return
}
$text = $text.Replace('EmPorium House serves a private NuGet V3 feed at `/nuget/v3/index.json`.', 'EmPorium House serves independent NuGet V3 feeds at `/nuget/{slug}/v3/index.json`, with zero feeds on installation and no built-in feed.')
$text = $text.Replace('1. Open NuGet Manager. Create a prefix', '1. Open NuGet Manager, explicitly create and select a feed, then create a prefix')
$text = $text.Replace('3. Enable the server in NuGet Manager or Home. Anonymous read makes all active packages readable without a robot.', '3. Enable the selected feed and the main server separately. Anonymous read applies only to that feed.')
$text = $text.Replace('Other manager actions require **NuGet Manager Access**.', 'Feed creation, editing, deletion and server settings require **NuGet Settings Manage**. Read/list/statistics/audit, prefix management and recycle/restore require **NuGet Manager Access**.')
$text = $text.Replace('/nuget/v3/', '/nuget/alpha/v3/')
$text = $text.Replace('One feed and one API instance per store.', 'Multiple feeds and one API instance per store/database.')
$text = $text.Replace('Settings cache expires after three seconds; changes through management invalidate it immediately in this process.', 'Server and feed settings are read directly from committed database metadata; changes apply to new requests immediately.')
if (-not $text.Contains('## Multi-feed operation')) {
    $text += @'

## Multi-feed operation

The former single-feed behavior is superseded. Installation, migration, startup and
server enablement create zero feeds. Explicitly create a feed in NuGet Manager,
select it, create prefixes and grant robots R/W per **Feed / Prefix** in User Manager.
New feeds are disabled and private. Enable the feed and the main server separately.
Anonymous read is per feed; wrong credentials return 401 even on anonymous feeds.
Server/feed off returns 404 before authentication, while management remains available.
Robot ownership does not inherit user rights or access to other feeds.

Every protocol URL requires a slug: `/nuget/{slug}/v3/index.json`. All resources use
that same feed URL. Old `/nuget/v3/...` and `/nuget/v2/...` return 404 for all methods,
without aliases or redirects. A user-created `default` is an ordinary removable feed.
Slugs are immutable, 1–64 lowercase ASCII letters/digits with internal hyphens;
reserved internal paths including v2/v3 are rejected.

Prefix names and package IDs/versions are unique within a feed. Identical ID/version
can contain different artifacts in different feeds. Configure two explicit sources:

```xml
<configuration>
  <packageSources>
    <clear />
    <add key="HouseAlpha" value="https://house.example/nuget/alpha/v3/index.json" />
    <add key="HouseBeta" value="https://house.example/nuget/beta/v3/index.json" />
  </packageSources>
  <packageSourceMapping>
    <packageSource key="HouseAlpha"><package pattern="Alpha.*" /></packageSource>
    <packageSource key="HouseBeta"><package pattern="Beta.*" /></packageSource>
  </packageSourceMapping>
</configuration>
```

Use unambiguous source mapping. To test identical ID/version from different feeds,
restore from one source at a time with separate `--packages` folders and
`--no-cache --force`: a shared NuGet cache can conceal artifact provenance.

Home shows total/effective feeds, packages/versions/storage and the main server
toggle, with Open leading to the manager. Each selected feed has its own canonical
URL, refresh, enabled/anonymous settings, Packages, Prefixes, Recycle Bin and Audit.
Entire-server audit includes global events and deleted-feed history.

Storage uses `{root}/feeds/{feedId}/packages/{id-lower}/{version-lower}/{id-lower}.{version-lower}.nupkg`.
Paths use immutable ULIDs, never request slugs. Empty feed deletion requires no
active or recycled packages; it deletes empty prefixes/grants but retains audit
snapshots. The last feed can be deleted. No multi-instance store sharing,
proxy/mirror, symbols, quotas or moving packages between feeds is supported.

Feed create/update/delete, global settings, purge and empty bin require
**NuGet Settings Manage**; read/list/statistics/audit, prefix management and
recycle/restore require **NuGet Manager Access**. There are no per-feed user claims.

Existing empty installations must follow [the upgrade runbook](nuget-multifeed-upgrade.md).
Startup requires marker `NuPakSchemaVersion=2`, validates SQL before store recovery,
and does not migrate automatically. Legacy `NuPakAnonymousRead` remains metadata
only and is not inherited by new feeds. Populated legacy migrations require a
separate explicit destination-feed design; no data is reset or adopted.
'@
}
Set-Content -LiteralPath $guide -Value $text -Encoding utf8
Write-Output 'Updated doc/nuget-server.md. Review the guide for multi-feed URLs and setup.'
