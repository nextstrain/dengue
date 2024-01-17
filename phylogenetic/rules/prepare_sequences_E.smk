"""
This part of the workflow prepares sequences for constructing the phylogenetic tree.
REQUIRED INPUTS:
    metadata_url    = url to metadata.tsv.zst
    sequences_url   = url to sequences.fasta.zst
    reference   = path to reference sequence or genbank
OUTPUTS:
    prepared_sequences = results/aligned.fasta
This part of the workflow usually includes the following steps:
    - augur index
    - augur filter
    - augur align
    - augur mask
See Augur's usage docs for these commands for more details.
"""

ruleorder: align_and_extract_E > decompress
ruleorder: filter_E > align

rule generate_E_reference_files:
    """
    Generating reference files for the E gene
    """
    input:
        reference = "config/reference_{serotype}_genome.gb",
    output:
        fasta = "results/config/reference_{serotype}_E.fasta",
        genbank = "results/config/reference_{serotype}_E.gb",
    params:
        gene = "E",
    shell:
        """
        python3 bin/newreference.py \
            --reference {input.reference} \
            --output-fasta {output.fasta} \
            --output-genbank {output.genbank} \
            --gene {params.gene}
        """

rule align_and_extract_E:
    """
    Cutting sequences to the length of the E gene reference sequence
    """
    input:
        sequences = "data/sequences_{serotype}.fasta",
        reference = "results/config/reference_{serotype}_E.fasta"
    output:
        sequences = "results/sequences_{serotype}_E.fasta"
    params:
        min_length = config['filter']['E_min_length'],
    shell:
        """
        nextclade3 run \
           -j 2 \
           --input-ref {input.reference} \
           --output-fasta {output.sequences} \
           --min-seed-cover 0.01 \
           --min-length {params.min_length} \
           --silent \
           {input.sequences}
        """

rule filter_E:
    """
    Filtering to
      - {params.sequences_per_group} sequence(s) per {params.group_by!s}
      - excluding strains in {input.exclude}
      - minimum genome length of {params.min_length}
      - excluding strains with missing region, country or date metadata
    """
    input:
        sequences = "results/sequences_{serotype}_E.fasta",
        metadata = "data/metadata_{serotype}.tsv",
        exclude = config["filter"]["exclude"],
    output:
        sequences = "results/aligned_{serotype}_E.fasta"
    params:
        group_by = config['filter']['group_by'],
        sequences_per_group = lambda wildcards: config['filter']['sequences_per_group'][wildcards.serotype],
        root_sequence = lambda wildcards: config['filter']['E_root_sequence'][wildcards.serotype],
        min_length = config['filter']['E_min_length'],
        strain_id = config.get("strain_id_field", "strain"),
    shell:
        """
        augur filter \
            --sequences {input.sequences} \
            --metadata {input.metadata} \
            --metadata-id-columns {params.strain_id} \
            --exclude {input.exclude} \
            --output {output.sequences} \
            --group-by {params.group_by} \
            --sequences-per-group {params.sequences_per_group} \
            --min-length {params.min_length} \
            --exclude-where country=? region=? date=? \
            --include-where strain={params.root_sequence}
        """
