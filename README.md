# EmPorium House

[![Release](https://img.shields.io/github/v/release/MatrixCode-ID/EmPorium-House?include_prereleases&label=release)](https://github.com/MatrixCode-ID/EmPorium-House/releases)
[![License: MIT](https://img.shields.io/github/license/MatrixCode-ID/EmPorium-House)](LICENSE)

**Developer infrastructure platform.** *Self-hosted. Fully stocked.*

EmPorium House is a self-hosted developer infrastructure platform by **Matrix Code**: CDN, container registry, and NuGet server.

> **EmPorium House is an implementation of [em-system](https://github.com/MatrixCode-ID/em-system).**
> em-system is the engine; EmPorium House is a product built on top of it. Every feature you see here — CDN,
> container registry, NuGet server, publisher, user and robot management, authentication, storage, and the desktop
> client shell — is provided by the em-system engine (`Em.*` libraries). This repository only contains the hosts
> that switch those features on, the EmPorium House home screen and its cards, and the product's branding and
> configuration.

The project is in early development: the server container image and the desktop client are published on the `alpha` channel only. Licensed under [MIT](LICENSE).

## Download the desktop client

The Windows desktop client is a single `EmPoriumHouse.exe`, packaged as a zip on the [**Releases**](https://github.com/MatrixCode-ID/EmPorium-House/releases) page.

1. Open [Releases](https://github.com/MatrixCode-ID/EmPorium-House/releases) and download `EmPorium-House.<version>.zip` from the **Assets** list of the newest release.
2. Extract the zip and run `EmPoriumHouse.exe`. It is self-contained (Windows 10/11, x64): no .NET installation is needed.
3. Connect to an EmPorium House server: start one with [Run with Docker](#run-with-docker), then add its address (for example `http://localhost:5232`) with the connection settings button on the login screen, pick it in the server list, and sign in (for the first sign-in see [First admin sign-in](#first-admin-sign-in)).

Alpha builds are marked **Pre-release** and the executable is not code-signed yet, so Windows SmartScreen may warn about an unknown publisher: choose **More info → Run anyway** if you trust the download.

## What comes from where

| Part | Provided by |
| --- | --- |
| HTTP API host, authentication, authorization, users, roles, robots | em-system (`Em.Api.Core`, `Em.Libs`) |
| CDN, container registry (`/v2`), NuGet server (NuPak), storage settings | em-system (`Em.Api.Core`) |
| Desktop client shell, login, manager screens, publisher | em-system (`Em.Ui.Core`, `Em.Ui.Wpf.Core`) |
| Database schema scripts | em-system (`doc/sqlscript/mssql`) |
| Server host that enables the features (`builder.AddXxx()`) | this repository |
| Desktop host, home screen and home cards, branding | this repository |

Generic code belongs to the engine: fixes and new shared features are made in em-system, not here. The engine keeps its `Em.*` names; the `EmPoriumHouse` prefix is only used for this product's hosts.

The whole server host is a few lines on top of the engine:

```csharp
var app = EmApp.BuildApp(args, builder => {
   var config = EmPoriumHouse.Api.Helper.ApplyConfig(builder);
   builder.AddNuPak(config.Storage.NuPakPath, config.Storage.NuPakMaxPackageMb);
   builder.EnableCdn(config.Storage.CdnPath, config.Storage.CdnMaxFileSizeMb);
   builder.AddContainerRegistry(config.Storage.RegistryPath);
});
```

Each feature is one registration line, so you can switch any of them off by removing it.

## Layout

| Path | Contents |
| --- | --- |
| `src/backend/EmPoriumHouse.Api` | Server host (HTTP API, CDN, container registry, NuGet) |
| `src/frontend/EmPoriumHouse.Ui.Wpf` | Desktop client host (WPF) with the EmPorium House home screen (`Home/`) |
| `doc/` | Product documentation and [roadmap](doc/roadmap.md) |

Each host has its own solution: `src/backend/EmPoriumHouse.Api.slnx` and `src/frontend/EmPoriumHouse.Ui.Wpf.slnx`. The engine comes from the `EmSys.*` packages on nuget.org, not from projects in the solutions.

Maintainers: [development workspace, first-clone setup, CI and product releases](doc/development-workspace.md).

## Requirements

- .NET SDK 10 (the WPF client needs Windows).
- Access to nuget.org for the engine packages (`EmSys.Api.Core`, `EmSys.Libs`, `EmSys.Ui.Wpf.Core`). Their version is the `EmSysVersion` property in [`Directory.Build.props`](Directory.Build.props); no em-system checkout is needed.
- A SQL Server database with the em-system schema. The scripts live in em-system ([`doc/sqlscript/mssql`](https://github.com/MatrixCode-ID/em-system/tree/main/doc/sqlscript/mssql)); see [Prepare the database](#prepare-the-database). EmPorium House can share the same database as an em-system server, so both see the same users and credentials.

## Prepare the database

The server stores its data in SQL Server, and the schema is provided by the engine, not by this repository. Run the scripts from [`doc/sqlscript/mssql`](https://github.com/MatrixCode-ID/em-system/tree/main/doc/sqlscript/mssql) of em-system against an **empty** database, in this order:

| Order | Folder | Script |
| --- | --- | --- |
| 1 | `sets/` | `000-ulid.sql` (ULID functions used by the column defaults) |
| 2 | `tables/` | `010-core.sql` (users, roles, sessions, robots, logs, ...) |
| 3 | `tables/` | `030-registry.sql` (container registry) |
| 4 | `tables/` | `040-nupak.sql` (NuGet server) |
| 5 | `views/` | `vi_Address`, `vi_Comm`, `vi_Contact`, `vi_Role`, `vi_User`, `vi_UserCredential`, `vi_NuPakAudit`, `vi_NuPakFeed`, `vi_NuPakPackage`, `vi_NuPakPrefix`, `vi_NuPakVersion` (`.sql`) |

The other scripts in that folder (`020-approval.sql`, `100-business.sql`, `900-emtest.sql`, `vi_TestDoc.sql`, `vi_TestItem.sql`) belong to engine features EmPorium House does not use. The `updates/` folder only holds migrations for databases created with older scripts.

With `sqlcmd` (PowerShell; use `-U <login> -P <password>` instead of `-E` for SQL authentication):

```powershell
git clone --depth 1 https://github.com/MatrixCode-ID/em-system.git
Set-Location em-system\doc\sqlscript\mssql

$server = 'localhost'; $db = 'EmPorium'
sqlcmd -S $server -E -Q "CREATE DATABASE [$db]"

$views = 'vi_Address','vi_Comm','vi_Contact','vi_Role','vi_User','vi_UserCredential',
         'vi_NuPakAudit','vi_NuPakFeed','vi_NuPakPackage','vi_NuPakPrefix','vi_NuPakVersion' | ForEach-Object { "views\$_.sql" }
$scripts = @('sets\000-ulid.sql', 'tables\010-core.sql', 'tables\030-registry.sql', 'tables\040-nupak.sql') + $views
foreach ($script in $scripts) {
    sqlcmd -S $server -d $db -E -b -I -i $script
    if ($LASTEXITCODE -ne 0) { throw "Failed: $script" }
}
```

`-b` stops on the first error and `-I` enables quoted identifiers, which the scripts expect. Each view script ends with a test `SELECT`, so `sqlcmd` prints empty result tables; that output is expected. Then put the database in `database.connectionString` of your [config file](src/backend/EmPoriumHouse.Api/emapi-config.example.json); a server running in a container needs SQL authentication (see [Run with Docker](#run-with-docker)). Use a dedicated SQL login for the application rather than `sa`.

## Build and run

```powershell
dotnet build src/backend/EmPoriumHouse.Api.slnx
dotnet build src/frontend/EmPoriumHouse.Ui.Wpf.slnx
```

Copy [`emapi-config.example.json`](src/backend/EmPoriumHouse.Api/emapi-config.example.json) to `..\.artefacts\EmPorium\config\emapi-config.json` beside the repository (outside Git; override the folder with the MSBuild property `ArtefactsPath`) and fill in `database.connectionString` and `admin.initialPassword`. The file format is the engine's `EmApiConfig`, the same as em-system. The environment variables `EM_DB_CONNECTION_STRING`, `EM_DB_PROVIDER`, `EM_ADMIN_INITIAL_PASSWORD` and `EM_DEBUG_TOKEN` override the file; `EM_API_CONFIG` points to a file elsewhere.

```powershell
dotnet run --project src/backend/EmPoriumHouse.Api/EmPoriumHouse.Api.csproj
```

The API listens on `http://localhost:5232` by default (em-system's own `Em.Api` uses 5132, so both can run side by side).

## Run with Docker

The server is released as a container image, `ghcr.io/matrixcode-id/emporium-server`. You need Docker with Linux containers (Compose v2.24+) and the database described in [Requirements](#requirements).

**1. Prepare the config file.** Copy [`emapi-config.example.json`](src/backend/EmPoriumHouse.Api/emapi-config.example.json) to `emapi-config.docker.json` next to your compose file and fill in `database.connectionString` and `admin.initialPassword` (the password of the first admin account, see [First admin sign-in](#first-admin-sign-in)). Inside a container `localhost` is the container itself, so for SQL Server on the Docker host use `Server=host.docker.internal,1433` with SQL authentication (Windows authentication is not available on Linux containers). Keep this file out of Git.

**2. Docker Compose** (recommended). Save as `compose.yml`, then run `docker compose up -d`:

```yaml
name: emporium-server
services:
  emporium-server:
    image: ghcr.io/matrixcode-id/emporium-server:alpha
    container_name: emporium-server
    hostname: emporium-house-api
    init: true
    restart: unless-stopped
    environment:
      EM_API_CONFIG: /run/secrets/emapi-config
      ASPNETCORE_ENVIRONMENT: Production
      # Optional: overrides admin.initialPassword from the config file (see "First admin sign-in").
      # EM_ADMIN_INITIAL_PASSWORD: ${EM_ADMIN_INITIAL_PASSWORD}
    ports:
      - "127.0.0.1:5232:8080"
    extra_hosts:
      - "host.docker.internal:host-gateway"
    volumes:
      - emporium-house-api-data:/app/data
    secrets:
      - emapi-config
volumes:
  emporium-house-api-data:
secrets:
  emapi-config:
    file: ./emapi-config.docker.json
```

**Or `docker run`** (PowerShell; in a POSIX shell replace the trailing backticks with `\`):

```powershell
docker volume create emporium-house-api-data
docker run --detach --name emporium-server --hostname emporium-house-api --init `
  --env EM_API_CONFIG=/run/secrets/emapi-config `
  --env ASPNETCORE_ENVIRONMENT=Production `
  --mount "type=bind,source=$((Resolve-Path emapi-config.docker.json).Path),target=/run/secrets/emapi-config,readonly" `
  --mount type=volume,source=emporium-house-api-data,target=/app/data `
  --publish 127.0.0.1:5232:8080 `
  --add-host host.docker.internal:host-gateway `
  ghcr.io/matrixcode-id/emporium-server:alpha
```

The API is then available at `http://localhost:5232`; follow the logs with `docker logs -f emporium-server`. Keep the `--hostname` fixed and keep the data volume: it holds the CDN, registry and NuGet files, and `docker compose down --volumes` deletes it. The image serves plain HTTP only, so put a TLS reverse proxy in front for anything public.

Advanced settings (building the image from source, all environment variables and parameters, storage layout, public deployment, troubleshooting) are in [Container setup](doc/setup-container.md). The shared Rider run configuration is in the [backend README](src/backend/README.md).

## First admin sign-in

The server creates its built-in `admin` account the first time it starts against a new database. Its password comes from the `admin.initialPassword` setting, which you can give in either of two ways:

**In the config file** (what the steps above use): `"admin": { "initialPassword": "<password>" }` in `emapi-config.docker.json`. This works the same for Compose and `docker run`, because both mount that file.

**With an environment variable**, which overrides the file: `EM_ADMIN_INITIAL_PASSWORD`. An empty variable is ignored and the value from the file is used.

- *Docker Compose:* remove the `#` before `EM_ADMIN_INITIAL_PASSWORD` in the compose file above, and provide the value from your shell or from a `.env` file next to `compose.yml` (keep `.env` out of Git):

  ```powershell
  $env:EM_ADMIN_INITIAL_PASSWORD = Read-Host 'Initial admin password'
  docker compose up -d
  ```

- *`docker run`:* add one more `--env` line to the command above, taking the value from your shell so it does not end up in a script or in the shell history:

  ```powershell
  $env:EM_ADMIN_INITIAL_PASSWORD = Read-Host 'Initial admin password'
  docker run ... --env "EM_ADMIN_INITIAL_PASSWORD=$env:EM_ADMIN_INITIAL_PASSWORD" ... ghcr.io/matrixcode-id/emporium-server:alpha
  ```

Two things to know:

1. **The password is only used once.** It is stored as a hash in the database the first time the server starts. Changing the setting afterwards does not change the existing password, so choose a strong one before the first start.
2. **The `admin` account is disabled on a new database**, so that a password written in a config file is never an open door by itself. Start the server once (it creates its settings), then enable the account directly in the database:

   ```powershell
   sqlcmd -S localhost -d EmPorium -E -Q "UPDATE ta_Meta SET cMetaValue = 'True' WHERE cMetaKey = 'AdminUserEnable'"
   ```

   Now sign in as `admin` with the initial password. Once you have a regular account with the permissions you need, set the value back to `'False'`.

## Engine documentation

The features are documented in em-system ([all engine guides](https://github.com/MatrixCode-ID/em-system/blob/main/doc/engine/README.md)):

- [CDN](https://github.com/MatrixCode-ID/em-system/blob/main/doc/engine/engine-cdn-storage.md)
- [Container registry](https://github.com/MatrixCode-ID/em-system/blob/main/doc/engine/engine-registry.md)
- [NuGet server (NuPak)](https://github.com/MatrixCode-ID/em-system/blob/main/doc/engine/engine-nupak.md)
- [Storage settings](https://github.com/MatrixCode-ID/em-system/blob/main/doc/engine/engine-storage-settings.md)
- [Robot identities](https://github.com/MatrixCode-ID/em-system/blob/main/doc/engine/engine-robots.md)
- [Module protocol endpoints](https://github.com/MatrixCode-ID/em-system/blob/main/doc/engine/engine-public-endpoints.md)
- [Publish from WPF](https://github.com/MatrixCode-ID/em-system/blob/main/doc/engine/engine-publish.md)
- [Release Manager](https://github.com/MatrixCode-ID/em-system/blob/main/doc/engine/engine-release-manager.md)
- [Login branding](https://github.com/MatrixCode-ID/em-system/blob/main/doc/engine/engine-login-branding.md)

What is planned next is in the [roadmap](doc/roadmap.md).
