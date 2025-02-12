"""
This part of the workflow handles running Nextclade on the curated metadata
and sequences.
REQUIRED INPUTS:
    metadata    = data/metadata_all.tsv
    sequences   = results/sequences_{serotype}.fasta
    nextclade_datasets = ../nextclade_data/{serotype}
OUTPUTS:
    metadata        = results/metadata_{serotype}.tsv
    nextclade       = results/nextclade_genotypes.tsv
See Nextclade docs for more details on usage, inputs, and outputs if you would
like to customize the rules:
https://docs.nextstrain.org/projects/nextclade/page/user/nextclade-cli.html
"""

SUPPORTED_NEXTCLADE_SEROTYPES = ['denv1', 'denv2', 'denv3', 'denv4']
SEROTYPE_CONSTRAINTS = '|'.join(SUPPORTED_NEXTCLADE_SEROTYPES)

rule get_nextclade_dataset:
    """Download Nextclade dataset"""
    output:
        dataset="data/nextclade_data/v-gen-lab/{serotype}.zip",
    params:
        dataset_name=lambda wildcards: f"community/v-gen-lab/dengue/{wildcards.serotype}",
    wildcard_constraints:
        serotype=SEROTYPE_CONSTRAINTS,
    shell:
        r"""
        nextclade3 dataset get \
            --name={params.dataset_name:q} \
            --output-zip={output.dataset} \
            --verbose
        """

rule run_nextclade:
    """
    For each type, classify into the appropriate Dengue genotype
    1. Capture the alignment
    2. Capture the translations of gene(s) of interest

    Note: If using --cds-selection, only the thoese genes are reported in the failedCdses column
    """
    input:
        sequences="results/sequences_{serotype}.fasta",
        dataset="data/nextclade_data/v-gen-lab/{serotype}.zip",
    output:
        nextclade="results/v-gen-lab/{serotype}/nextclade.tsv",
        alignment="results/v-gen-lab/{serotype}/alignment.fasta",
        translations=expand("data/v-gen-lab/{{serotype}}/translations/{gene}/seqs.gene.fasta", gene=config["nextclade"]["gene"]),
    threads: 4
    params:
        min_length=config["nextclade"]["min_length"],
        min_seed_cover=config["nextclade"]["min_seed_cover"],
        output_translations = lambda wildcards: f"data/v-gen-lab/{wildcards.serotype}/translations/{{cds}}/seqs.gene.fasta",
    log:
        "logs/v-gen-lab/{serotype}/run_nextclade.txt",
    benchmark:
        "benchmarks/v-gen-lab/{serotype}/run_nextclade.txt",
    wildcard_constraints:
        serotype=SEROTYPE_CONSTRAINTS
    shell:
        r"""
        nextclade3 run \
            --input-dataset {input.dataset} \
            -j {threads} \
            --output-tsv {output.nextclade} \
            --min-length {params.min_length} \
            --min-seed-cover {params.min_seed_cover} \
            --silent \
            --output-fasta {output.alignment} \
            --output-translations {params.output_translations} \
            {input.sequences} \
          &> {log:q}
        """

rule concat_genotype_nextclade_results:
    """
    Concatenate all the nextclade results for dengue genotype classification
    """
    input:
        nextclade_files=expand("results/v-gen-lab/{serotype}/nextclade.tsv", serotype=SUPPORTED_NEXTCLADE_SEROTYPES),
    output:
        genotype_nextclade=temp("results/v-gen-lab/nextclade_metadata.tsv"),
    params:
        input_nextclade_fields=",".join([f'{key}' for key, value in config["nextclade"]["field_map"].items()]),
        output_nextclade_fields=",".join([f'{value}' for key, value in config["nextclade"]["field_map"].items()]),
    log:
        "logs/v-gen-lab/concat_genotype_nextclade_results.txt",
    benchmark:
        "benchmarks/v-gen-lab/concat_genotype_nextclade_results.txt",
    shell:
        """
        echo "{params.output_nextclade_fields}" \
        | tr ',' '\t' \
        > {output.genotype_nextclade}

        tsv-select -H -f "{params.input_nextclade_fields}" {input.nextclade_files} \
        | awk 'NR>1 {{print}}' \
        >> {output.genotype_nextclade}
        """

rule calculate_gene_coverage:
    """
    Calculate the coverage of the gene of interest
    """
    input:
        nextclade_translation="data/v-gen-lab/{serotype}/translations/{gene}/seqs.gene.fasta",
    output:
        gene_coverage="data/v-gen-lab/{serotype}/translations/{gene}/gene_coverage.tsv",
    wildcard_constraints:
        serotype=SEROTYPE_CONSTRAINTS,
    params:
        id_field=config["curate"]["output_id_field"],
    log:
        "logs/v-gen-lab/{serotype}/{gene}/calculate_gene_coverage.txt",
    benchmark:
        "benchmarks/v-gen-lab/{serotype}/{gene}/calculate_gene_coverage.txt",
    shell:
        """
        python scripts/calculate-gene-converage-from-nextclade-translation.py \
          --fasta {input.nextclade_translation} \
          --out-id {params.id_field} \
          --out-col {wildcards.gene}_coverage \
          > {output.gene_coverage}
        """

rule aggregate_gene_coverage_by_gene:
    """
    Aggregate the gene coverage results by gene
    """
    input:
        gene_coverage=expand("data/v-gen-lab/{serotype}/translations/{{gene}}/gene_coverage.tsv", serotype=SUPPORTED_NEXTCLADE_SEROTYPES),
    output:
        gene_coverage_all="results/{gene}/gene_coverage_all.tsv",
    log:
        "logs/v-gen-lab/{gene}/aggregate_gene_coverage_by_gene.txt",
    benchmark:
        "benchmarks/v-gen-lab/{gene}/aggregate_gene_coverage_by_gene.txt",
    shell:
        """
        tsv-append -H {input.gene_coverage} > {output.gene_coverage_all}
        """

rule combine_gene_coverage_columns:
    """
    Append the gene coverage results to the metadata
    Since gene coverage values should be a value between 0 and 1, empty fields should be filled with 0's
    """
    input:
        metadata="data/metadata_all.tsv",
        gene_coverage=expand("results/{gene}/gene_coverage_all.tsv", gene=config["nextclade"]["gene"])
    output:
        gene_coverage_combined="results/gene_coverage_combined.tsv",
    params:
        id_field=config["curate"]["output_id_field"],
    log:
        "logs/v-gen-lab/combine_gene_coverage_columns.txt",
    benchmark:
        "benchmarks/v-gen-lab/combine_gene_coverage_columns.txt",
    shell:
        """
        tsv-select -H -f "{params.id_field}" {input.metadata} > {output.gene_coverage_combined}
        for FILE in {input.gene_coverage}; do
            tsv-join -H \
                --filter-file $FILE \
                --key-fields {params.id_field} \
                --append-fields '*_coverage' \
                --write-all 0 \
                {output.gene_coverage_combined} \
            > results/temp_aggregate_gene_coverage.tsv
            mv results/temp_aggregate_gene_coverage.tsv {output.gene_coverage_combined}
        done
        """

rule append_nextclade_columns:
    """
    Append the nextclade results to the metadata
    """
    input:
        metadata="data/metadata_all.tsv",
        genotype_nextclade="results/v-gen-lab/nextclade_metadata.tsv",
    output:
        metadata="data/metadata_nextclade.tsv",
    params:
        output_nextclade_fields=",".join([f'{value}' for key, value in config["nextclade"]["field_map"].items()][1:]),
        metadata_id_field=config["curate"]["output_id_field"],
        nextclade_id_field=config["nextclade"]["id_field"],
    log:
        "logs/v-gen-lab/append_nextclade_columns.txt",
    benchmark:
        "benchmarks/v-gen-lab/append_nextclade_columns.txt",
    shell:
        """
        augur merge \
            --metadata \
                metadata={input.metadata:q} \
                nextclade={input.genotype_nextclade:q} \
            --metadata-id-columns \
                metadata={params.metadata_id_field:q} \
                nextclade={params.nextclade_id_field:q} \
            --output-metadata {output.metadata:q} \
            --no-source-columns \
        &> {log:q}
        """

rule append_gene_coverage_columns:
    """
    Append the gene_coverage results to the metadata
    """
    input:
        metadata="data/metadata_nextclade.tsv",
        gene_coverage="results/gene_coverage_combined.tsv",
    output:
        metadata="results/metadata_all.tsv",
    params:
        id_field=config["curate"]["output_id_field"],
    log:
        "logs/v-gen-lab/append_gene_coverage_columns.txt",
    benchmark:
        "benchmarks/v-gen-lab/append_gene_coverage_columns.txt",
    shell:
        """
        augur merge \
            --metadata \
                metadata={input.metadata:q} \
                gene_coverage={input.gene_coverage:q} \
            --metadata-id-columns \
                metadata={params.id_field:q} \
                gene_coverage={params.id_field:q} \
            --output-metadata {output.metadata:q} \
            --no-source-columns \
        &> {log:q}
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
    params:
        serotype_field=config["curate"]["serotype_field"],
    log:
        "logs/split_metadata_by_serotype_{serotype}.txt",
    benchmark:
        "benchmarks/split_metadata_by_serotype_{serotype}.txt",
    shell:
        """
        tsv-filter -H --str-eq {params.serotype_field}:{wildcards.serotype} {input.metadata} > {output.serotype_metadata}
        """