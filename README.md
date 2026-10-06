# EmPorium House

**Developer infrastructure platform.** *Self-hosted. Fully stocked.*

EmPorium House is a self-hosted developer infrastructure platform by **Matrix Code**: CDN, container registry, and NuGet server.

> **EmPorium House is an implementation of [em-system](https://github.com/MatrixCode-ID/em-system).**
> em-system is the engine; EmPorium House is a product built on top of it. Every feature you see here — CDN,
> container registry, NuGet server, publisher, user and robot management, authentication, storage, and the desktop
> client shell — is provided by the em-system engine (`Em.*` libraries). This repository only contains the hosts
> that switch those features on, the EmPorium House home screen and its cards, and the product's branding and
> configuration.

The project is in early development: the server container image is published on the `alpha` channel only. Licensed under [MIT](LICENSE).

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

## Requirements

- .NET SDK 10 (the WPF client needs Windows).
- Access to nuget.org for the engine packages (`EmSys.Api.Core`, `EmSys.Libs`, `EmSys.Ui.Wpf.Core`). Their version is the `EmSysVersion` property in [`Directory.Build.props`](Directory.Build.props); no em-system checkout is needed.
- A SQL Server database prepared with the em-system scripts in `doc/sqlscript/mssql`: `sets/` first, then `tables/` in numeric order (core `010-core.sql`, container registry `030-registry.sql`, NuGet server `040-nupak.sql`), then `views/`. EmPorium House can share the same database as an em-system server, so both see the same users and credentials.

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

**1. Prepare the config file.** Copy [`emapi-config.example.json`](src/backend/EmPoriumHouse.Api/emapi-config.example.json) to `emapi-config.docker.json` next to your compose file and fill in `database.connectionString` and `admin.initialPassword`. Inside a container `localhost` is the container itself, so for SQL Server on the Docker host use `Server=host.docker.internal,1433` with SQL authentication (Windows authentication is not available on Linux containers). Keep this file out of Git.

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

## Engine documentation

The features are documented in em-system:

- [CDN storage](https://github.com/MatrixCode-ID/em-system/blob/main/doc/engine/engine-cdn-storage.md)
- [Container registry](https://github.com/MatrixCode-ID/em-system/blob/main/doc/engine/engine-registry.md)
- [NuGet server (NuPak)](https://github.com/MatrixCode-ID/em-system/blob/main/doc/engine/engine-nupak.md)
- [Storage settings](https://github.com/MatrixCode-ID/em-system/blob/main/doc/engine/engine-storage-settings.md)
- [Robots](https://github.com/MatrixCode-ID/em-system/blob/main/doc/engine/engine-robots.md)
- [WPF publisher](https://github.com/MatrixCode-ID/em-system/blob/main/doc/engine/engine-publish.md)
- [Login and branding](https://github.com/MatrixCode-ID/em-system/blob/main/doc/engine/engine-login-branding.md)

What is planned next is in the [roadmap](doc/roadmap.md).
