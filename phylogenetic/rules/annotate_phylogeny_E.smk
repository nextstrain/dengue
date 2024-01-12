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

ruleorder: translate_E > translate

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