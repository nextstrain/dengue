# CHANGELOG

We use this CHANGELOG to document breaking changes, new features, bug fixes, and config value changes that may affect both the usage of the workflows and the outputs of the workflows.

## 2024

* 26 February 2024: Exclude circular synthetic (or chimeric) and duplicate sequences. [PR #29](https://github.com/nextstrain/dengue/pull/29)
* 23 February 2024: Use nextclade v3 dataset to classify records into subtypes (DENV1/I, DENV1/II, DENV4/I, etc). [PR #16](https://github.com/nextstrain/dengue/pull/16)
* 24 February 2024: Split the pair of metadata.tsv and sequences.fasta files by serotype (DENV1-DENV4) using NCBI `virus-tax-id` field. [PR #20](https://github.com/nextstrain/dengue/pull/20)
* 09 January 2024: Use a phylogenetic directory to start conforming to the [pathogen-repo-guide](https://github.com/nextstrain/pathogen-repo-guide). [PR #15](https://github.com/nextstrain/dengue/pull/15)

## 2023

* 05 December 2023: Initialize the ingest directory for pulling data from NCBI datasets and subsequent curation for a single pair of metadata.tsv and sequences.fasta files. [PR #13](https://github.com/nextstrain/dengue/pull/13)
* 12 October 2023: Since multiple records can have the same strain name, use the "accession" column as the ID column instead. [PR #12](https://github.com/nextstrain/dengue/pull/12)
* 09 April 2023: Add the DENV2/AII clade amino acid defining changes. [PR #11](https://github.com/nextstrain/dengue/pull/11)

## 2022

* 13 October 2022: Instead of pulling data from the fauna database, pull data from an s3 url [PR #5](https://github.com/nextstrain/dengue/pull/5)
* 05 April 2022: CI: Use a centralized pathogen repo CI workflow. [PR #3](https://github.com/nextstrain/dengue/pull/3)
* 04 April 2022: Migrate CI to GitHub Actions. [PR #3](https://github.com/nextstrain/dengue/pull/3)

## 2021

* 09 November 2021: CI: Upgrade setuptools suite prior to installation. [PR #2](https://github.com/nextstrain/dengue/pull/2)

## 2019

* 10 December 2019: Switch to export v2. [PR #1](https://github.com/nextstrain/dengue/pull/1)
* 16 August 2019: Update build to work with ViPR data. (https://github.com/nextstrain/dengue/commit/081f9f82d971e75848ac1967bf6d841e05428545)

## 2018

* 30 December 2018: Initialize the dengue repository. (https://github.com/nextstrain/dengue/commit/3e0f9feaa4d1799cdda6cf839e03d09390f39c53)
