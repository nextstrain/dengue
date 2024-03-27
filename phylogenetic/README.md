# nextstrain.org/dengue

This is the [Nextstrain](https://nextstrain.org) build for dengue. Output from this build is visible at
[nextstrain.org/dengue](https://nextstrain.org/dengue).


## Software requirements

Follow the [standard installation instructions](https://docs.nextstrain.org/en/latest/install.html) for Nextstrain's suite of software tools.

## Usage

If you're unfamiliar with Nextstrain builds, you may want to follow our
[Running a Pathogen Workflow guide][] first and then come back here.

The easiest way to run this pathogen build is using the Nextstrain
command-line tool:

    nextstrain build .

Build output goes into the directories `data/`, `results/` and `auspice/`.

Once you've run the build, you can view the results in auspice:

    nextstrain view auspice/


## Configuration

Configuration for the workflow takes place entirely within the [defaults/config_dengue.ymal](defaults/config_dengue.yaml).
The analysis pipeline is contained in [Snakefile](Snakefile) with included [rules](rules).
Each rule specifies its file inputs and output and pulls its parameters from the config.
There is little redirection and each rule should be able to be reasoned with on its own.


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

The above datasets have been preprocessed and cleaned from GenBank and are updated at regular intervals. 

### Using example data

Alternatively, you can run the build using the
example data provided in this repository.  Before running the build, copy the
example sequences into the `data/` directory like so:

    nextstrain build .  --configfile profiles/ci/profiles_config.yaml

## AWS

With access to AWS, this can be more quickly run as:

    nextstrain build --aws-batch --aws-batch-cpus 4 --aws-batch-memory 7200 . --jobs 4

[Nextstrain]: https://nextstrain.org
[augur]: https://docs.nextstrain.org/projects/augur/en/stable/
[auspice]: https://docs.nextstrain.org/projects/auspice/en/stable/index.html
[Installing Nextstrain guide]: https://docs.nextstrain.org/en/latest/install.html
[Running a Pathogen Workflow guide]: https://docs.nextstrain.org/en/latest/tutorials/running-a-workflow.html

### Deploying build

To run the workflow and automatically deploy the build to nextstrain.org,
you will need to have AWS credentials to run the following:

```
nextstrain build \
    --env AWS_ACCESS_KEY_ID \
    --env AWS_SECRET_ACCESS_KEY \
    . \
        deploy_all \
        --configfile build-configs/nextstrain-automation/config.yaml
```
