#!/usr/bin/env bash
# One-time setup before `docker compose up`:
#   - downloads the Git LFS binary files (fastq.gz, Kraken2 databases)
#   - auto-detects a corporate CA certificate (for SSL-inspection networks)
#   - generates .env: sets ODIN_PIPELINE_ROOT, a device name for this computer
#     (ODIN_DEVICE_NAME), and a unique per-install login
#     (ODIN_AUTH_USER / ODIN_AUTH_PASSWORD)
#
#   bash setup.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="${REPO_ROOT}/.env"
PIPELINE_ROOT="${REPO_ROOT}/pipeline"

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; NC='\033[0m'

# ── Git LFS ───────────────────────────────────────────────────────────────────
echo "==> Checking Git LFS..."
if command -v git-lfs &>/dev/null || git lfs version &>/dev/null 2>&1; then
    # A fresh clone (with git-lfs installed) already has the LFS hooks. Only run
    # 'lfs install' when the hook is absent, so we never overwrite an existing hook.
    if [ ! -f "${REPO_ROOT}/.git/hooks/pre-push" ]; then
        echo "    Configuring Git LFS for this repository..."
        git -C "${REPO_ROOT}" lfs install --local
    fi
    # 'git lfs ls-files' marks a present object with '*' and a not-yet-downloaded
    # pointer with '-'. This is a fast local check, so only run the (slow, network)
    # pull when something is still a pointer.
    if git -C "${REPO_ROOT}" lfs ls-files | grep -qE '^[0-9a-f]+ - '; then
        echo "    Fetching missing LFS files..."
        git -C "${REPO_ROOT}" lfs pull
        echo -e "    ${GREEN}LFS files downloaded.${NC}"
    else
        echo -e "    ${GREEN}LFS files already present.${NC}"
    fi
else
    echo -e "    ${RED}WARNING: git-lfs not found.${NC}"
    echo "    Large files (fastq.gz, Kraken2 DBs) will be missing or corrupted."
    echo "    1. Install it (e.g. 'sudo apt install git-lfs' or 'brew install git-lfs')"
    echo "    2. Run 'git lfs install' and 'git lfs pull' in this directory."
fi

# ── .env ──────────────────────────────────────────────────────────────────────
if [[ -f "$ENV_FILE" ]]; then
    echo ".env already exists — overwrite? [y/N] "
    read -r answer
    [[ "$answer" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }
fi

# ── Corporate CA Certificate ──────────────────────────────────────────────────
# Auto-detect corporate certificates from common environment variables.
# This ensures that if the host is already configured for a corporate firewall,
# the backend container will also have the certificate for Nextflow/CURL tasks.
CA_DIR="${REPO_ROOT}/pipeline/ca"
mkdir -p "$CA_DIR"

for var in REQUESTS_CA_BUNDLE CURL_CA_BUNDLE SSL_CERT_FILE; do
    # Use variable indirection to get value of $REQUESTS_CA_BUNDLE etc.
    CERT_VAL="${!var:-}"
    if [[ -f "$CERT_VAL" ]]; then
        echo "==> Corporate CA detected via \$$var..."
        DEST="$CA_DIR/$(basename "$CERT_VAL")"
        if [[ ! -f "$DEST" ]]; then
            cp "$CERT_VAL" "$DEST"
            echo -e "    ${GREEN}Copied certificate to pipeline/ca/${NC}"
        else
            echo "    Certificate already exists in pipeline/ca/"
        fi
        break # Only need one
    fi
done

# ── Frontend login credentials (HTTP Basic Auth) ────────────────────────────────
# The frontend enforces a username/password in front of the whole app. Generate a
# memorable, per-install password (two short words + a number) so no two demos share
# the same default. Reuse existing values if .env already has them, so re-running
# setup does not change your login.
AUTH_USER="$(grep -E '^ODIN_AUTH_USER=' "$ENV_FILE" 2>/dev/null | tail -n1 | cut -d= -f2- || true)"
AUTH_PASS="$(grep -E '^ODIN_AUTH_PASSWORD=' "$ENV_FILE" 2>/dev/null | tail -n1 | cut -d= -f2- || true)"
[[ -n "$AUTH_USER" ]] || AUTH_USER="odin"
if [[ -z "$AUTH_PASS" ]]; then
    WORDS=(otter tiger falcon cedar maple river amber comet delta ember flint coral
           heron ivory jasper koala lemon mango nectar olive pearl quartz raven sable
           topaz umber violet walnut yarrow zephyr basil clover dune fern grove hazel
           indigo juniper kelp larch moss north opal pine reef sage teak wren)
    w1="${WORDS[RANDOM % ${#WORDS[@]}]}"
    w2="${WORDS[RANDOM % ${#WORDS[@]}]}"
    AUTH_PASS="${w1}-${w2}-$((RANDOM % 90 + 10))"
fi

# ── Device name ─────────────────────────────────────────────────────────────────
# Stamped into created_by/updated_by on every row and used in sync export filenames,
# so it has to identify this computer — and has to stay the same between runs.
#
# The backend deliberately has no default for it: the only name available inside the
# container is the container ID, which changes every time the container is recreated,
# so one machine would show up in the data as a series of different devices. The host
# hostname IS stable, so it is resolved out here and written into .env.
#
# Reused from an existing .env exactly like the login above: re-running setup must not
# silently re-label data that was created under the previous name.
DEVICE_NAME="$(grep -E '^ODIN_DEVICE_NAME=' "$ENV_FILE" 2>/dev/null | tail -n1 | cut -d= -f2- || true)"
if [[ -z "$DEVICE_NAME" ]]; then
    DEVICE_NAME="$(hostname 2>/dev/null || true)"
    # Windows without hostname.exe on PATH, then bash's own builtin.
    [[ -n "$DEVICE_NAME" ]] || DEVICE_NAME="${COMPUTERNAME:-${HOSTNAME:-}}"
    # Keep only characters that survive being slugged into an export filename.
    DEVICE_NAME="$(printf '%s' "$DEVICE_NAME" | tr -cd '[:alnum:]._-')"
    [[ -n "$DEVICE_NAME" ]] || DEVICE_NAME="odin-demo"
    # Offer it for confirmation when run interactively; accept it silently otherwise
    # so the script still works unattended.
    if [[ -t 0 ]]; then
        echo
        echo "==> Device name — identifies this computer in the data and in sync exports"
        printf '    Press Enter to accept "%s", or type a different name: ' "$DEVICE_NAME"
        read -r answer
        if [[ -n "$answer" ]]; then
            answer="$(printf '%s' "$answer" | tr -cd '[:alnum:]._-')"
            [[ -z "$answer" ]] || DEVICE_NAME="$answer"
        fi
    fi
fi

# ── Container runtime detection ───────────────────────────────────────────────
# Docker is the default. When only rootless Podman is present, activate the two
# Podman settings (DooD socket + unprivileged UI port); otherwise emit them
# commented so switching later is a two-line .env edit.
CONTAINER_SOCK_LINE="# ODIN_CONTAINER_SOCK=/run/user/$(id -u)/podman/podman.sock"
UI_PORT_LINE="# ODIN_UI_PORT=8099"
# 'command -v docker' is NOT enough: Docker Desktop leaves a shim at
# /usr/bin/docker in every WSL distro, present but non-functional when the
# distro's integration is off ("could not be found in this WSL 2 distro").
# Only a daemon that actually answers counts as Docker being available.
if ! docker info >/dev/null 2>&1 && command -v podman >/dev/null 2>&1; then
    CONTAINER_SOCK_LINE="ODIN_CONTAINER_SOCK=/run/user/$(id -u)/podman/podman.sock"
    UI_PORT_LINE="ODIN_UI_PORT=8099"
    echo
    echo -e "==> Docker not found, Podman is: configured for ${GREEN}rootless Podman${NC}"
    echo "    (UI on http://localhost:8099 — rootless cannot bind port 80."
    echo "     See the Podman section in TROUBLESHOOTING.md for host setup.)"
fi

# ── Pathogen list ──────────────────────────────────────────────────────────────
# The demo tree keeps no input_sheets/pathogens.yaml; the stack reads the deployment
# profile's file in place. A field data folder gets its own copy from
# init_pipeline_tree.sh instead, so the line is only written when the profile file
# exists under the root setup.sh detected (i.e. the repo's own pipeline/).
PROFILE_PATHOGENS="${PIPELINE_ROOT}/deployments/mobile_lab_2025/pathogens.yaml"
if [[ -f "$PROFILE_PATHOGENS" ]]; then
    PATHOGENS_LINE="ODIN_PATHOGENS_FILE=${PROFILE_PATHOGENS}"
else
    PATHOGENS_LINE="# ODIN_PATHOGENS_FILE="
fi

cat > "$ENV_FILE" <<EOF
# Generated by setup.sh — safe to edit by hand.
# Re-running setup.sh asks before overwriting, and keeps the login and device name
# already set here rather than issuing new ones.
# See .env.example for every supported variable, its default, and the expected
# directory layout.

# ── PIPELINE DATA ROOT ────────────────────────────────────────────────────────
# Absolute path to the pipeline/ subdirectory of this repo — not the repo root.
# Auto-detected from where setup.sh lives, and used verbatim as a Docker bind-mount
# path, so if you move or rename this repo the value goes stale: re-run setup.sh to
# refresh it. Every data location (minknow/, output/, biomeme/, databases/) is
# derived from this one path.
ODIN_PIPELINE_ROOT=${PIPELINE_ROOT}

# ── PATHOGEN LIST ─────────────────────────────────────────────────────────────
# The demo stack reads the deployment profile's list in place (there is no copy under
# input_sheets/). If you point ODIN_PIPELINE_ROOT at a field data folder created by
# init_pipeline_tree.sh, blank or delete this line: that folder has its own
# input_sheets/pathogens.yaml, which is what ODIN reads when this is unset.
${PATHOGENS_LINE}

# ── DEVICE IDENTITY ───────────────────────────────────────────────────────────
# Identifies this computer in created_by/updated_by and in sync export filenames.
# Auto-detected from the host hostname by setup.sh — edit for a friendlier name
# (e.g. alice-field-laptop). Keep it stable: changing it makes this one machine
# look like two different devices when data is merged.
ODIN_DEVICE_NAME=${DEVICE_NAME}

# ── FRONTEND LOGIN (HTTP Basic Auth) ──────────────────────────────────────────
# The frontend requires this username/password before showing the app or proxying
# to the API. Auto-generated so each install differs — change if you like.
# For anything beyond a local/loopback demo, also read SECURITY.md.
ODIN_AUTH_USER=${AUTH_USER}
ODIN_AUTH_PASSWORD=${AUTH_PASS}

# ── RECOMMENDED ON WINDOWS/WSL2 ───────────────────────────────────────────────
# Set ODIN_WORK_DIR to a WSL2-native Linux path to avoid I/O failures when
# Nextflow task containers access work directories on a Windows filesystem.
# docker-compose.yml mounts this path identically (host:container) so that
# sibling pipeline containers can reach it via the Docker socket.
# Docker auto-creates the directory on first launch — no mkdir needed.
# Default when unset: /tmp/odin_work (also auto-created).
# ODIN_WORK_DIR=/home/<your-wsl-user>/odin_work

# ── CONTAINER RUNTIME ─────────────────────────────────────────────────────────
# Socket used to spawn pipeline tool containers (Docker-outside-of-Docker).
# Unset -> Docker Engine (/var/run/docker.sock). For rootless Podman, use the
# line below (the path contains your numeric user id) — see TROUBLESHOOTING.md
# for the one-time Podman host setup.
${CONTAINER_SOCK_LINE}
# Web app host port (default 80 -> http://localhost). Rootless Podman cannot
# bind ports below 1024 — 8099 works well:
${UI_PORT_LINE}

# ── OPTIONAL ──────────────────────────────────────────────────────────────────
# ODIN_TMP_DIR=/var/tmp
# ODIN_LOG_DIR=/home/<your-wsl-user>/odin_logs
EOF

echo "Created .env:"
cat "$ENV_FILE"

echo
echo -e "==> ${GREEN}Frontend login${NC} (you will be prompted when you open http://localhost):"
echo -e "      user:     ${GREEN}${AUTH_USER}${NC}"
echo -e "      password: ${GREEN}${AUTH_PASS}${NC}"
echo "    Stored in .env as ODIN_AUTH_USER / ODIN_AUTH_PASSWORD — edit there to change."

echo
echo -e "==> ${GREEN}Device name${NC}: ${GREEN}${DEVICE_NAME}${NC}"
echo "    Recorded on every row you create and used in sync export filenames."
echo "    Stored in .env as ODIN_DEVICE_NAME — edit there to change."
