# Field Deployment Guide (Mobile Lab)

How to prepare a mobile-lab computer so that ODIN works **without internet**,
and how to work with it in the field. Written for the person running the lab:
Part 1 and Part 2 are for you. Part 3 is technical reference for whoever
supports the installation — you can ignore it.

The one idea behind everything here: **while you still have internet, run
everything once — then change nothing.** The first time each analysis runs, it
downloads the tools it needs; after that it can run offline, as long as nobody
updates or "cleans up" the software.

---

## Part 1 — Before you travel (with internet)

### 1. Set up the data folder

Decide where your data will live — typically an external drive, e.g.
`/mnt/i/pipeline`. Then, from the starter-kit folder:

```bash
bash init_pipeline_tree.sh /mnt/i/pipeline
```

The script creates the folder structure, installs the standard configuration
and a **deployment profile** (the project's own lists — see step 2b), and then
**asks you a few questions** — where your sequencing runs are, where your
reference databases will live, a name for this computer — and saves the
answers for you. Just press Enter to accept the suggestions. The default
profile is `mobile_lab_2025`; another one is chosen with `--profile <name>`
(see `pipeline/deployments/README.md`).

While you have the drive in front of you, look at its root directory: files
like `!!!!!<digits>.<ext>` are data-recovery artifacts from the disk's
previous life — investigate before trusting the hardware on a trip.

The script also creates a `ca/` folder. That is for office networks that
intercept HTTPS; it is inert without one, so you can ignore it in the field.

### 2. Add your reference database

Copy your Kraken2 database folder into the databases location you chose in
step 1 (on Windows/WSL2 the script suggests the computer's internal disk,
`/ODIN/databases`, because analysis is much faster from there than from a USB
drive). Example:

```bash
cp -r /path/to/MOBILE_LAB_db6 /ODIN/databases/
```

That's all — ODIN finds databases in that folder automatically and shows them
on its Databases page.

### 2b. Check the deployment profile

The setup script installed three project-specific files from the profile:

| File in the data folder | What it decides |
|---|---|
| `input_sheets/pathogens.yaml` | which organisms get a **Priority pathogen group** in Enlighten (the pathogen bar charts and the target-group datasets) — one entry per NCBI TaxID |
| `config/assay-params.csv` | the Biomeme qPCR assay calibrations |
| `config/extract_targets.csv` | the read-extraction reference targets |

Open the pathogen list once and make sure it is the list your project wants.
Do this **before the first analysis**: results are annotated when they are
processed, so a list changed later only takes effect after **Run
post-processing** (Dashboard → a run's ⋮ menu) has been repeated for every run.
Between June and September 2026 a field installation ran with the 9-row demo
list by mistake and every dashboard showed three pathogens — that is what this
step prevents.

**Remove any leftover Excel list.** Installations set up from the original demo
tree carried `input_sheets/pathogens.xlsx` (the 9-row demo placeholder, in the old
Excel layout). ODIN reads `pathogens.yaml` when it exists, but the Excel file is
read if the YAML is ever missing or renamed, so delete every `pathogens*.xlsx` in
`input_sheets/` once the YAML is in place. The mobile-lab installation had one
until 21 September 2026.

Editing is plain text: each entry has a `taxid`, a `pathogen_group` (the label
shown in Enlighten) and, for documentation, `scientific_name`, `type` and
`target_group`. Organisms are matched on the TaxID, and a group's reads are
counted for that TaxID and everything below it, so list a species once. The
format and the profiles are described in `pipeline/deployments/README.md`.

### 3. Start ODIN and enter your metadata

```bash
docker compose down && docker compose up -d
```

Open http://localhost. **ODIN is your metadata editor**: enter your sites and
samples directly in the app (Sites and Samples pages), and connect runs to
samples from the Dashboard when you register them. This is the normal way to
work — before the trip and in the field.

When your pre-trip metadata is entered, make a backup:
**Sync → Download snapshot**, and save the file on the data drive. If the
installation ever has to be rebuilt, **Sync → Restore** brings everything
back. (The Excel export/import on the same page does the same job in
spreadsheet form — useful if someone prepares sample lists outside ODIN.)

### 4. Prepare for offline operation

The first time each analysis type runs, ODIN downloads the tools it needs;
they stay on the computer afterwards. So the preparation is simply: while
still online, run **one complete analysis of each type you will use in the
field** — from registering the run to seeing the result in Enlighten. After
that, the machine has everything on board.

### 5. The offline test

Prove it works without internet before you depend on it:

1. Add this line to the `.env` file in the starter-kit folder:
   `NXF_OFFLINE=true`
   (it makes any missing download fail immediately with a clear message,
   instead of hanging)
2. Turn off Wi-Fi / unplug the network.
3. Run a complete analysis again: register a run → launch → result appears in
   Enlighten.
4. Also try: unplug and replug the data drive, and reboot the computer — ODIN
   should come back by itself with everything intact.

Leave `NXF_OFFLINE=true` in place for the field.

### 6. From now on: change nothing

Once the offline test passes, the installation is sealed:

> **Do not update ODIN. Do not update or "clean up" Docker. Do not change
> versions of anything.** Every one of those can silently delete a downloaded
> tool that cannot be re-downloaded offline.

---

## Part 2 — In the field

### Daily work

- New sequencing runs appear on the **Dashboard** — register and launch them
  there.
- Add new samples and sites **directly in ODIN** as they arise, like before
  the trip.
- Results appear in **Enlighten** and update as post-processing finishes.
- Once a day (or after significant data entry): **Sync → Download snapshot**
  onto the data drive. That file is your backup of all metadata.
- **Plug the data drive into a port on the computer itself** — not a
  monitor or docking-station USB hub. When a monitor goes to sleep, its hub
  can cut power to the drive mid-run and fail the analysis. During long
  runs, set the display sleep to Never (Windows: Settings → Power).

### Moving the data drive between computers

Typical flow: the drive sits in the sequencing PC while MinKNOW writes, then
moves to the analysis PC for ODIN.

- **Before unplugging**: `docker compose down`, then eject the drive in
  Windows.
- **After plugging in**: `sudo mount /mnt/i`, then `docker compose up -d`.

(One-time setup per computer so the two commands above work: see
"Drive mobility" in Part 3 — ask your support person.)

### If something looks wrong

| What you see | What to do |
|---|---|
| A run doesn't appear on the Dashboard | Press Scan. Still missing → is the drive mounted? (`sudo mount /mnt/i`, then restart ODIN: `docker compose down && docker compose up -d`) |
| A launch fails immediately with a "download/offline" message | Something wasn't warmed up before departure. Note the message for your support person; the run can be launched again once resolved. |
| Enlighten stops updating | Restart the stack: `docker compose down && docker compose up -d` — datasets are on the drive and come back. |
| ODIN webpage doesn't load | `docker compose up -d` (starts anything that stopped); if the computer just booted, wait a minute and reload. |

Anything beyond this: [TROUBLESHOOTING.md](TROUBLESHOOTING.md), or your
support person — with Part 3 below.

---

## Part 3 — Technical reference (support engineers)

Everything below assumes Docker/WSL2 familiarity. The lab operator does not
need it.

### Offline-safety inventory

Baked into images (no runtime network dependency):

| Component | Where | Notes |
|---|---|---|
| Nextflow launcher (pinned) | backend image (`Dockerfile.backend`) | no first-run download |
| Nextflow framework fat-jar | backend image, `NXF_HOME=/opt/nextflow` | pre-placed so Nextflow skips fetching it |
| nf-schema plugin | backend image | see plugin-version caveat below |
| taxprofiler workflow source | backend image, seeded to `$ODIN_PIPELINE_ROOT/nf/taxprofiler-<revision>` at first container start | launches use the seeded copy — no GitHub access. `<revision>` is `TAXPROFILER_REVISION` (default 1.2.6) and must match what the image bundles, or it falls back to the GitHub pull; `TAXPROFILER_DIR` overrides with a different checkout |
| ODIN api/ui, Enlighten api/client, squirrel | Docker image cache | pin exact tags in compose; never `--pull` in the field |

Still requiring the online warm-up:

| Risk | Why | Fix |
|---|---|---|
| Task containers (quay.io/biocontainers, one per process) | pulled lazily on first use of each process | run every pipeline type end-to-end once per machine; survives restarts but NOT `docker system prune` |
| Reference databases (Kraken2/Bracken) | large downloads/builds | in place before departure; verify Databases page / `ODIN_DATABASE_PATH` auto-discovery resolves locally |
| Krona taxonomy | may fetch on first `--run_krona` | covered by the warm-up run |
| Overridden `TAXPROFILER_REVISION` | an unbundled revision falls back to the GitHub pull | stick to the bundled revision, or vendor + `TAXPROFILER_DIR` |
| Plugin version mismatch | workflow declaring a different plugin version than baked triggers a runtime download | exposed immediately by the `NXF_OFFLINE=true` drill |

### Settings written by init_pipeline_tree.sh

The interactive setup writes `.env`: `ODIN_PIPELINE_ROOT` (the data folder),
`ODIN_PATHOGENS_FILE` cleared (a `.env` made by `setup.sh` for the demo points it at
the repo's profile file; a field data folder has its own `input_sheets/pathogens.yaml`,
which ODIN reads when the variable is empty),
`ODIN_MINKNOW_DIR` (sequencing data outside the pipeline root — compose
bind-mounts it identically, env overrides the Settings-UI value),
`ODIN_DATABASE_PATH` (databases on fast ext4 — Kraken2 memory-maps `hash.k2d`;
9p/USB is punishingly slow; auto-discovery scans this dir for subdirs
containing `hash.k2d`), `ODIN_DEVICE_NAME` (row attribution + sync
filenames), and on WSL2 `ODIN_WORK_DIR`/`ODIN_LOG_DIR` (`/ODIN/work`,
`/ODIN/logs` — Nextflow work dirs are v9fs-unsafe on `/mnt/*`). All paths are
bind-mounted by the compose file with no-op defaults — no compose edits.
`/ODIN` does not travel with the drive: re-copy databases onto each new
machine; the drive keeps the transport copy.

**Applying a change to `.env` or the compose file**: full `docker compose
down`, then `up -d`. `up -d` alone has left the MinKNOW scan broken after
mount changes. (`down`, not `down -v`, unless you mean to wipe the database.)

### Fresh database for a new deployment

`docker compose down -v` (the `-v` removes the named volume `odin-demo-data`
holding the SQLite state; plain `down` keeps it). The next start begins with
an empty metadata database — restore a Sync snapshot, or start entering
metadata in the app. NOTE: the volume is shared across ALL checkouts of this
repo on the machine (see TROUBLESHOOTING.md).

### Drive mobility (one-time per machine)

Fix the drive letter in Windows Disk Management (paths in `.env` depend on
it), then in the WSL distro's `/etc/fstab`:

```
I: /mnt/i drvfs rw,noatime,uid=1000,gid=1000,nofail 0 0
```

WSL auto-mounts only drives present at boot; after a replug,
`sudo mount /mnt/i` remounts (no `wsl --shutdown` needed — that kills every
distro and the Docker backend).

Config travels with the drive: `enlighten/config` on the drive is what the
stack mounts, so a drive prepared on another machine brings that machine's
settings with it — review it after migrating.

### When the stack won't start in the field

- **`up -d` fails with `error while creating mount source path … file exists`
  or `stating <path>: no such device`** (Docker Desktop/WSL2), while the path
  looks fine from the WSL shell: Docker Desktop's VM holds stale state for
  the drive, from before it was remounted or a mounted directory re-created
  (e.g. after re-scaffolding). Escalate in order — each step is a superset:
  1. Restart Docker Desktop from its own menu (NOT by killing its
     processes — that orphans the WSL integration and forces step 2).
  2. If the error persists: close WSL work in other distros, then
     `wsl --shutdown` from PowerShell and start Docker Desktop again —
     this restarts the whole WSL VM and always clears it. Remount the
     drive afterwards (`sudo mount /mnt/i`).
  (Under rootless Podman there is no Docker Desktop VM layer — step 2,
  `wsl --shutdown`, is the whole procedure.)
- **"Scan finds nothing" although the host path exists**: the path is outside
  every container bind mount. Check
  `docker inspect --format '{{range .Mounts}}{{.Source}} -> {{.Destination}}\n{{end}}' odin-app-api`.
- **`mkdir: Already exists` for a folder that is not there** (scaffolding onto
  a Windows-mounted drive after deleting the old tree): a ghost directory
  entry in WSL's 9p view of the drive — `mkdir` sees the deleted name,
  `stat` does not, and it can survive WSL restarts. Workaround: create the
  folder from the Windows side (`mkdir I:\pipeline` in any Windows shell),
  then re-run the script — it continues idempotently.
- **USB drive vanished mid-run** (`Failed to create publish directory`,
  `stat -f /mnt/i` → `No such device`, while other mounts stay healthy):
  observed cause was a monitor-integrated USB hub cutting downstream power
  when the display slept (180 s AC timeout). Use a direct port or
  self-powered hub; `powercfg /change monitor-timeout-ac 0` during runs;
  disable USB selective suspend. A dropout also deletes the concat
  workspace, so resuming re-reads all input over slow 9p.

### Packing list (data drive)

- Reference databases (transport copy) and, if used, a `databases.csv`
- MinKNOW output directory structure as the instruments expect
- The latest Sync snapshot (metadata backup)
- A copy of this repo at the tested commit
- Optional: `docker save` bundles of all images as a recovery path if the
  Docker cache is ever lost in the field
