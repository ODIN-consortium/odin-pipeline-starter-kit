# Deployment profiles

A **deployment profile** is the project-specific configuration a field installation
needs on top of the ODIN software: which organisms count as priority pathogens, the
qPCR assay calibrations, the read-extraction targets. It is not application code and
not demo data — it is the answer to "what is *this* project looking for".

Each profile is one self-contained folder here:

```text
deployments/
  README.md                 ← this file
  mobile_lab_2025/          ← the ODIN mobile-lab deployment (Tanzania, Burkina Faso, DRC)
    README.md               ← provenance and editing notes for that profile
    pathogens.yaml          ← pathogen list → installed as input_sheets/pathogens.yaml
    assay-params.csv        ← Biomeme qPCR assay calibration → config/assay-params.csv
    extract_targets.csv     ← read-extraction targets → config/extract_targets.csv
```

`init_pipeline_tree.sh` installs a profile into the data folder:

```bash
bash init_pipeline_tree.sh /mnt/<drive>/pipeline                       # default: mobile_lab_2025
bash init_pipeline_tree.sh /mnt/<drive>/pipeline --profile <name>      # another folder here
bash init_pipeline_tree.sh /mnt/<drive>/pipeline --profile /path/to/a/profile/folder
```

Files are copied only where nothing exists yet, so re-running never overwrites a list
you have edited on the data drive. A profile change on an installation that has already
processed runs takes effect only after **Run post-processing** has been repeated for
those runs (Dashboard → a run's ⋮ menu).

## Adding a profile

Copy `mobile_lab_2025/`, rename it, edit the three files, and describe the project and
the provenance of each list in its README. The `--profile` path form means a profile
can also live outside this repository — the intent is that, if more deployments come,
the profiles move to a repository of their own and this folder disappears; nothing
here depends on where the folder lives.

## The pathogen list format

`pathogens.yaml` has one entry per NCBI TaxID under a top-level `pathogens:` key:

```yaml
pathogens:
  - taxid: 573                       # NCBI Taxonomy ID (integer, required)
    scientific_name: "Klebsiella pneumoniae"
    type: bacteria                   # bacteria | virus | eukaryotic
    target_group: AMR                # AMR | waterborne | non-waterborne
    priority: WP2-priority           # optional
    pathogen_group: "ESBL/Carbapenemase producing K. pneumoniae"   # required; the label shown in Enlighten
```

ODIN matches Kraken2 rows on the TaxID and gives the group to that node and everything
below it, so list a species once rather than every strain. The older Excel layout
(`pathogens.xlsx`, sheet `comprehensive_pathogen_list`, header on row 3) is still read
when no `pathogens.yaml` is present, but no profile ships one any more; an installation
that still has a `pathogens*.xlsx` in `input_sheets/` should delete it (see
FIELD_DEPLOYMENT.md, step 2b).
