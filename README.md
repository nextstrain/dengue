# nextstrain.org/dengue

This is the [Nextstrain](https://nextstrain.org) build for dengue, visible at
[nextstrain.org/dengue](https://nextstrain.org/dengue).

The build encompasses fetching data, preparing it for analysis, doing quality
control, performing analyses, and saving the results in a format suitable for
visualization (with [auspice][]).  These steps involves running 
[augur][] subcommands.

All dengue-specific steps and functionality for the Nextstrain pipeline should be
housed in this repository.

[![Build Status](https://github.com/nextstrain/dengue/actions/workflows/ci.yaml/badge.svg?branch=main)](https://github.com/nextstrain/dengue/actions/workflows/ci.yaml)

## Usage

See the [Installing Nextstrain guide][] for how to install the `nextstrain` command.

If you're unfamiliar with Nextstrain builds, you may want to follow our
[Running a Pathogen Workflow guide][] first and then come back here.

The easiest way to run this pathogen build is using the Nextstrain
command-line tool:

    nextstrain build .

Build output goes into the directories `data/`, `results/` and `auspice/`.

Once you've run the build, you can view the results in auspice:

    nextstrain view auspice/


## Configuration

Configuration takes place entirely with the `Snakefile`. This can be read top-to-bottom, each rule
specifies its file inputs and output and also its parameters. There is little redirection and each
rule should be able to be reasoned with on its own.


### Using GenBank data

This build starts by pulling preprocessed sequence and metadata files from: 

* https://data.nextstrain.org/files/dengue/sequences_all.fasta.zst
* https://data.nextstrain.org/files/dengue/metadata_all.tsv.zst
* https://data.nextstrain.org/files/dengue/sequences_denv1.fasta.zst
* https://data.nextstrain.org/files/dengue/metadata_denv1.tsv.zst
* https://data.nextstrain.org/files/dengue/sequences_denv2.fasta.zst
* https://data.nextstrain.org/files/dengue/metadata_denv2.tsv.zst
* https://data.nextstrain.org/files/dengue/sequences_denv3.fasta.zst
* https://data.nextstrain.org/files/dengue/metadata_denv3.tsv.zst
* https://data.nextstrain.org/files/dengue/sequences_denv4.fasta.zst
* https://data.nextstrain.org/files/dengue/metadata_denv4.tsv.zst

The above datasets have been preprocessed and cleaned from GenBank and are updated at regular intervals from the ingest folder.

```
nextstrain build ingest

# Upload final dataset and trigger slack notifications
nextstrain build ingest  --configfiles config/config.yaml config/optional.yaml
```

### Using example data

Alternatively, you can run the build using the
example data provided in this repository.  Before running the build, copy the
example sequences into the `data/` directory like so:

    mkdir -p data/
    cp example_data/dengue* data/

## AWS

With access to AWS, this can be more quickly run as:

    nextstrain build --aws-batch --aws-batch-cpus 4 --aws-batch-memory 7200 . --jobs 4

[Nextstrain]: https://nextstrain.org
[augur]: https://docs.nextstrain.org/projects/augur/en/stable/
[auspice]: https://docs.nextstrain.org/projects/auspice/en/stable/index.html
[Installing Nextstrain guide]: https://docs.nextstrain.org/en/latest/install.html
[Running a Pathogen Workflow guide]: https://docs.nextstrain.org/en/latest/tutorials/running-a-workflow.html
