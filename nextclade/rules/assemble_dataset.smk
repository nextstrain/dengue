"""
This part of the workflow assembles a nextclade dataset.
REQUIRED INPUTS:
    tree           = nextstrain tree
    pathogen_json  = configs in pathogen.json file
OUTPUTS:
    nextclade_dataset = nextclade_dataset
This part of the workflow usually includes the following steps:
    - Copying the tree and pathogen.json to appropriate location in datasets
See Augur's usage docs for these commands for more details.
"""

rule assemble_dataset:
    input:
        reference="resources/{serotype}/reference.fasta",
        tree="auspice/dengue_{serotype}.json",
        pathogen_json="resources/{serotype}/pathogen.json",
        #sequences="resources/{serotype}/sequences.fasta",
        annotation="resources/{serotype}/genome_annotation.gff3",
        readme="resources/{serotype}/README.md",
        changelog="resources/{serotype}/CHANGELOG.md",
    output:
        reference="datasets/{serotype}/reference.fasta",
        tree="datasets/{serotype}/tree.json",
        pathogen_json="datasets/{serotype}/pathogen.json",
        #sequences="datasets/{serotype}/sequences.fasta",
        annotation="datasets/{serotype}/genome_annotation.gff3",
        readme="datasets/{serotype}/README.md",
        changelog="datasets/{serotype}/CHANGELOG.md",
    shell:
        """
        cp {input.reference} {output.reference}
        cp {input.tree} {output.tree}
        cp {input.pathogen_json} {output.pathogen_json}
        cp {input.annotation} {output.annotation}
        cp {input.readme} {output.readme}
        cp {input.changelog} {output.changelog}
        """
# #cp {input.sequences} {output.sequences}

rule test_dataset:
    input:
        tree="datasets/{serotype}/tree.json",
        pathogen_json="datasets/{serotype}/pathogen.json",
        sequences="resources/all/sequences.fasta",
        annotation="datasets/{serotype}/genome_annotation.gff3",
        readme="datasets/{serotype}/README.md",
        changelog="datasets/{serotype}/CHANGELOG.md",
    output:
        outdir=directory("test_output/{serotype}"),
    params:
        dataset_dir="datasets/{serotype}",
    shell:
        """
        nextclade run \
          --input-dataset {params.dataset_dir} \
          --output-all {output.outdir} \
          --silent \
          {input.sequences}
        """