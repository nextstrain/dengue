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
        sequences = lambda wildcard: "data/sequences_{serotype}.fasta" if wildcard.gene in ['genome'] else "results/{serotype}/{gene}/sequences.fasta",
        metadata = "data/metadata_{serotype}.tsv",
        exclude = config["filter"]["exclude"],
        include = config["filter"]["include"],
    output:
        sequences = "results/{serotype}/{gene}/filtered.fasta"
    benchmark:
        "benchmarks/{serotype}/{gene}/filter.txt"
    params:
        group_by = config['filter']['group_by'],
        subsample_max_sequences = config['filter']['subsample_max_sequences'],
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
            --subsample-max-sequences {params.subsample_max_sequences} \
            --min-length {params.min_length} \
            --exclude-where country=? region=? date=? is_lab_host='true' \
            --query-columns is_lab_host:str
        """

rule align:
    """
    Aligning sequences to {input.reference}
      - filling gaps with N
    """
    input:
        sequences = "results/{serotype}/{gene}/filtered.fasta",
        reference = lambda wildcard: "defaults/{serotype}/reference.gb" if wildcard.gene in ['genome'] else "results/defaults/reference_{serotype}_{gene}.gb"
    output:
        alignment = "results/{serotype}/{gene}/aligned.fasta"
    benchmark:
        "benchmarks/{serotype}/{gene}/align.txt"
    threads: 8
    shell:
        """
        augur align \
            --sequences {input.sequences} \
            --reference-sequence {input.reference} \
            --output {output.alignment} \
            --fill-gaps \
            --remove-reference \
            --nthreads {threads}
        """
