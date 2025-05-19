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

rule download:
    """Downloading sequences and metadata from data.nextstrain.org"""
    output:
        sequences = "data/sequences_{serotype}.fasta.zst",
        metadata = "data/metadata_{serotype}.tsv.zst"
    benchmark:
        "benchmarks/{serotype}/download.txt"
    params:
        sequences_url = config["sequences_url"],
        metadata_url = config["metadata_url"],
    shell:
        """
        curl -fsSL --compressed {params.sequences_url:q} --output {output.sequences}
        curl -fsSL --compressed {params.metadata_url:q} --output {output.metadata}
        """

rule decompress:
    """Parsing fasta into sequences and metadata"""
    input:
        sequences = "data/sequences_{serotype}.fasta.zst",
        metadata = "data/metadata_{serotype}.tsv.zst"
    output:
        sequences = "data/sequences_{serotype}.fasta",
        metadata = "data/metadata_{serotype}.tsv"
    benchmark:
        "benchmarks/{serotype}/decompress.txt"
    shell:
        """
        zstd -d -c {input.sequences} > {output.sequences}
        zstd -d -c {input.metadata} > {output.metadata}
        """

rule filter:
    """
    Filtering to
      - {params.sequences_per_group} sequence(s) per {params.group_by!s}
      - excluding strains in {input.exclude}
      - minimum genome length of {params.min_length}
      - excluding strains with missing region, country or date metadata
    """
    input:
        sequences = lambda wildcard: "data/sequences_{serotype}.fasta" if wildcard.gene in ['genome'] else "results/{gene}/sequences_{serotype}.fasta",
        metadata = "data/metadata_{serotype}.tsv",
        exclude = config["filter"]["exclude"],
        include = config["filter"]["include"],
    output:
        sequences = "results/{gene}/filtered_{serotype}.fasta"
    benchmark:
        "benchmarks/{serotype}/{gene}/filter.txt"
    params:
        group_by = config['filter']['group_by'],
        sequences_per_group = lambda wildcards: config['filter']['sequences_per_group'][wildcards.serotype],
        min_length = lambda wildcard: config['filter']['min_length'][wildcard.gene],
        strain_id = config.get("strain_id_field", "strain"),
    shell:
        """
        augur filter \
            --sequences {input.sequences} \
            --metadata {input.metadata} \
            --metadata-id-columns {params.strain_id} \
            --exclude {input.exclude} \
            --include {input.include} \
            --output-sequences {output.sequences} \
            --group-by {params.group_by} \
            --sequences-per-group {params.sequences_per_group} \
            --min-length {params.min_length} \
            --exclude-where country=? region=? date=? \
        """

rule add_outgroup:
    """
    Adding outgroup to the filtered sequences
    """
    input:
        sequences = "results/{gene}/filtered_{serotype}.fasta",
        outgroup = lambda wildcard: config["outgroup"][wildcard.serotype],
    output:
        sequences = "results/{gene}/filtered_{serotype}_with_outgroup.fasta"
    benchmark:
        "benchmarks/{serotype}/{gene}/add_outgroup.txt"
    shell:
        """
        cat {input.sequences} {input.outgroup} > {output.sequences}
        """

rule align:
    """
    Aligning sequences to {input.reference}
      - filling gaps with N
    """
    input:
        sequences = lambda wildcard: "results/{gene}/filtered_{serotype}.fasta" if wildcard.serotype in ['all'] else "results/{gene}/filtered_{serotype}_with_outgroup.fasta",
        reference = "resources/{serotype}/reference.fasta",
    output:
        alignment = "results/{gene}/aligned_{serotype}.fasta"
    benchmark:
        "benchmarks/{serotype}/{gene}/align.txt"
    shell:
        """
        augur align \
            --sequences {input.sequences} \
            --reference-sequence {input.reference} \
            --output {output.alignment} \
            --fill-gaps \
            --nthreads 1
        """
