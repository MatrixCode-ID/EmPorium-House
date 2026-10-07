# Maintained tests

CI runs the release version and release-note checks from the repository root:

```powershell
pwsh -NoLogo -NoProfile -File tests/workflows/release-rules.ps1
```

Local fixtures are created in `../.artefacts/EmPorium/scripts/release-rules-tests/`.
CI supplies its runner temporary directory through `-FixtureDirectory`.

Temporary smoke and render harnesses belong in
`../.artefacts/EmPorium/scripts/<name>-smoke/` or `<name>-render/` and are kept
outside Git. Their references to this repository must be relative.
`scripts/` contains user tools and their supporting resources.
