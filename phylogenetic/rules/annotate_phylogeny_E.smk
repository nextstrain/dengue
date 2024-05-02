"""
This part of the workflow creates additonal annotations for the phylogenetic tree.
REQUIRED INPUTS:
    metadata            = data/metadata_all.tsv
    prepared_sequences  = results/aligned.fasta
    tree                = results/tree.nwk
OUTPUTS:
    node_data = results/*.json
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
ruleorder: ancestral_E > ancestral
ruleorder: translate_E > translate
ruleorder: traits_E > traits

rule ancestral_E:
    """Reconstructing ancestral sequences and mutations"""
    input:
        tree = "results/tree_{serotype}_E.nwk",
        alignment = "results/aligned_{serotype}_E.fasta"
    output:
        node_data = "results/nt-muts_{serotype}_E.json"
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

rule translate_E:
    """Translating amino acid sequences"""
    input:
        tree = "results/tree_{serotype}_E.nwk",
        node_data = "results/nt-muts_{serotype}_E.json",
        reference = "results/config/reference_dengue_{serotype}_E.gb"
    output:
        node_data = "results/aa-muts_{serotype}_E.json"
    shell:
        """
        augur translate \
            --tree {input.tree} \
            --ancestral-sequences {input.node_data} \
            --reference-sequence {input.reference} \
            --output {output.node_data} \
        """

ruleorder: traits_all_E > traits_E

rule traits_all_E:
    """
    Inferring ancestral traits for {params.columns!s}
      - increase uncertainty of reconstruction by {params.sampling_bias_correction} to partially account for sampling bias
    """
    input:
        tree = "results/tree_all_E.nwk",
        metadata = "data/metadata_all.tsv"
    output:
        node_data = "results/traits_all_E.json",
    params:
        columns = lambda wildcards: config['traits']['E_traits_columns']['all'],
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

rule traits_E:
    """
    Inferring ancestral traits for {params.columns!s}
      - increase uncertainty of reconstruction by {params.sampling_bias_correction} to partially account for sampling bias
    """
    input:
        tree = "results/tree_{serotype}_E.nwk",
        metadata = "data/metadata_{serotype}.tsv"
    output:
        node_data = "results/traits_{serotype}_E.json",
    params:
        columns = lambda wildcards: config['traits']['E_traits_columns'][wildcards.serotype],
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