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

rule nextclade_denvX:
    """
    For each type, classify into the appropriate subtype
    """
    input:
        sequences="results/sequences_denv{x}.fasta",
        dataset="../nextclade_data/denv{x}",
    output:
        nextclade_denvX="data/nextclade_results/nextclade_denv{x}.tsv",
    threads: 4
    shell:
        """
        nextclade run \
          --input-dataset {input.dataset} \
          -j {threads} \
          --output-tsv {output.nextclade_denvX} \
          --min-match-rate 0.01 \
          --silent \
          {input.sequences}
        """

rule join_nextclade_clades:
    """
    Merge all the nextclade results into metadata and split metadata
    """
    input:
        metadata="data/metadata_all.tsv",
        nextclade_denv1="data/nextclade_results/nextclade_denv1.tsv",
        nextclade_denv2="data/nextclade_results/nextclade_denv2.tsv",
        nextclade_denv3="data/nextclade_results/nextclade_denv3.tsv",
        nextclade_denv4="data/nextclade_results/nextclade_denv4.tsv",
    output:
        metadata_all="results/metadata_all.tsv",
        metadata_denv1="results/metadata_denv1.tsv",
        metadata_denv2="results/metadata_denv2.tsv",
        metadata_denv3="results/metadata_denv3.tsv",
        metadata_denv4="results/metadata_denv4.tsv",
    shell:
        """
        echo "genbank_accession,nextclade_subtype,nextclade_type" \
        | tr ',' '\t' \
        > results/nextclade_subtype.tsv

        tsv-select -H -f "seqName,clade" {input.nextclade_denv1} \
        | awk 'NR>1 {{print $0"\tDENV1"}}' \
        >> results/nextclade_subtype.tsv
        tsv-select -H -f "seqName,clade" {input.nextclade_denv2} \
        | awk 'NR>1 {{print $0"\tDENV2"}}' \
        >> results/nextclade_subtype.tsv
        tsv-select -H -f "seqName,clade" {input.nextclade_denv3} \
        | awk 'NR>1 {{print $0"\tDENV3"}}' \
        >> results/nextclade_subtype.tsv
        tsv-select -H -f "seqName,clade" {input.nextclade_denv4} \
        | awk 'NR>1 {{print $0"\tDENV4"}}' \
        >> results/nextclade_subtype.tsv

        tsv-join -H \
            --filter-file results/nextclade_subtype.tsv \
            --key-fields genbank_accession \
            --append-fields 'nextclade_subtype,nextclade_type' \
            --write-all ? \
            {input.metadata} \
        > {output.metadata_all}

        tsv-filter -H --str-eq ncbi_serotype:denv1 {output.metadata_all} > {output.metadata_denv1}
        tsv-filter -H --str-eq ncbi_serotype:denv2 {output.metadata_all} > {output.metadata_denv2}
        tsv-filter -H --str-eq ncbi_serotype:denv3 {output.metadata_all} > {output.metadata_denv3}
        tsv-filter -H --str-eq ncbi_serotype:denv4 {output.metadata_all} > {output.metadata_denv4}
        """
