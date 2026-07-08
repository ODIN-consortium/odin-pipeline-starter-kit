#!/usr/bin/env bash
# Set up a clean ODIN data folder for a real (field) deployment — and walk you
# through the few settings ODIN needs.
#
#   bash init_pipeline_tree.sh /mnt/<drive>/pipeline
#   bash init_pipeline_tree.sh /mnt/<drive>/pipeline --profile <name-or-path>
#
# What it does:
#   1. Creates the folder structure ODIN expects at the location you give it,
#      with the standard configuration files — and none of the demo data.
#   2. Installs a DEPLOYMENT PROFILE — the project's own configuration: the
#      priority pathogen list, the qPCR assay calibrations, the read-extraction
#      targets (see pipeline/deployments/README.md). Default: mobile_lab_2025.
#   3. Asks a few questions (where your sequencing data is, where your
#      reference databases are, a name for this computer) and writes the
#      answers to the .env settings file for you.
#
# Safe to re-run: it never overwrites existing files, and it backs up .env
# before changing it.

set -euo pipefail

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; BOLD='\033[1m'; NC='\033[0m'

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="${REPO_ROOT}/pipeline"
ENV_FILE="${REPO_ROOT}/.env"
PROFILES_DIR="${SRC}/deployments"
DEFAULT_PROFILE="mobile_lab_2025"

usage() {
    echo "Usage: bash init_pipeline_tree.sh <data-folder> [--profile <name-or-path>] [--configure]"
    echo "Example: bash init_pipeline_tree.sh /mnt/i/pipeline"
    echo
    echo "Deployment profiles in this checkout (default: ${DEFAULT_PROFILE}):"
    for p in "${PROFILES_DIR}"/*/; do [[ -d "$p" ]] && echo "  $(basename "$p")"; done
}

TARGET=""; PROFILE="${DEFAULT_PROFILE}"; CONFIGURE=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --profile)   [[ $# -ge 2 ]] || { usage; exit 1; }; PROFILE="$2"; shift 2 ;;
        --configure) CONFIGURE=true; shift ;;
        -h|--help)   usage; exit 0 ;;
        *)           if [[ -z "$TARGET" ]]; then TARGET="$1"; shift; else usage; exit 1; fi ;;
    esac
done
[[ -n "$TARGET" ]] || { usage; exit 1; }

if [[ ! -d "$SRC" ]]; then
    echo -e "${RED}ERROR: template source not found: $SRC (run from a full starter-kit checkout)${NC}"
    exit 1
fi

# A profile is a folder: a name under pipeline/deployments/, or any path (so a profile
# kept in another repository works too).
if [[ -d "$PROFILE" ]]; then
    PROFILE_DIR="$(cd "$PROFILE" && pwd)"
elif [[ -d "${PROFILES_DIR}/${PROFILE}" ]]; then
    PROFILE_DIR="${PROFILES_DIR}/${PROFILE}"
else
    echo -e "${RED}ERROR: deployment profile not found: ${PROFILE}${NC}"
    usage
    exit 1
fi

created=0; kept=0; warned=0

note_lfs_pointer() {
    # A not-downloaded Git LFS file is a small text pointer, not the real file.
    if head -c 100 "$1" 2>/dev/null | grep -q "git-lfs"; then
        echo -e "    ${YELLOW}WARNING: $1 is a Git LFS pointer, not the real file."
        echo -e "    Run 'bash setup.sh' (or 'git lfs pull') in the repo first, then re-run this script.${NC}"
        warned=$((warned+1))
        return 0
    fi
    return 1
}

copy_file() {  # copy_file <repo-relative-path>
    local rel="$1" src="${SRC}/$1" dst="${TARGET}/$1"
    if [[ -e "$dst" ]]; then kept=$((kept+1)); return; fi
    note_lfs_pointer "$src" && return
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    created=$((created+1))
}

copy_profile_file() {  # copy_profile_file <file-in-profile> <target-relative-path>
    local src="${PROFILE_DIR}/$1" dst="${TARGET}/$2"
    if [[ ! -f "$src" ]]; then
        echo -e "    ${YELLOW}WARNING: profile has no $1 — ODIN will run without it${NC}"
        warned=$((warned+1)); return
    fi
    if [[ -e "$dst" ]]; then kept=$((kept+1)); return; fi
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    created=$((created+1))
}

copy_tree() {  # copy_tree <repo-relative-dir> — every file under it, no overwrite
    local rel="$1"
    if [[ ! -d "${SRC}/${rel}" ]]; then
        echo -e "    ${YELLOW}WARNING: template dir missing in checkout, skipped: ${rel}${NC}"
        warned=$((warned+1))
        return
    fi
    while IFS= read -r -d '' f; do
        copy_file "${f#"${SRC}/"}"
    done < <(find "${SRC}/${rel}" -type f -print0)
}

echo -e "${BOLD}==> Setting up the ODIN data folder at: $TARGET${NC}"
echo

# ── Directory skeleton ────────────────────────────────────────────────────────
for d in \
    minknow \
    output \
    biomeme/biomeme_input_data \
    databases \
    input_sheets \
    config \
    ca \
    nf \
    enlighten/config \
    enlighten/data \
    enlighten/files/public \
; do
    mkdir -p "${TARGET}/${d}"
done
echo "    Folder structure in place."

# ── Deployment profile (the project's own configuration) ─────────────────────
# Copied first, so the profile's files win over the generic templates below
# (copy_file never overwrites).
echo "    Deployment profile: ${PROFILE_DIR}"
copy_profile_file "pathogens.yaml"      "input_sheets/pathogens.yaml"   # priority pathogen list
copy_profile_file "assay-params.csv"    "config/assay-params.csv"       # Biomeme qPCR calibrations
copy_profile_file "extract_targets.csv" "config/extract_targets.csv"    # read-extraction targets

# ── Generic configuration templates (no demo data) ────────────────────────────
copy_file "config/odin.config"          # Nextflow profiles
copy_tree "enlighten/config"            # server_config.yaml, client_config.yaml
copy_tree "enlighten/files/public"      # Enlighten static assets, templates, user manual
copy_file "databases/README.md"
copy_tree "ca"                          # corporate CA certs, if this checkout has
                                        # any — needed BEFORE the first start on
                                        # office networks with SSL inspection
# NOT copied on purpose:
#   input_sheets/databases.csv — the demo's file references the demo database and,
#     when present, takes priority over the Databases page. Without it, entries
#     from the Databases page (or auto-discovery) are used — the right default.
#   config/*.csv of the demo tree — those are the demo stack's working copies; a
#     field installation gets them from the profile. (The demo tree has no
#     input_sheets/pathogens.yaml at all: the demo stack reads the profile's file
#     in place through ODIN_PATHOGENS_FILE, set by setup.sh in .env.)
#   demo runs, demo databases, demo metadata — a field installation starts
#     empty; metadata is entered directly in ODIN (it is a metadata editor).
#   nf/ content — the app fills this in automatically at first start.

echo "    Configuration copied ($created files; $kept already present)."
[[ $warned -gt 0 ]] && echo -e "    ${YELLOW}$warned file(s) skipped — see warnings above.${NC}"

# ── Guided settings ───────────────────────────────────────────────────────────
# Asks where things are and writes the answers to .env. Runs when a person is
# at the keyboard (or with --configure); skipped in scripts/pipelines.
env_set() {  # env_set KEY VALUE — update key in .env, or append it
    local key="$1" value="$2"
    if [[ -f "$ENV_FILE" ]] && grep -q "^${key}=" "$ENV_FILE"; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$ENV_FILE"
    else
        printf '%s=%s\n' "$key" "$value" >> "$ENV_FILE"
    fi
    echo -e "      ${GREEN}${key}=${value}${NC}"
}

ask() {  # ask "question" "default" -> REPLY_VALUE
    local q="$1" def="$2"
    read -r -p "$(echo -e "  ${BOLD}${q}${NC} [${def}]: ")" REPLY_VALUE
    REPLY_VALUE="${REPLY_VALUE:-$def}"
}

interactive=false
[[ -t 0 ]] && interactive=true
$CONFIGURE && interactive=true

if $interactive; then
    echo
    echo -e "${BOLD}==> A few questions to finish the setup${NC}"
    echo "    (press Enter to accept the suggested answer)"
    echo

    if [[ -f "$ENV_FILE" ]]; then
        cp "$ENV_FILE" "${ENV_FILE}.bak.$(date +%Y%m%d%H%M%S)"
        echo "    Your current .env was backed up first."
    fi
    echo "    Writing settings to: $ENV_FILE"
    env_set "ODIN_PIPELINE_ROOT" "$TARGET"
    # A .env written by setup.sh for the demo points ODIN_PATHOGENS_FILE at the repo's
    # profile file. The data folder just created has its own input_sheets/pathogens.yaml
    # (copied from the profile above) — that is the one ODIN must read and the operator
    # may edit, so the override is cleared here.
    if [[ -f "$ENV_FILE" ]] && grep -q "^ODIN_PATHOGENS_FILE=." "$ENV_FILE"; then
        env_set "ODIN_PATHOGENS_FILE" ""
        echo "      (cleared: this data folder has its own input_sheets/pathogens.yaml)"
    fi

    # Sequencing data location
    ask "Where does MinKNOW write your sequencing runs?" "${TARGET}/minknow"
    if [[ "$REPLY_VALUE" != "${TARGET}/minknow" ]]; then
        env_set "ODIN_MINKNOW_DIR" "$REPLY_VALUE"
    fi

    # Reference databases — fast internal disk strongly recommended on WSL2
    db_default="${TARGET}/databases"
    if grep -qi microsoft /proc/version 2>/dev/null; then
        db_default="/ODIN/databases"
        echo
        echo "  Note: reference databases work much faster from the computer's"
        echo "  internal disk than from a USB/external drive."
    fi
    ask "Where will your reference databases (Kraken2) live?" "$db_default"
    if [[ "$REPLY_VALUE" != "${TARGET}/databases" ]]; then
        env_set "ODIN_DATABASE_PATH" "$REPLY_VALUE"
        if [[ ! -d "$REPLY_VALUE" ]]; then
            if mkdir -p "$REPLY_VALUE" 2>/dev/null; then
                echo "      (created $REPLY_VALUE)"
            else
                echo -e "      ${YELLOW}Could not create $REPLY_VALUE — run:${NC}"
                echo "        sudo mkdir -p $REPLY_VALUE && sudo chown \$USER $REPLY_VALUE"
            fi
        fi
    fi

    # Device name — recorded on every entry made on this computer
    ask "A short name for this computer/operator (shown on records it creates)" "$(hostname)"
    env_set "ODIN_DEVICE_NAME" "$REPLY_VALUE"

    # Working files on the fast disk (WSL2)
    if grep -qi microsoft /proc/version 2>/dev/null; then
        ask "Keep ODIN's working files on the fast internal disk? (recommended) y/n" "y"
        if [[ "$REPLY_VALUE" =~ ^[Yy] ]]; then
            env_set "ODIN_WORK_DIR" "/ODIN/work"
            env_set "ODIN_LOG_DIR" "/ODIN/logs"
        fi
    fi
else
    echo
    echo "    (No one at the keyboard — skipping the questions. Run"
    echo "     'bash init_pipeline_tree.sh $TARGET --configure' to answer them,"
    echo "     or set ODIN_PIPELINE_ROOT=$TARGET in .env yourself.)"
fi

# ── What's next ───────────────────────────────────────────────────────────────
echo
echo -e "${GREEN}${BOLD}Done.${NC} Next steps:"
echo
echo "  1. Put your reference database folder(s) into the databases location"
echo "     chosen above — ODIN finds them automatically."
echo "  2. Check the deployment profile you just installed ($(basename "$PROFILE_DIR")):"
echo "     ${TARGET}/input_sheets/pathogens.yaml is the list of organisms that get a"
echo "     'Priority pathogen group' in Enlighten; config/assay-params.csv and"
echo "     config/extract_targets.csv are its qPCR calibrations and extraction"
echo "     targets. If your project's lists differ, replace them BEFORE the first"
echo "     analysis — results are annotated when they are processed, and a later"
echo "     change means re-running post-processing for every run."
echo "  3. Start ODIN:   docker compose down && docker compose up -d"
echo "  4. Open http://localhost and enter your sites and samples directly"
echo "     in ODIN — it is the metadata editor for your deployment."
echo "  5. Before going offline, follow FIELD_DEPLOYMENT.md (one full test"
echo "     run while online, then the offline test)."
