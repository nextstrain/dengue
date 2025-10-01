# nextstrain.org/dengue/ingest

This is the ingest pipeline for dengue virus sequences.

## Software requirements

Follow the [standard installation instructions](https://docs.nextstrain.org/en/latest/install.html) for Nextstrain's suite of software tools.

## Usage

All workflows are expected to the be run from the top level pathogen repo directory.
The default ingest workflow should be run with

Fetch sequences with

```sh
nextstrain build ingest data/sequences.ndjson
```

Run the complete ingest pipeline with

```sh
nextstrain build ingest
```

This will produce 10 files (within the `ingest` directory):

A pair of files with all the dengue sequences:

- `ingest/results/metadata_all.tsv`
- `ingest/results/sequences_all.fasta`

A pair of files for each dengue serotype (denv1 - denv4)

- `ingest/results/metadata_denv1.tsv`
- `ingest/results/sequences_denv1.fasta`
- `ingest/results/metadata_denv2.tsv`
- `ingest/results/sequences_denv2.fasta`
- `ingest/results/metadata_denv3.tsv`
- `ingest/results/sequences_denv3.fasta`
- `ingest/results/metadata_denv4.tsv`
- `ingest/results/sequences_denv4.fasta`

Run the complete ingest pipeline and upload results to AWS S3 with

```sh
nextstrain build \
    --env AWS_ACCESS_KEY_ID \
    --env AWS_SECRET_ACCESS_KEY \
    ingest \
        upload_all \
        --configfile build-configs/nextstrain-automation/config.yaml
```

### Adding new sequences not from GenBank

#### Static Files

Do the following to include sequences from static FASTA files.

1. Convert the FASTA files to NDJSON files with:

    ```sh
    ./ingest/scripts/fasta-to-ndjson \
        --fasta {path-to-fasta-file} \
        --fields {fasta-header-field-names} \
        --separator {field-separator-in-header} \
        --exclude {fields-to-exclude-in-output} \
        > ingest/data/{file-name}.ndjson
    ```

2. Add the following to the `.gitignore` to allow the file to be included in the repo:

    ```gitignore
    !ingest/data/{file-name}.ndjson
    ```

3. Add the `file-name` (without the `.ndjson` extension) as a source to `ingest/defaults/config.yaml`. This will tell the ingest pipeline to concatenate the records to the GenBank sequences and run them through the same transform pipeline.

## Configuration

Configuration takes place in `defaults/config.yaml` by default.
Optional configs for uploading files are in `build-configs/nextstrain-automation/config.yaml`.

### Environment Variables

The complete ingest pipeline with AWS S3 uploads uses the following environment variables:

#### Required

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

#### Optional

These are optional environment variables used in our automated pipeline.

- `GITHUB_RUN_ID` - provided via [`github.run_id` in a GitHub Action workflow](https://docs.github.com/en/actions/learn-github-actions/contexts#github-context)
- `AWS_BATCH_JOB_ID` - provided via [AWS Batch Job environment variables](https://docs.aws.amazon.com/batch/latest/userguide/job_env_vars.html)

## Input data

### GenBank data

GenBank sequences and metadata are fetched via [NCBI datasets](https://www.ncbi.nlm.nih.gov/datasets/docs/v2/download-and-install/).
