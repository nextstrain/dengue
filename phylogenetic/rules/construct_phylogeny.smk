"""
This part of the workflow constructs the phylogenetic tree.
REQUIRED INPUTS:
    metadata            = results/{serotype}/metadata.tsv
    prepared_sequences  = results/{serotype}/{gene}/aligned.fasta
OUTPUTS:
    tree            = results/{serotype}/{gene}/tree.nwk
    branch_lengths  = results/{serotype}/{gene}/branch-lengths.json
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
    benchmark:
        "benchmarks/{serotype}/{gene}/tree.txt"
    threads:
        8
    shell:
        """
        augur tree \
            --alignment {input.alignment} \
            --output {output.tree} \
            --nthreads {threads}
        """

def _clock_rate_params(wildcards):
    """
    Generate the clock rate parameters for dengue samples for augur refine based on if wildcard serotype and gene values are in the config file

    refine:
      clock_rate:
        wildcards.serotype:
          wildcards.gene: numeric value here

    else leave blank
    """
    clock_rate = config.get('refine', {}).get('clock_rate', {}).get(wildcards.serotype, {}).get(wildcards.gene, "")
    if clock_rate !="":
        return f' --clock-rate {clock_rate} '
    else:
        return ""

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
        metadata = "results/{serotype}/metadata.tsv"
    output:
        tree = "results/{serotype}/{gene}/tree.nwk",
        node_data = "results/{serotype}/{gene}/branch-lengths.json",
    benchmark:
        "benchmarks/{serotype}/{gene}/refine.txt"
    params:
        coalescent = "const",
        date_inference = "marginal",
        clock_filter_iqd = 4,
        clock_rate_params = lambda wildcards: _clock_rate_params(wildcards),
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
            {params.clock_rate_params} \
            --coalescent {params.coalescent} \
            --date-confidence \
            --date-inference {params.date_inference} \
            --clock-filter-iqd {params.clock_filter_iqd}
        """
