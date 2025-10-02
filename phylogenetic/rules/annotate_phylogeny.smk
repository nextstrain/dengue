"""
This part of the workflow creates additonal annotations for the phylogenetic tree.
REQUIRED INPUTS:
    metadata            = results/{serotype}/metadata.tsv
    prepared_sequences  = results/{serotype}/{gene}/aligned.fasta
    tree                = results/{serotype}/{gene}/tree.nwk
OUTPUTS:
    node_data = results/{serotype}/{gene}/*.json
    There are no required outputs for this part of the workflow as it depends
    on which annotations are created. All outputs are expected to be node data
    JSON files that can be fed into `augur export`.
    See Nextstrain's data format docs for more details on node data JSONs:
    https://docs.nextstrain.org/page/reference/data-formats.html
This part of the workflow usually includes the following steps:
    - augur traits
    - augur ancestral
    - augur translate
    - augur clades
See Augur's usage docs for these commands for more details.
Custom node data files can also be produced by build-specific scripts in addition
to the ones produced by Augur commands.
"""

rule ancestral:
    """Reconstructing ancestral sequences and mutations"""
    input:
        tree = "results/{serotype}/{gene}/tree.nwk",
        alignment = "results/{serotype}/{gene}/aligned.fasta",
    output:
        node_data = "results/{serotype}/{gene}/nt-muts.json"
    benchmark:
        "benchmarks/{serotype}/{gene}/ancestral.txt"
    params:
        inference = "joint"
    shell:
        """
        augur ancestral \
            --tree {input.tree} \
            --alignment {input.alignment} \
            --output-node-data {output.node_data} \
            --inference {params.inference}
        """

rule translate:
    """Translating amino acid sequences"""
    input:
        tree = "results/{serotype}/{gene}/tree.nwk",
        node_data = "results/{serotype}/{gene}/nt-muts.json",
        reference = lambda wildcard: "defaults/{serotype}/reference.gb" if wildcard.gene in ['genome'] else "results/defaults/reference_{serotype}_{gene}.gb"
    output:
        node_data = "results/{serotype}/{gene}/aa-muts.json"
    benchmark:
        "benchmarks/{serotype}/{gene}/translate.txt"
    shell:
        """
        augur translate \
            --tree {input.tree} \
            --ancestral-sequences {input.node_data} \
            --reference-sequence {input.reference} \
            --output {output.node_data} \
        """

rule traits:
    """
    Inferring ancestral traits for {params.columns!s}
      - increase uncertainty of reconstruction by {params.sampling_bias_correction} to partially account for sampling bias
    """
    input:
        tree = "results/{serotype}/{gene}/tree.nwk",
        metadata = "results/{serotype}/metadata.tsv",
    output:
        node_data = "results/{serotype}/{gene}/traits.json",
    benchmark:
        "benchmarks/{serotype}/{gene}/traits.txt"
    params:
        columns = lambda wildcards: config['traits']['traits_columns'][wildcards.serotype],
        sampling_bias_correction = config['traits']['sampling_bias_correction'],
        strain_id = config.get("strain_id_field", "strain"),
    shell:
        """
        augur traits \
            --tree {input.tree} \
            --metadata {input.metadata} \
            --metadata-id-columns {params.strain_id} \
            --output {output.node_data} \
            --columns {params.columns} \
            --confidence \
            --sampling-bias-correction {params.sampling_bias_correction}
        """

rule clades:
    """Annotating serotypes / genotypes"""
    input:
        tree = "results/{serotype}/genome/tree.nwk",
        nt_muts = "results/{serotype}/genome/nt-muts.json",
        aa_muts = "results/{serotype}/genome/aa-muts.json",
        clade_defs = lambda wildcards: config['clades']['clade_definitions'][wildcards.serotype],
    output:
        clades = "results/{serotype}/genome/clades.json"
    benchmark:
        "benchmarks/{serotype}/genome/clades.txt"
    shell:
        """
        augur clades \
            --tree {input.tree} \
            --mutations {input.nt_muts} {input.aa_muts} \
            --clades {input.clade_defs} \
            --output {output.clades}
        """
