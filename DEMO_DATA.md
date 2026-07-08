# Demo Data Reference

What this repository's `pipeline/` tree contains and how ODIN consumes it.
The main setup path is in the [README](README.md).

## Repository layout

The repository root holds deployment/bootstrap files. Runtime data and
configuration live under `pipeline/`, which is used as `ODIN_PIPELINE_ROOT`.

```text
pipeline/
  minknow/                 ← Nanopore demo runs (MinKNOW layout)
    DemoExperiment/
      DemoSample1/…        ← metagenomics run 1 (2 barcodes)
      DemoSample2/…        ← metagenomics run 2 (2 barcodes)
      MpoxDemoRun/…        ← mpox amplicon run (1 barcode)
  biomeme/
    biomeme_input_data/    ← Biomeme qPCR workbooks (countries AA, BB)
    biomeme_processed/
  seed/                    ← the demo's pre-loaded metadata
  databases/
    demo_crypto_giardia/   ← demo Kraken2 database
  deployments/             ← deployment profiles: a project's own configuration
    mobile_lab_2025/       ← pathogens.yaml, assay-params.csv, extract_targets.csv
                             (installed on field computers by init_pipeline_tree.sh)
  config/                  ← the demo stack's working copies: odin.config,
                             extraction targets, assay params
  input_sheets/            ← databases.csv. There is no pathogen list here: the demo
                             stack reads deployments/mobile_lab_2025/pathogens.yaml in
                             place (ODIN_PATHOGENS_FILE in .env, written by setup.sh);
                             a field data folder gets its own copy from
                             init_pipeline_tree.sh. The demo data only contains
                             Giardia, Cryptosporidium and Mpox.
  enlighten/               ← Enlighten config, data and static files
  ca/                      ← corporate CA certs (empty by default)
  nf/                      ← Nextflow runtime area (assets, store, seeded
                             workflow) — generated, gitignored
  output/                  ← pipeline outputs — generated
```

## Nanopore demo — metagenomics (taxprofiler / wf-metagenomics)

Two MinKNOW runs intended for metagenomic classification pipelines
(taxprofiler, wf-metagenomics AMR/SSU):

| Run accession | Barcodes | Experiment | Sample |
|---|---|---|---|
| `20260610_0800_MN00000_FAX00001_aabb1234` | barcode01, barcode02 | DemoExperiment | DemoSample1 |
| `20260611_0800_MN00000_FAX00002_ccdd5678` | barcode01, barcode02 | DemoExperiment | DemoSample2 |

- Kit: Rapid Barcoding Kit (RB_GEN, P2 protocol)
- Pre-registered in the demo metadata, with matching `DEMO_*` sites/samples

## Nanopore demo — mpox amplicon (artic-mpxv-nf)

One MinKNOW run with anonymized mpox sequencing data for the artic-mpxv-nf
amplicon pipeline:

| Run accession | Barcodes | Experiment | Sample |
|---|---|---|---|
| `20260115_0800_MN00000_FAX00003_ee112233` | barcode01 | DemoExperiment | MpoxDemoRun |

- Kit: Rapid Barcoding Kit 114-24 (SQK-RBK114-24, P5 protocol) — amplicon sequencing
- Scheme: `artic-inrb-mpox/2500/v1.0.0`
- Clade: select **Mpox Clade Ia** or **Mpox Clade Ib** when launching
- Pre-registered in the demo metadata, using the same `DEMO_*` sites/samples
  as the metagenomics runs

## Biomeme demo

- 6 anonymized Biomeme Excel files across two dummy countries (`AA`, `BB`)
- Pre-registered in the demo metadata (`AADS1_*`, `BBDS1_*` sites/samples)
- Files are intentionally minimized to the rows ODIN uses for parsing, so
  behavior matches real ingestion while removing unused metadata

## Demo metadata

The demo's sites, samples and run registrations are loaded automatically the
first time the stack starts (from `pipeline/seed/`). A reset
(`docker compose down -v && docker compose up -d`) restores them.

In a real deployment there is no pre-loaded metadata: **ODIN is the metadata
editor** — sites, samples and runs are entered directly in the app, and
**Sync → Download snapshot / Restore** covers backup and re-deployment.

## Pipeline databases

Taxprofiler needs a Kraken2/Bracken database. Three sources, in priority
order:

1. A `databases.csv` file (this demo ships one at
   `pipeline/input_sheets/databases.csv` referencing the demo database) —
   when present it wins outright;
2. Entries on the **Databases** page in the UI;
3. Auto-discovery: any directory containing `hash.k2d` under
   `ODIN_DATABASE_PATH` (or `$ODIN_PIPELINE_ROOT/databases` when unset).

The demo works out of the box via source 1 and the bundled
`demo_crypto_giardia` database. For real databases and fast-filesystem
placement, see [FIELD_DEPLOYMENT.md](FIELD_DEPLOYMENT.md).

## Workflow and tool downloads

- The taxprofiler workflow source is bundled in the backend image and seeded
  to `$ODIN_PIPELINE_ROOT/nf/taxprofiler-<revision>` at first start — launches
  need no GitHub access. `<revision>` is `TAXPROFILER_REVISION` (default
  1.2.6); asking for a revision the image did not bundle falls back to a
  GitHub pull.
- The per-process tool containers (quay.io/biocontainers) are pulled on
  first use of each pipeline type and cached by Docker.
- Other pipelines may download/cache assets under `pipeline/nf/`.
