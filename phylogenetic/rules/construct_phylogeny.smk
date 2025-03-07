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
        alignment = "results/{serotype}/{gene}/aligned.fasta"
    output:
        tree = "results/{serotype}/{gene}/tree-raw.nwk"
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
        tree = "results/{serotype}/{gene}/tree-raw.nwk",
        alignment = "results/{serotype}/{gene}/aligned.fasta",
        metadata = "data/metadata_{serotype}.tsv"
    output:
        tree = "results/{serotype}/{gene}/tree.nwk",
        node_data = "results/{serotype}/{gene}/branch-lengths.json",
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