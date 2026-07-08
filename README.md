# ODIN pipeline starter kit

Everything needed to run the ODIN application — a browser-based tool for
registering, launching, and tracking sequencing (Nanopore) and qPCR (Biomeme)
workflows, with results visualised in OpenEnlighten. This repository provides a
ready-to-run Docker Compose stack, deployment profiles and seed files, with
anonymised demo data to try it out. To run ODIN on your own data, start from
here and follow **[FIELD_DEPLOYMENT.md](FIELD_DEPLOYMENT.md)**.

> ⚠️ **Security:** ODIN mounts the host Docker socket, so access to the app is
> effectively root on the host. This demo protects it two ways: it binds the UI
> to **loopback (`127.0.0.1`)** so only this machine can reach it, and
> `setup.sh` sets a **login** that you'll be prompted for. Keep both, and do
> not expose it to an untrusted network. Review **[SECURITY.md](SECURITY.md)**
> before deploying anywhere real.

The application runs from release images built from its public source,
[ODIN-consortium/odin-pipeline-web-application](https://github.com/ODIN-consortium/odin-pipeline-web-application),
and published on the GitHub Container Registry
([`ghcr.io/odin-consortium/odin-pipeline-api`](https://github.com/orgs/ODIN-consortium/packages/container/package/odin-pipeline-api),
[`ghcr.io/odin-consortium/odin-pipeline-ui`](https://github.com/orgs/ODIN-consortium/packages/container/package/odin-pipeline-ui)).
`docker-compose.yml` pins every image by digest, so a given demo release always runs exactly
the same containers. The Enlighten viewer images come from Docker Hub (`norceresearch1/enlweb-api`,
`norceresearch1/enlweb-client`), also pinned by digest.

## Quick start

Runs under **Linux or WSL2** (on Windows: Docker Desktop with the WSL2
backend). All commands below go in a Linux/WSL2 shell — not CMD or PowerShell.

**1. Prerequisites**

- [Docker](https://docs.docker.com/get-docker/) (Desktop on Windows/macOS,
  Engine on Linux). Allow **4+ CPUs** in Docker Desktop
  (Settings → Resources) — some pipelines require it.
  Rootless [Podman](https://podman.io/) also works — see
  [Podman (experimental)](#podman-experimental) below.
- [Git LFS](https://git-lfs.com/): install the package for your OS, then run
  `git lfs install` once. Both steps, in that order — the demo's FASTQ and
  database files live in LFS.

**2. Clone**

```bash
git clone https://github.com/ODIN-consortium/odin-pipeline-starter-kit.git
cd odin-pipeline-starter-kit
```

**3. Set up**

```bash
bash setup.sh
```

Generates `.env` (paths + a login it prints — note it down), pulls any
missing LFS data, and auto-detects corporate CA certificates.

**4. Start**

```bash
docker compose up -d
```

Open **http://localhost** and log in with the credentials from step 3.

> The login is optional: clearing `ODIN_AUTH_USER` / `ODIN_AUTH_PASSWORD` in
> `.env` (and restarting the stack) disables it entirely. Only do this on a
> machine where loopback-only access is protection enough — see
> [SECURITY.md](SECURITY.md).

**5. Explore**

- **Dashboard** → scan: the Nanopore demo runs and Biomeme folders appear.
- **Register & launch** a run — the first pipeline launch downloads its tool
  containers (a few minutes, once).
- Results open in **Enlighten** at http://localhost:8080.

What the demo data contains, and how seeding works: **[DEMO_DATA.md](DEMO_DATA.md)**.

## Reset

```bash
docker compose down -v && docker compose up -d
```

Wipes the app database (`-v`); the demo metadata is restored automatically on
next start.

## Podman (experimental)

The stack runs under rootless Podman — full pipeline runs validated — but
Docker remains the supported path. For the especially interested, after the
one-time host setup in [TROUBLESHOOTING.md](TROUBLESHOOTING.md):

```bash
ODIN_CONTAINER_SOCK=/run/user/$(id -u)/podman/podman.sock ODIN_UI_PORT=8099 podman-compose up -d
```

(then http://localhost:8099). If Podman is the **only** engine on the
machine, the two variables can live in `.env` instead — but don't put them
there on a machine that also runs Docker: a Docker-started stack would then
mount the wrong socket.

## When something is off

Corporate networks (SSL inspection), datasets on Windows/network drives,
LFS pointer files, CPU limits, cleanup — all in
**[TROUBLESHOOTING.md](TROUBLESHOOTING.md)**.

Deploying for real field work (offline operation, external data drives,
metadata workflow): **[FIELD_DEPLOYMENT.md](FIELD_DEPLOYMENT.md)**.

## Citation

If you use this starter kit or its demo data, please cite its archived release on Zenodo.

## License

Licensed under the GNU Affero General Public License v3.0 (AGPL-3.0). See
[LICENSE](LICENSE) for the full text.
