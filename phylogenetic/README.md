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

The config that was used during the run of the workflow is output to `results/run_config.yaml`.

### Default input data

The default builds start from the public Nextstrain data that have been preprocessed
and cleaned from NCBI GenBank.

```yaml
serotypes: ['all', 'denv1', 'denv2', 'denv3', 'denv4']
inputs:
  - name: ncbi
    metadata: "https://data.nextstrain.org/files/workflows/dengue/metadata_{serotype}.tsv.zst"
    sequences: "https://data.nextstrain.org/files/workflows/dengue/sequences_{serotype}.fasta.zst"
```

Note the inputs require the `{serotype}` expandable field, to be replaced by
the config parameter `serotypes` values.

### Adding your own data

If you want to add your own data to the default input, specify your inputs with
the `additional_inputs` config parameter. For example, this repo has a small set
of example data that could be added to the default inputs via:

```yaml
additional_inputs:
  - name: example-data
    metadata: example_data/metadata_{serotype}.tsv
    sequences: example_data/sequences_{serotype}.fasta
```

Note that the additional inputs also require the `{serotype}` expandable field.
If you only have data for a single serotype, e.g. denv1, then you can do so with

```yaml
serotypes: ["denv1"]
additional_inputs:
  - name: private
    metadata: private/metadata_{serotype}.tsv
    sequences: private/sequences_{serotype}.fasta
```

If you want to run the builds _without_ the default data and only use your own
data, you can do so by specifying the `inputs` parameter.

```yaml
inputs:
  - name: example-data
    metadata: example_data/metadata_{serotype}.tsv
    sequences: example_data/sequences_{serotype}.fasta
```

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
