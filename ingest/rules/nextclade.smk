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
    1. Capture the alignment
    2. Capture the translations of gene(s) of interest

    Note: If using --cds-selection, only the thoese genes are reported in the failedCdses column
    """
    input:
        sequences="results/sequences_{serotype}.fasta",
        dataset="../nextclade_data/{serotype}",
    output:
        nextclade_denvX="data/nextclade_results/nextclade_{serotype}.tsv",
        nextclade_alignment="results/aligned_{serotype}.fasta",
        nextclade_translations=expand("data/translations/{{serotype}}/{gene}/seqs.gene.fasta", gene=config["nextclade"]["gene"]),
    threads: 4
    params:
        min_length=config["nextclade"]["min_length"],
        min_seed_cover=config["nextclade"]["min_seed_cover"],
        output_translations = lambda wildcards: f"data/translations/{wildcards.serotype}/{{cds}}/seqs.gene.fasta",
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
          --output-fasta {output.nextclade_alignment} \
          --output-translations {params.output_translations} \
          {input.sequences}
        """

rule concat_nextclade_subtype_results:
    """
    Concatenate all the nextclade results for dengue subtype classification
    """
    input:
        nextclade_results_files = expand("data/nextclade_results/nextclade_{serotype}.tsv", serotype=SUPPORTED_NEXTCLADE_SEROTYPES),
    output:
        nextclade_subtypes="results/nextclade_subtypes.tsv",
    params:
        input_nextclade_fields=",".join([f'{key}' for key, value in config["nextclade"]["field_map"].items()]),
        output_nextclade_fields=",".join([f'{value}' for key, value in config["nextclade"]["field_map"].items()]),
    shell:
        """
        echo "{params.output_nextclade_fields}" \
        | tr ',' '\t' \
        > {output.nextclade_subtypes}

        tsv-select -H -f "{params.input_nextclade_fields}" {input.nextclade_results_files} \
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
        metadata_all="data/metadata_nextclade.tsv",
    params:
        id_field=list(config["nextclade"]["field_map"].values())[0],
        output_nextclade_fields=",".join([f'{value}' for key, value in config["nextclade"]["field_map"].items()][1:]),
    shell:
        """
        tsv-join -H \
            --filter-file {input.nextclade_subtypes} \
            --key-fields {params.id_field} \
            --append-fields {params.output_nextclade_fields} \
            --write-all ? \
            {input.metadata} \
        > {output.metadata_all}
        """

rule calculate_gene_coverage:
    """
    Calculate the coverage of the gene of interest
    """
    input:
        nextclade_translation="data/translations/{serotype}/{gene}/seqs.gene.fasta",
    output:
        gene_coverage="data/translations/{serotype}/{gene}/gene_coverage.tsv",
    wildcard_constraints:
        serotype=SEROTYPE_CONSTRAINTS,
    shell:
        """
        python bin/calculate-gene-converage-from-nextclade-translation.py \
          --fasta {input.nextclade_translation} \
          --out-col {wildcards.gene}_coverage \
          > {output.gene_coverage}
        """

rule aggregate_gene_coverage_by_gene:
    """
    Aggregate the gene coverage results by gene
    """
    input:
        gene_coverage=expand("data/translations/{serotype}/{{gene}}/gene_coverage.tsv", serotype=SUPPORTED_NEXTCLADE_SEROTYPES),
    output:
        gene_coverage_all="results/{gene}/gene_coverage_all.tsv",
    shell:
        """
        tsv-append -H {input.gene_coverage} > {output.gene_coverage_all}
        """

rule append_gene_coverage_columns:
    """
    Append the gene coverage results to the metadata
    """
    input:
        metadata="data/metadata_nextclade.tsv",
        gene_coverage=expand("results/{gene}/gene_coverage_all.tsv", gene=config["nextclade"]["gene"])
    output:
        metadata_all="results/metadata_all.tsv",
    params:
        id_field=config["curate"]["id_field"],
    shell:
        """
        cp {input.metadata} {output.metadata_all}
        for FILE in {input.gene_coverage}; do
            tsv-join -H \
                --filter-file $FILE \
                --key-fields {params.id_field} \
                --append-fields '*_coverage' \
                --write-all 0 \
                {output.metadata_all} \
            > results/temp_aggregate_gene_coverage.tsv
            mv results/temp_aggregate_gene_coverage.tsv {output.metadata_all}
        done
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
