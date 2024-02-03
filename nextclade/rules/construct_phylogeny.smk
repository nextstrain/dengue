"""
This part of the workflow constructs the phylogenetic tree.
REQUIRED INPUTS:
    metadata            = data/metadata_all.tsv
    prepared_sequences  = results/aligned_serotype.fasta
OUTPUTS:
    tree            = results/tree.nwk
    branch_lengths  = results/branch_lengths.json
This part of the workflow usually includes the following steps:
    - augur tree
    - augur refine
See Augur's usage docs for these commands for more details.
"""

rule tree:
    """Building tree"""
    input:
        alignment = "results/aligned_{serotype}.fasta"
    output:
        tree = "results/tree-raw_{serotype}.nwk"
    shell:
        """
        augur tree \
            --alignment {input.alignment} \
            --output {output.tree} \
            --nthreads 1
        """

rule refine:
    """
    Refining tree
      - estimate timetree
      - use {params.coalescent} coalescent timescale
      - estimate {params.date_inference} node dates
      - filter tips more than {params.clock_filter_iqd} IQDs from clock expectation
    """
    input:
        tree = "results/tree-raw_{serotype}.nwk",
        alignment = "results/aligned_{serotype}.fasta",
        metadata = "data/metadata_{serotype}.tsv"
    output:
        tree = "results/tree_{serotype}.nwk",
        node_data = "results/branch-lengths_{serotype}.json",
    params:
        coalescent = "const",
        date_inference = "marginal",
        clock_filter_iqd = 4,
        strain_id = config.get("strain_id_field", "strain"),
    shell:
        """
        augur refine \
            --tree {input.tree} \
            --alignment {input.alignment} \
            --metadata {input.metadata} \
            --metadata-id-columns {params.strain_id} \
            --output-tree {output.tree} \
            --output-node-data {output.node_data} \
            --timetree \
            --coalescent {params.coalescent} \
            --date-confidence \
            --date-inference {params.date_inference} \
            --clock-filter-iqd {params.clock_filter_iqd}
        """