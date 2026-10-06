# EmPorium House API

`EmPoriumHouse.Api` hosts the em-system engine with the NuPak NuGet module.
It runs as a container from [compose.yml](compose.yml) and the Alpine
[Dockerfile](EmPoriumHouse.Api/Dockerfile). The SDK is installed only in the
build stage; the final image contains the ASP.NET Core 10 runtime, `tzdata`
and diagnostic tools (`ping`, `traceroute`, `nano`) and runs as UID 1654.

## Prerequisites

- Docker with Linux containers, Compose 2.24+ and BuildKit (current Docker
  Desktop provides both).
- Network access to nuget.org during the image build: the engine comes from the
  `EmSys.*` packages (version `EmSysVersion` in `Directory.Build.props`), so no
  em-system checkout is needed.
- An external database that already contains the engine core/registry schema
  and the NuPak version 2 schema. For an existing NuPak database, see
  [the engine upgrade runbook](../../../em-system/doc/engine-nupak-multifeed-upgrade.md). Compose does not
  run a database.

## Configuration

The API reads a single `emapi-config.json` (the engine's `EmApiConfig`; format
in [emapi-config.example.json](EmPoriumHouse.Api/emapi-config.example.json)).
It lives outside the repository in `..\.artefacts\EmPorium\config\`:

| File | Used by |
| --- | --- |
| `emapi-config.json` | `dotnet run` / IDE; the build copies it to the output. |
| `emapi-config.docker.json` | Compose; mounted read-only at `/run/secrets/emapi-config`. |

The container file differs only where the network differs: for SQL Server on
the Docker host use `host.docker.internal` with an explicit TCP port and SQL
authentication. Inside the container `localhost` is the container itself, and
Windows integrated authentication is not available. Relative storage paths
(`./data/...`) resolve to the `/app/data` volume.

Compose passes the file as a [secret](https://docs.docker.com/compose/how-tos/use-secrets/),
which outside Swarm is a read-only bind mount, and sets
`EM_API_CONFIG=/run/secrets/emapi-config`. On a Linux server the file must be
readable by UID 1654 (for example `chown root:1654` and `chmod 640`).

`.env` (copy from `.env.example`) holds Compose settings only. It is ignored by
Git and excluded from the image, as are `emapi-config*.json`, `*.local.json` and
`*.production.json`. Never commit real credentials.

| Variable | Default | Purpose |
| --- | --- | --- |
| `EM_API_CONFIG_FILE` | `../../../.artefacts/EmPorium/config/emapi-config.docker.json` | Host path of the container config, relative to `compose.yml` or absolute. |
| `EMPORIUM_API_PORT` | `5232` | Host port mapped to container port `8080`. |
| `EMPORIUM_API_BIND_ADDRESS` | `127.0.0.1` | Host address for the published port. |
| `ASPNETCORE_ENVIRONMENT` | `Development` | Use `Production` for deployments. |
| `BUILD_CONFIGURATION` | `Release` | `dotnet publish` configuration. |
| `TZ` | `Asia/Jakarta` | IANA timezone for the image build and container runtime. |

`EM_DB_CONNECTION_STRING`, `EM_DB_PROVIDER`, `EM_ADMIN_INITIAL_PASSWORD` and
`EM_DEBUG_TOKEN` are still read when present (for example from a secret
manager) and override the matching file values. Leave them out of `.env` so the
config file stays the single source.

## Run with Compose

From this directory:

```powershell
docker compose config --quiet
docker compose up --build -d
docker compose logs -f emporium-server
docker compose down
```

The API listens on `http://localhost:5232` and the image is tagged
`emporium-server:local`. After editing `.env`, use
`docker compose up -d --force-recreate`, because `restart` keeps the old
environment. Use `up --build -d` after code or Dockerfile changes.

`down` keeps the named volume `emporium-house-api_emporium-house-api-data`
mounted at `/app/data`, which holds the CDN, registry and NuGet files.
`down --volumes` deletes it. Back up the database and this volume together.

### Direct docker build

```powershell
# From the repository root.
docker build --file src/backend/EmPoriumHouse.Api/Dockerfile --build-arg TZ=Asia/Jakarta --tag emporium-server:local .
```

Without `--build-arg TZ`, the image defaults to `UTC`. You can override the
timezone at runtime with `--env TZ=...`. Timestamps that are explicitly stored
or logged in UTC remain in UTC.

### Run with docker run and minimal Compose

A `docker run` command with every parameter explained, a standalone minimal
`compose.yml` for a prebuilt image, the variable list, storage layout and
troubleshooting are in [Container setup](../../doc/setup-container.md).

## Upload to GitHub Container Registry

Run the interactive publisher from any working directory:

```cmd
scripts\upload-api-ghcr.cmd
```

PowerShell helpers are in `scripts/upload-api-ghcr/`. Before any prompts or
login, the script checks that the Docker API responds and uses Linux containers.
If unavailable, it stops with instructions to start Docker Desktop or check the
Docker context/`DOCKER_HOST`. It then checks saved Docker GHCR credentials and
validates them against GitHub. If login is
missing or expired, it asks for your GitHub username and a hidden classic PAT
with `read:packages` and `write:packages`. Docker saves the login using its
configured credential store. The same login is used for reading private tags
and pushing, so no manual login or token environment variable is required.
The script then asks for the
GHCR namespace (default `matrixcode-id`) and channel (`release`, `beta`, `alpha`,
`prealpha`; default `prealpha`). It reads published GHCR tags, displays the
previous channel version, and asks for a target version.
Enter keeps that version; no history defaults to `0.1.0`.

The channel menu stays in the CLI: use Up/Down arrows or keys 1-4 to select,
then Enter to confirm. Enter immediately selects `prealpha`; Esc cancels.
With redirected input/output, a text prompt accepts a number or channel name.

For all four channels, the build number increases for the same target version,
or starts at 1 for a new version/channel. For example, `0.1.0-prealpha.2` becomes
`0.1.0-prealpha.3`. Release uses the same format, for example `0.1.0-release.1`, and also increments
the build number when the target version is unchanged.
Only GHCR history advances the build counter. For example, if GHCR has
`0.1.0-prealpha.1` and a previous unpublished local build has `.2`, the next run
removes the local `.2` tag and rebuilds `.2` from the current source. It also
removes the matching local GHCR-qualified tag, if present. Other version tags
are kept. Removal uses no force and does not delete containers; if Docker
refuses removal, the script stops.
See [the engine naming convention](../../../em-system/doc/konvensi-penamaan-container.md).

The script builds Release into local Docker as `emporium-server:<version-tag>`,
sets the assembly and image version, and verifies the image exists. Only then
it asks whether to push to GHCR; Enter means **no**. Declining preserves the local
image. No containers are started or replaced.

An approved push uploads the version tag first, then its floating channel tag.
Release additionally updates `latest`, `MAJOR.MINOR` and `MAJOR`; prerelease
channels never update `latest`. Remote version tags are checked again before
push to avoid overwriting existing versions. The registry does not provide an
atomic reservation, so avoid simultaneous publishers for the same version.

Tokens are passed to Docker through stdin and are not written to project files
or command arguments. The script respects `DOCKER_CONFIG`, per-registry
`credHelpers`, and the default `credsStore`. `GHCR_USERNAME` can prefill the
username prompt. If registry history cannot be verified, the script stops
instead of guessing a build number.

Optional shell configuration: `GHCR_NAMESPACE` (lowercase) and `TZ` (default
`Asia/Jakarta`). Compose `.env` is not loaded.
Docker must be running in Linux mode with BuildKit available.
Use `scripts\upload-api-ghcr.cmd -Help` for usage.
On failure, the CMD launcher preserves the exit code and waits for a keypress
so errors remain visible when launched by double-clicking. Runtime errors also
show the script filename and line number.

See [GitHub's Container registry documentation](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)
for authentication, organization access and package visibility settings.

## Run from an IDE

`EmPoriumHouse.Api.slnx` includes a Compose project (`compose.dcproj`) for
Visual Studio and a shared Rider run configuration, **EmPoriumHouse.Api
Compose** (Compose project name `emporium-server`). With Docker running, select
that configuration and click **Run**. Application output appears in
**Services** (`Alt+8`) under the container's **Log** tab. Rider fast mode is
disabled so the complete multi-repository publish runs inside Docker.

Debugging inside the Alpine container is not supported yet: Rider's Linux
debugger worker targets glibc and fails to start on Alpine. Use **Run**, or
run the API outside Docker with `dotnet run` and `emapi-config.json`
in `..\.artefacts\EmPorium\config\` (see `emapi-config.example.json`).

## Public deployment

- Set `ASPNETCORE_ENVIRONMENT=Production`, keep `debugTokens` empty unless you
  need it, and point `EM_API_CONFIG_FILE` to the server's config file (outside
  the checkout, readable by UID 1654).
- The image serves plain HTTP only. Terminate TLS at a reverse proxy, and keep
  the bind address at `127.0.0.1` when the proxy runs on the same host.
- Use a dedicated database login (not `sa`), a validated server certificate,
  and a strong initial admin password. List the reverse proxy in
  `http.proxy.trusted` so client addresses are logged correctly.

NuGet prerequisites: run em-system `doc/sqlscript/mssql/sets/NuPak.sql` (schema version 2). See em-system `doc/engine-nupak.md`. Engine host uses managed settings; EmPorium House uses `AddNuPak(config.Storage.NuPakPath, config.Storage.NuPakMaxPackageMb)`.
