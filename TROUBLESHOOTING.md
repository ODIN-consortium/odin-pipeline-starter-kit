# Troubleshooting

Side-paths and fixes that are off the main [README](README.md) route.
Field-specific problems (offline operation, external drives) are in
[FIELD_DEPLOYMENT.md](FIELD_DEPLOYMENT.md) — see "When the stack won't
start in the field" for drive and mount failures.

## Corporate network (SSL inspection)

If your organisation intercepts HTTPS traffic, pipeline launches fail even
though the UI works. You need this section if you see any of:

- Nextflow: `WARN: Cannot read project manifest -- Cause: (certificate_unknown) PKIX path building failed` followed by `Cannot find nf-core/...`
- curl (in the pipeline log): `curl: (60) SSL certificate problem: self-signed certificate in certificate chain`
- host git: `server certificate verification failed`

The first two happen **inside the backend container**, so fixing certificates
on the host (git config, system store) does not help them.

### Fix for the pipeline (Nextflow/curl inside the container)

1. Get your organisation's root CA as a PEM file. Use **one bundle file
   containing the full chain** — the backend picks up only the *first*
   `*.cer`/`*.crt`/`*.pem` file it finds, so multiple separate files won't
   all be used.
2. Place it in `pipeline/ca/`. (`setup.sh` does this automatically when
   `$CURL_CA_BUNDLE`, `$REQUESTS_CA_BUNDLE`, or `$SSL_CERT_FILE` points at
   it — on a fresh machine these are usually unset. Note: those variables
   are read **once, when setup.sh runs** — the running app never sees them;
   it finds certs by scanning `pipeline/ca/` at container start. So export
   them before running setup.sh, or just copy the file yourself.)
3. **Restart the backend container** — the certificate is installed by the
   container entrypoint, i.e. only at container start:

   ```bash
   docker compose restart odin-app-api
   ```

   > ⚠️ `docker compose up -d` is **not** enough while the stack is already
   > running: adding a file to a mounted directory changes nothing that
   > compose tracks, so the container is not recreated and the certificate
   > is never installed.

4. Verify:

   ```bash
   docker logs odin-app-api 2>&1 | grep "Installing runtime CA cert"
   docker exec odin-app-api curl -sS -o /dev/null -w '%{http_code}\n' https://github.com
   # expect: [ODIN] Installing runtime CA cert: ...  and  200
   ```

Alternatively, set `ODIN_CA_CERT=/path/to/bundle.pem` in `.env` — it takes
precedence over the `pipeline/ca/` scan.

### Fix for the host (git clone, curl on the machine itself)

```bash
sudo cp your-ca-bundle.pem /usr/local/share/ca-certificates/your-ca-bundle.crt
sudo update-ca-certificates
# git and git-lfs — point at the FULL system bundle (git-lfs rejects a
# corporate-only bundle):
git config --global http.sslCAInfo /etc/ssl/certs/ca-certificates.crt
```

## Enlighten datasets on Windows-mounted or network drives

Windows drives mounted into WSL (`/mnt/...`), network shares, and Docker
Desktop shared folders deliver no native file-change events — a file watcher
on them silently sees nothing.

**enlweb-api handles this automatically**: it detects such
filesystems at startup and switches its dataset watcher to polling (look for
`auto-enabling polling` in the container log). Unknown filesystems that turn
out to be event-less are also detected at runtime and demoted to polling
after missing changes twice.

Manual override, if you need a different poll rate: declare the feather
plugin explicitly in
`pipeline/enlighten/config/server_config.yaml` with
`polling_interval_sec: <seconds>` — see the commented example there
(`0` = automatic, `> 0` = force polling at that interval).

## Git LFS pointer files

Large binary files are tracked with Git LFS (see `.gitattributes`):
`*.fastq.gz`, `*.k2d`, `*.kmer_distrib`. If you cloned without LFS installed,
those files are ~130-byte text pointers like:

```text
version https://git-lfs.github.com/spec/v1
oid sha256:7f...
size 12345
```

and pipelines fail on them. To recover, complete all three steps in order:

1. Install the `git lfs` package for your OS — follow [https://git-lfs.com/](https://git-lfs.com/)
2. Activate LFS hooks (once per machine): `git lfs install`
3. Download the actual binary files: `git lfs pull`

## AMR / SSU pipeline fails with "Process requirement exceeds available CPUs"

**Symptom:** the wf-metagenomics AMR or SSU pipeline fails immediately with:
```
Process requirement exceeds available CPUs -- req: 4; avail: 2
```

**Cause:** The Docker CPU allocation is lower than the 4 CPUs the `fastcat`
process requests — Docker Desktop resources manually limited, or a
`.wslconfig` file on Windows capping WSL2 CPUs.

**Fix 1 — increase Docker Desktop CPU allocation (preferred):**
> Docker Desktop → Settings → Resources → CPUs → set to 4 or more

**Fix 2 — cap CPU requests in `odin.config`** (when you cannot change Docker
settings): open `pipeline/config/odin.config` and add `executor.cpus` and
`resourceLimits` to the `odin_epi2me` profile, set to the CPUs Docker
actually has (e.g. 2):

```groovy
odin_epi2me {
    // ... existing settings ...
    executor.name           = 'local'
    executor.cpus           = 2          // ← add
    process {
        beforeScript = _beforeScript
        resourceLimits = [cpus: 2]       // ← add: silently caps per-process requests
        // ... existing withName blocks ...
    }
}
```

`resourceLimits` makes Nextflow silently reduce any process CPU request that
exceeds the limit — slower, but it completes.

### CPU profiles in odin.config

`pipeline/config/odin.config` defines three profiles:

| Profile | Used by | Default CPU limit |
|---|---|---|
| `odin` | taxprofiler | `executor.cpus = 4`, `resourceLimits cpus: 4` |
| `odin_epi2me` | wf-metagenomics (AMR, SSU) | none — inherits from Docker |
| `odin_big` | taxprofiler (large runs) | `executor.cpus = 16` |

The `odin_epi2me` profile has no hard CPU limit by design. Add
`resourceLimits` only if your Docker CPU allocation is lower than 4.

## Running with rootless Podman instead of Docker

Full taxprofiler runs, including the sibling task containers, work under
rootless Podman (tested on WSL2/Ubuntu 26.04 with Podman 5.7 and
podman-compose 1.5). Two `.env` settings switch the stack over — no
compose edits:

```bash
ODIN_CONTAINER_SOCK=/run/user/<your-uid>/podman/podman.sock   # id -u
ODIN_UI_PORT=8099    # rootless cannot bind ports below 1024
```

(`setup.sh` writes both automatically when it finds Podman and no Docker.)
The app is then at http://localhost:8099. A bonus of rootless: pipeline
outputs are owned by you, not root.

**One-time host setup:**

```bash
sudo apt install podman-compose
systemctl --user enable --now podman.socket   # creates the API socket
loginctl enable-linger "$USER"                # keeps it across logouts
mkdir -p ~/.config/containers
cat >> ~/.config/containers/containers.conf <<'EOF'
[engine]
compose_providers = ["podman-compose"]
compose_warning_logs = false
EOF
```

Then `podman compose up -d` from the repo directory (instead of
`docker compose up -d`).

**Podman gotchas:**

- **Do NOT run `podman machine init` on WSL2** — WSL2 is already Linux;
  that command builds a VM and fails looking for qemu. Skip it.
- **Broken container networking after a reboot** (`aardvark-dns failed to
  start`, `dial unix /run/user/<uid>/bus: no such file`): the systemd *user*
  session is not running — a known WSL2 boot race, and a hard prerequisite
  for rootless networking. Check before starting the stack:
  ```bash
  systemctl is-active user@$(id -u).service   # must print: active
  ```
  If not: `sudo systemctl start user@$(id -u).service`, or `wsl --shutdown`
  from PowerShell and reopen the shell.
- **`podman system check` reports phantom "damage" while containers run**
  (`layer content modified` for every image with a running container). Only
  run it with the stack stopped, and do not wipe storage on its say-so —
  `podman system reset` would destroy the app database volume.
- **On a machine that also has Docker Desktop**, Podman may silently borrow
  Docker's compose plugin — the `compose_providers` line above pins it to
  podman-compose so the two runtimes stay independent. Never point
  `DOCKER_HOST` at the Podman socket, and never run both stacks at once
  (shared host ports).
- The compose file's image names are fully qualified (`docker.io/...`)
  because Podman, unlike Docker, refuses to guess the registry for short
  names on a clean host.
- **podman-compose cannot expand variables inside `${VAR:-...}` fallbacks**
  (nested braces produce garbage; even the unbraced form passes the inner
  variable through unexpanded). The compose file therefore uses
  literal-only fallbacks, and every default derived from
  `ODIN_PIPELINE_ROOT` (seed dir, Nextflow assets/store, Enlighten data
  path) is computed by the backend itself.
  Tripwire: a container env value containing a literal `$ODIN_PIPELINE_ROOT`
  or `${...}` fragment means a variable fallback crept back into
  `docker-compose.yml`.

## Multiple checkouts of this repo

The compose file uses fixed container names (`odin-app-api`, …) and a shared
named volume (`odin-demo-data`). Consequences when you keep more than one
clone on a machine:

- only ONE stack can run at a time — `docker compose up` in a second clone
  takes over the container names and ports;
- **all clones share the same app database** — a `down -v` in any clone
  deletes it for all of them.

Run `docker compose down` in one clone before `up` in another, and check
`docker ps` (the compose project label tells you which clone owns the
running stack).

## Useful cleanup

Remove generated runtime/cache/output data while keeping committed inputs:

```bash
git clean -fdx pipeline/nf/ pipeline/output/
```

Full demo reset — wipe the ODIN database so seed data is re-imported on next
startup:

```bash
docker compose down -v
docker compose up -d
```
