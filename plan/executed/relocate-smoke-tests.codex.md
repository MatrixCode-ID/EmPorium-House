# Keep smoke and render harnesses outside the repository

- Date: 2026-10-07
- Requested by the user: smoke tests belong in the artefacts directory beside the repositories; use relative paths; reserve `scripts/` for tools used by users.

## Work

1. Move temporary smoke/render harnesses and their generated files into `../.artefacts/EmPorium/scripts/`.
2. Replace machine-specific paths with paths relative to each harness and update documentation references.
3. Move maintained CI release-rule checks into `tests/workflows/` and update CI.
4. Record the permanent rule in both repositories' CLAUDE.md, preserving existing guidance.
5. Check paths, PowerShell/YAML syntax and maintained release rules; publish the EmPorium correction through work-bench and main.

## Verification

- Temporary host/login/render harnesses and the remaining NuGet smoke outputs moved outside Git into `../.artefacts/EmPorium/scripts/`.
- All four workspace/release harness defaults now resolve the repository relative to their own location.
- The render project reference resolves to the existing WPF project; moved PowerShell harnesses parse successfully.
- Maintained CI checks moved to `tests/workflows/release-rules.ps1`; CI path filters and invocation updated.
- 25 release-rule, 21 workspace, 18 Prepare and 13 Publish checks passed from the new relative paths.
- PowerShell syntax, actionlint and `git diff --check` passed.
- The historical GHCR login harness remains for manual execution as documented; relocation and syntax checking do not claim its previously blocked run succeeded.
- Permanent guidance recorded in EmPorium House and em-system; existing contents preserved. The unrelated em-system task file was left untouched.
