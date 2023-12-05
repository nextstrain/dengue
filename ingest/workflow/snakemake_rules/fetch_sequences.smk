"""
This part of the workflow handles fetching sequences from various sources.
Uses `config.sources` to determine which sequences to include in final output.

Currently only fetches sequences from GenBank, but other sources can be
defined in the config. If adding other sources, add a new rule upstream
of rule `fetch_all_sequences` to create the file `data/{source}.ndjson` or the
file must exist as a static file in the repo.

Produces final output as

    sequences_ndjson = "data/sequences.ndjson"

"""


rule fetch_ncbi_dataset_package:
    output:
        dataset_package=temp("data/ncbi_dataset.zip"),
    retries: 5  # Requires snakemake 7.7.0 or later
    benchmark:
        "benchmarks/fetch_ncbi_dataset_package.txt"
    params:
        ncbi_taxon_id=config["ncbi_taxon_id"],
    shell:
        """
        datasets download virus genome taxon {params.ncbi_taxon_id} \
            --no-progressbar \
            --filename {output.dataset_package}
        """


rule extract_ncbi_dataset_sequences:
    input:
        dataset_package="data/ncbi_dataset.zip",
    output:
        ncbi_dataset_sequences=temp("data/ncbi_dataset_sequences.fasta"),
    benchmark:
        "benchmarks/extract_ncbi_dataset_sequences.txt"
    shell:
        """
        unzip -jp {input.dataset_package} \
            ncbi_dataset/data/genomic.fna > {output.ncbi_dataset_sequences}
        """


rule format_ncbi_dataset_report:
    # Formats the headers to match the NCBI mnemonic names
    input:
        dataset_package="data/ncbi_dataset.zip",
    output:
        ncbi_dataset_tsv=temp("data/ncbi_dataset_report.tsv"),
    params:
        ncbi_datasets_fields=",".join(config["ncbi_datasets_fields"]),
    benchmark:
        "benchmarks/format_ncbi_dataset_report.txt"
    shell:
        """
        dataformat tsv virus-genome \
            --package {input.dataset_package} \
            --fields {params.ncbi_datasets_fields:q} \
            --elide-header \
            | csvtk add-header -t -l -n {params.ncbi_datasets_fields:q} \
            | csvtk rename -t -f accession -n accession-rev \
            | csvtk -tl mutate -f accession-rev -n accession -p "^(.+?)\." \
            | tsv-select -H -f accession --rest last \
            > {output.ncbi_dataset_tsv}
        """


rule format_ncbi_datasets_ndjson:
    input:
        ncbi_dataset_sequences="data/ncbi_dataset_sequences.fasta",
        ncbi_dataset_tsv="data/ncbi_dataset_report.tsv",
    output:
        ndjson="data/genbank.ndjson",
    params:
        ncbi_datasets_fields=",".join(config["ncbi_datasets_fields"]),
    log:
        "logs/format_ncbi_datasets_ndjson.txt",
    benchmark:
        "benchmarks/format_ncbi_datasets_ndjson.txt"
    shell:
        """
        augur curate passthru \
            --metadata {input.ncbi_dataset_tsv} \
            --fasta {input.ncbi_dataset_sequences} \
            --seq-id-column accession-rev \
            --seq-field sequence \
            --unmatched-reporting warn \
            --duplicate-reporting warn \
            2> {log} > {output.ndjson}
        """


def _get_all_sources(wildcards):
    return [f"data/{source}.ndjson" for source in config["sources"]]


rule fetch_all_sequences:
    input:
        all_sources=_get_all_sources,
    output:
        sequences_ndjson="data/sequences.ndjson",
    shell:
        """
        cat {input.all_sources} > {output.sequences_ndjson}
        """
