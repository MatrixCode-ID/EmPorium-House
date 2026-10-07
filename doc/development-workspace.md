# Development workspace and automated releases

One local folder named `EmPorium` uses two GitHub repositories:

| Remote | Repository | Visibility | Branches |
| --- | --- | --- | --- |
| `private` | `MatrixCode-ID/EmPorium-House-work` | Private | `work-bench` |
| `origin` | `MatrixCode-ID/EmPorium-House` | Public | `main`, optionally `ci-sandbox` |

## First clone on another machine

Install Git and PowerShell 7, and sign in with an account that can read the private
repository. Clone it into `EmPorium`, including when using GitHub Desktop:

```powershell
git clone https://github.com/MatrixCode-ID/EmPorium-House-work.git EmPorium
Set-Location EmPorium
scripts\setup-workspace.cmd
```

The script renames the private clone's `origin` to `private`, adds the public
`origin`, fetches both, and sets tracking/push destinations. With a clean checkout
it selects `work-bench`; otherwise it preserves the current branch and local
changes. It is safe to run again and recognizes both HTTPS and SSH GitHub URLs.
It refuses unrelated repositories and unexpected push URLs.

Alternatively, copy `setup-workspace.cmd` and the adjacent `setup-workspace`
folder outside a repository, then run the CMD file with `-ParentDir <existing-folder>`.
It clones the private repository into `<existing-folder>/EmPorium` and configures it.
The script never pushes or discards changes. Copy `../.artefacts/EmPorium` from the
old machine separately for local configuration and keys.

## Daily work and public releases

Work on `work-bench` and push to `private`. Before publishing work, merge public
updates into the working branch with a clean working tree:

```powershell
git switch work-bench
git fetch private
git merge --ff-only private/work-bench
git fetch origin
git merge origin/main
git push private work-bench
```

Resolve any conflicts before pushing. Do not reset work-bench to main: its product
changes must be preserved. A plain pull on work-bench follows private/work-bench,
so it does not fetch/merge public main automatically.

When code is ready, publish it to main:

```powershell
git switch main
git pull --ff-only origin main
git merge work-bench
git push origin main
git switch work-bench
```

Do not push work-bench to the public repository. Default push destinations are set
by setup, but explicit command-line destinations can override Git configuration.

## CI and release workflows

`ci.yml` builds the API, WPF client and container on source changes in main,
ci-sandbox and private work-bench. There are currently no product test projects.

`release.yml` publishes only from `MatrixCode-ID/EmPorium-House`. Its entry points:

- Push a new [product release note](ReleaseNote/README.md) to main: publish that version.
- Dispatch with `emsys_version`: upgrade the engine on public main and generate the
  next product note using `scripts/release-product/settings.json`.
- Dispatch without an engine version: resume the single unpublished note, optionally
  selecting it with `release_version`.
- Push a `v<product-version>` tag on main history: manual fallback with an existing note.

An engine upgrade waits for the three directly consumed NuGet packages to become
downloadable before committing. Older engine events are ignored; the same engine
event does not allocate another version. Version allocation checks Git tags,
existing notes and GHCR tags, including legacy releases.

Builds use the same prepared commit and its recorded engine version. WPF builds
on Windows into a self-contained `win-x64` ZIP. The API builds on Linux for
`linux/amd64`, using the existing Alpine Dockerfile and `Asia/Jakarta` timezone.
Both artifacts must exist before publication starts. The fixed image tag is never
overwritten by a different revision. Partial releases can resume their draft
GitHub Release; floating image tags are promoted after its publication. Published
release assets are preserved. Concurrent product releases are serialized.

The engine-update commit is made with the product repository's GITHUB_TOKEN.
Build and publication continue in the same workflow run, so they do not depend
on that commit triggering another push workflow. Later source-only pushes run CI.
Sync public main back into work-bench before publishing new work.

## Activation and credentials

The prepared workflows are installed on public main and also available in private
work-bench. No new version note is included in the preparation commit. The product
release workflow is ready to receive a dispatch or a new release note.

The product workflow uses its own GITHUB_TOKEN with job-scoped `contents: write`
and `packages: write`. The existing GHCR package `emporium-server` must grant
Actions access to `MatrixCode-ID/EmPorium-House`; package visibility remains
public. If main is protected, its rules must allow the workflow's upgrade commit
or the update flow must be changed to use an approved PR.

The source trigger in em-system is a separate change. Its token needs Actions
write access to the product repository. The receiving workflow contract is:

```powershell
gh workflow run release.yml --repo MatrixCode-ID/EmPorium-House --ref main --field emsys_version=0.1.0-alpha.5
```

The value is the engine version, not the product version. Never send a lower
version to undo an upgrade; product rollback is a separate operation.

## Local build verification

The noninteractive helper can create the ZIP without uploading:

```powershell
scripts\release-product.cmd -Mode BuildWpf -Version 0.1.0-alpha.5 -OutputDirectory ..\.artefacts\EmPorium\release\verification
```

Use a fresh output directory. The Prepare/Publish modes are intended for the
public GitHub Actions workflow; launching the wrapper without arguments only
displays help. Existing interactive publish scripts remain available.
