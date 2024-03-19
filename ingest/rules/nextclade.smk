"""
This part of the workflow handles running Nextclade on the curated metadata
and sequences.
REQUIRED INPUTS:
    metadata    = data/metadata_all.tsv
    sequences   = results/sequences_{serotype}.fasta
    nextclade_datasets = ../nextclade_data/{serotype}
OUTPUTS:
    metadata        = results/metadata_{serotype}.tsv
    nextclade       = results/nextclade_subtypes.tsv
See Nextclade docs for more details on usage, inputs, and outputs if you would
like to customize the rules:
https://docs.nextstrain.org/projects/nextclade/page/user/nextclade-cli.html
"""

SUPPORTED_NEXTCLADE_SEROTYPES = ['denv1', 'denv2', 'denv3', 'denv4']
SEROTYPE_CONSTRAINTS = '|'.join(SUPPORTED_NEXTCLADE_SEROTYPES)

rule nextclade_denvX:
    """
    For each type, classify into the appropriate subtype
    """
    input:
        sequences="results/sequences_{serotype}.fasta",
        dataset="../nextclade_data/{serotype}",
    output:
        nextclade_denvX="data/nextclade_results/nextclade_{serotype}.tsv",
    threads: 4
    params:
        min_length=config["nextclade"]["min_length"],
        min_seed_cover=config["nextclade"]["min_seed_cover"],
    wildcard_constraints:
        serotype=SEROTYPE_CONSTRAINTS
    shell:
        """
        nextclade run \
          --input-dataset {input.dataset} \
          -j {threads} \
          --output-tsv {output.nextclade_denvX} \
          --min-length {params.min_length} \
          --min-seed-cover {params.min_seed_cover} \
          --silent \
          {input.sequences}
        """

rule concat_nextclade_subtype_results:
    """
    Concatenate all the nextclade results for dengue subtype classification
    """
    input:
        expand("data/nextclade_results/nextclade_{serotype}.tsv", serotype=SUPPORTED_NEXTCLADE_SEROTYPES),
    output:
        nextclade_subtypes="results/nextclade_subtypes.tsv",
    params:
        id_field=config["curate"]["id_field"],
        nextclade_field=config["nextclade"]["nextclade_field"],
    shell:
        """
        echo "{params.id_field},{params.nextclade_field}" \
        | tr ',' '\t' \
        > {output.nextclade_subtypes}

        tsv-select -H -f "seqName,clade" {input} \
        | awk 'NR>1 {{print}}' \
        >> {output.nextclade_subtypes}
        """

rule append_nextclade_columns:
    """
    Append the nextclade results to the metadata
    """
    input:
        metadata="data/metadata_all.tsv",
        nextclade_subtypes="results/nextclade_subtypes.tsv",
    output:
        metadata_all="results/metadata_all.tsv",
    params:
        id_field=config["curate"]["id_field"],
        nextclade_field=config["nextclade"]["nextclade_field"],
    shell:
        """
        tsv-join -H \
            --filter-file {input.nextclade_subtypes} \
            --key-fields {params.id_field} \
            --append-fields {params.nextclade_field} \
            --write-all ? \
            {input.metadata} \
        > {output.metadata_all}
        """

rule split_metadata_by_serotype:
    """
    Split the metadata by serotype
    """
    input:
        metadata="results/metadata_all.tsv",
    output:
        serotype_metadata="results/metadata_{serotype}.tsv"
    wildcard_constraints:
        serotype=SEROTYPE_CONSTRAINTS
    shell:
        """
        tsv-filter -H --str-eq ncbi_serotype:{wildcards.serotype} {input.metadata} > {output.serotype_metadata}
        """