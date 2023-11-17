# Nextclade Dataset

## Nextclade Web v2

| clade_membership | accession | strain | Nextclade Web |
|:--|:--|:--|:--|
| | [NC_002640](https://www.ncbi.nlm.nih.gov/nuccore/NC_002640) | DENV4/NA/REFERENCE/2003 (DENV4)| [Nextclade all](https://clades.nextstrain.org/?dataset-url=https://github.com/nextstrain/dengue/tree/cp_ingest_nextpr/nextclade_data/all) |
| DENV1 | [NC_001477](https://www.ncbi.nlm.nih.gov/nuccore/NC_001477) | DENV1/NAURUISLAND/REFERENCE/1997 | [Nextclade denv1](https://clades.nextstrain.org/?dataset-url=https://github.com/nextstrain/dengue/tree/cp_ingest_nextpr/nextclade_data/denv1) |
| DENV2 | [NC_001474](https://www.ncbi.nlm.nih.gov/nuccore/NC_001474) | DENV2/THAILAND/REFERENCE/1964 | [Nextclade denv2](https://clades.nextstrain.org/?dataset-url=https://github.com/nextstrain/dengue/tree/cp_ingest_nextpr/nextclade_data/denv2) |
| DENV3 | [NC_001475](https://www.ncbi.nlm.nih.gov/nuccore/NC_001475) | DENV3/SRI_LANKA/REFERENCE/2000 | [Nextclade denv3](https://clades.nextstrain.org/?dataset-url=https://github.com/nextstrain/dengue/tree/cp_ingest_nextpr/nextclade_data/denv3) |
| DENV4 | [NC_002640](https://www.ncbi.nlm.nih.gov/nuccore/NC_002640) | DENV4/NA/REFERENCE/2003 | [Nextclade denv4](https://clades.nextstrain.org/?dataset-url=https://github.com/nextstrain/dengue/tree/cp_ingest_nextpr/nextclade_data/denv4) |

## Nextclade

```
# Nextclade calls for denv1 to denv4
nextclade run \
  --input-dataset nextclade_data/all \
  --output-tsv nextclade_serotypes.tsv \
  --min-match-rate 0.01 \
  --silent \
  sequences.fasta

# Nextclade calls for subtypes within those groups
nextclade run \
  --input-dataset nextclade_data/denv1 \
  --output-tsv nextclade_denv1.tsv \
  --min-match-rate 0.01 \
  --silent \
  denv1.fasta
```