# Deployment profile: ODIN mobile lab 2025

Configuration for the ODIN mobile-laboratory deployment (Tanzania, Burkina Faso,
Democratic Republic of Congo; sampling 2025, sequencing September 2025).

| File | Installed as | What it is |
|---|---|---|
| `pathogens.yaml` | `input_sheets/pathogens.yaml` | The priority pathogen list: 47 NCBI TaxIDs in 27 groups (AMR bacteria, waterborne and non-waterborne pathogens). Decides which organisms get a *Priority pathogen group* in Enlighten. Same file as the analysis code's `pathogen_group_map.yaml`, so dashboards and manuscript figures count the same organisms. |
| `assay-params.csv` | `config/assay-params.csv` | Biomeme qPCR assay calibrations (`Abundance = 10^((Cq − B) / M)`) for the 13 assays run in the field: Mpox/Orthopox (E9L, G2R_G, G2R_WA, Mpox‑K, C3L), *V. cholerae* ctxA, *S.* Typhi STadh, *K. pneumoniae* Khe, *E. coli* uidA, and the enteric-virus assays. |
| `extract_targets.csv` | `config/extract_targets.csv` | Read-extraction targets for the Mpox clade references (Ia, Ib, II). |

## Decisions recorded in the pathogen list

- *Salmonella* is one group, "Salmonella spp.", counted on the *S. enterica* clade
  (TaxID 28901); serovars are not split out (SME consensus, June 2026).
- *Vibrio cholerae* is the O1 (127906) and O139 (45888) nodes — the project's original
  scope — not the species node 666.
- Group labels are plain text. Until 21 Sept 2026 four AMR labels carried a trailing
  zero-width space (U+200B) and "Cryptosporidium" a trailing space, inherited from the
  original Excel workbook; both were removed everywhere, and the app's pathogen-list
  reader strips such characters if they reappear. Datasets exported before that date
  carry the old labels, so re-export after upgrading.

## Editing

Edit the YAML, then either re-run `init_pipeline_tree.sh` on an installation that has
no `input_sheets/pathogens.yaml` yet, or copy the file there by hand, and repeat
**Run post-processing** for every processed run. Keep this profile in step with the
analysis code's copy of the list.
