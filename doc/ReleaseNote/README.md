# Product release notes

Each new EmPorium House version has one English release note in this folder:
`<MAJOR.MINOR.PATCH>-<prealpha|alpha|beta|release>.<N>.md`, without the `v` prefix.
Use the same version for the GitHub Release, desktop ZIP and fixed GHCR image tag.
Published release notes are immutable. Existing releases predating this workflow
do not need to be rewritten or backfilled.

Start with `# EmPorium House <version>`, then `## Summary` with a short paragraph.
Add `## New features`, `## Fixes`, `## Breaking changes`, and `## Upgrade notes`
when relevant. These notes become the GitHub Release description.

Raise `<Version>` in `Directory.Build.props` to the same version in the change that adds the
note, so local builds of the API and the desktop client carry it. CI builds with the newest note
version (`-p:Version`, and `APP_VERSION` for the image) and warns when `Directory.Build.props` lags
behind; `release.yml` always passes the release version. An engine update raises `<Version>` itself.

Merge one unpublished version into public `main` when ready to release.
`release.yml` builds both products before publishing. Source-only merges run CI;
they do not reserve a version or publish a release.

Engine updates are automatic. After em-system publishes a new EmSys version,
its `publish-nuget.yml` dispatches `release.yml` here with `emsys_version`
(needs the `PRODUCT_DISPATCH_TOKEN` secret in em-system). As a fallback,
`release.yml` also runs once a day (01:17 UTC) and upgrades when nuget.org has an EmSys
version, published for every referenced package, that is newer than main's
`EmSysVersion`. The scheduled run never publishes a pending product note on its
own. A manual dispatch with `emsys_version` still works.

An engine dispatch writes its own product release note and records the new
`EmSysVersion` in `Directory.Build.props`. The automatic channel and target
version live in `scripts/release-product/settings.json`. For example, product
`0.1.0-alpha.4` becomes `0.1.0-alpha.5` even if the new engine is `0.1.0-alpha.8`.
If exactly one unpublished product note is already on main, the upgrade joins
that release instead of reserving a second version.

To move from alpha to beta, change `automaticChannel` to `beta` and add
`0.1.0-beta.1.md` in the same product publication. Subsequent engine updates
allocate beta.2, beta.3, and so on. Prereleases update only their own image alias.
The release channel updates `release`, `latest`, `MAJOR.MINOR` and `MAJOR`.
