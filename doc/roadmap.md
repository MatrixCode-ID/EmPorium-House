# EmPorium House roadmap

EmPorium House is a self-hosted developer infrastructure platform. This roadmap lists what is planned and in what order. It is a direction, not a promise: there are no dates, the order may change as needs become clear, and nothing here is released yet.

**Goal:** one self-hosted place for the infrastructure a small development team depends on (artifacts, containers, releases, logs, secrets) so it runs on your own hardware, with one sign-in and one desktop client.

## How the platform grows

These rules apply to every phase:

- **Every feature is a module.** A module is switched on or off in the host with one registration line, and (where it makes sense) with a runtime toggle, so a team that only needs one feature does not carry the rest.
- **One identity model.** Users and robots (machine accounts) come from the em-system engine. Modules grant rights to robots per resource instead of inventing their own credentials.
- **Engine versus product.** Generic building blocks (authentication, storage, host shell, UI core) live in [em-system](https://github.com/MatrixCode-ID/em-system). Product features live here.
- **A module is done when it has:** its table script, a server API, a desktop screen with a dashboard card on Home, automated checks for the server side, a render check for the screen in light and dark themes, and a setup guide in `doc/`.

## Status at a glance

| Phase | Theme | Status |
| --- | --- | --- |
| 0 | Foundation: CDN, container registry, NuGet server | Built, early |
| 1 | Artifact depth: caching, symbols, registry housekeeping | Planned |
| 2 | Container hosts: connect to Docker and watch it | Planned |
| 3 | Releases and deployment | Planned |
| 4 | Observability: logs, errors, uptime | Planned |
| 5 | Configuration and security: secrets, certificates | Planned |
| 6 | Host agent for machines behind NAT | Planned |
| 7 | More package ecosystems | Planned |
| 8 | Everyday developer utilities | Planned |
| - | Git hosting, CI build runner | Open question |

## Phase 0: Foundation

Built and being hardened.

- Server host and WPF desktop client with a Home screen of module cards.
- **CDN** for static files, with size limits and runtime settings.
- **Container registry** (OCI distribution API) with per-root robot access and a manager screen.
- **NuGet server** (V3 feed) with per-prefix robot permissions, runtime on/off, a recycle bin and audit.
- Robot accounts and rights through the engine's User Manager.

Remaining before this phase counts as finished: end-to-end checks against a real server (real `docker push/pull`, real `dotnet nuget push/restore`), continuous integration, and a first tagged release.

## Phase 1: Artifact depth

Make the registry and NuGet server more useful day to day.

- **Pull-through cache.** The registry and NuGet server keep a copy of what is first pulled from Docker Hub and nuget.org. Less bandwidth, works offline, and avoids public pull limits.
- **Symbol server** for NuGet (`.snupkg` and PDB), so internal packages can be debugged with step-into.
- **Registry housekeeping:** garbage collection of unreferenced blobs, retention rules, quotas and an audit trail.
- **Vulnerability and SBOM reports** for images and packages (evaluate integrating an existing scanner instead of building one).

Done when: a clean machine can restore packages and pull base images through EmPorium House with no internet, and old images can be cleaned up safely.

## Phase 2: Container hosts

See and control containers on Docker hosts, starting with the simplest connection that works.

- **Direct connection** from the server to a Docker Engine over mutual TLS or an SSH tunnel. No agent is needed for hosts the server can reach.
- **Host list and inventory:** hosts, containers, images, state and health.
- **Live metrics:** CPU, memory, network and disk per container, and host-level CPU, memory, disk and temperature where available. Shown as gauges on cards with their own refresh.
- **Actions** limited to an allowlist: start, stop, restart, logs, pull. Destructive actions need a separate permission.
- **Compatibility checks** for Podman (Docker-compatible API) and for NAS systems such as TrueNAS, which may be better served by their own management API than by raw Docker.
- **Setup guide** for exposing a Docker host safely (certificates, firewall, optional socket proxy).

Done when: an operator can watch resource usage of containers on at least two hosts and restart a container from the desktop client, with every action audited.

## Phase 3: Releases and deployment

- **Release and update server** for your own applications: versions, channels (stable and beta), rollback, and a feed the existing launcher and updater can consume.
- **Deployment manager** built on Phase 2: choose an image from the registry, deploy it to a host, keep history, roll back.

Done when: publishing a new application version and deploying a container image to a host are both a few clicks, reversible, and recorded.

## Phase 4: Observability

- **Log server:** collect, search and retain structured logs.
- **Error and crash tracking:** desktop and server apps report exceptions, grouped into issues.
- **Metric history** for hosts and containers (Phase 2 only shows the current value).
- **Uptime monitoring and a status page,** with notifications when something stops responding.

Done when: a failing service is noticed and explained from one place without logging in to the machine.

## Phase 5: Configuration and security

- **Secret vault** with per-robot access and an audit trail. Plain secrets never appear in the settings store or in logs.
- **Configuration store and feature flags** per environment.
- **Internal certificate authority:** issue, renew and revoke client certificates, which is what Phase 2 mutual TLS needs.
- **SSH key management** for hosts.

For a small team, integrating an existing tool may be wiser than building each of these; that decision is made when the phase starts.

## Phase 6: Host agent

For machines the server cannot reach (home networks, NAT, firewalls).

- A small **Linux agent** that connects outbound to the server, so no Docker or management port is opened on the host.
- Sends inventory, metrics and events; receives commands from a queue, or a desired state to converge to.
- Only allowlisted operations are executed. The agent is a robot with minimal rights.
- Runs as a systemd service. Native AOT is a goal if the agent API stays small and its serialization is source-generated.

Done when: a host behind NAT shows up in the host list and behaves like a directly connected one.

## Phase 7: More package ecosystems

- npm, PyPI, Maven and generic versioned artifacts.
- Helm charts and other OCI artifacts through the existing registry.

Each ecosystem is its own optional module. Order follows demand.

## Phase 8: Everyday developer utilities

Small, independent modules:

- SMTP catcher for development mail.
- Webhook inspector and relay.
- Mock server.
- S3-compatible object storage.
- Database backup manager with retention and restore tests.
- Central scheduler for recurring jobs.
- Documentation portal and changelog generated from releases.

## Open questions

- **Git hosting:** build a native module, or integrate and manage an existing git server?
- **CI build runner:** valuable but large and easy to over-extend. It stays out of the plan until a concrete need appears.
- **Moving the registry** from the engine into an EmPorium House module.
- **Single sign-on across servers** depends on token-signing keys and has not been verified.
- **Package names and domain availability** for `emporium-house` have not been checked.

## Changing this roadmap

Open an issue to propose a module or a different order. Anything marked "Planned" can move, shrink, or be dropped.
