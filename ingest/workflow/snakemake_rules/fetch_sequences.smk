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


rule fetch_from_genbank:
    output:
        genbank_ndjson="data/genbank.ndjson",
    params:
        serotype_tax_id=download_serotype,
        csv_to_ndjson_url="https://raw.githubusercontent.com/nextstrain/monkeypox/644d07ebe3fa5ded64d27d0964064fb722797c5d/ingest/bin/csv-to-ndjson",
    shell:
        """
        # (1) Pick curl or wget based on availability    
        if which curl > /dev/null; then
            download_cmd="curl -fsSL --output"
        elif which wget > /dev/null; then
            download_cmd="wget -O"
        else
            echo "ERROR: Neither curl nor wget found. Please install one of them."
            exit 1
        fi

        # (2) Download the required scripts if not already present
        [[ -d bin ]] || mkdir bin
        [[ -f bin/csv-to-ndjson ]] || $download_cmd bin/csv-to-ndjson {params.csv_to_ndjson_url}
        chmod +x bin/*

        # (3) Fetch sequences from GenBank
        ./bin/fetch-from-genbank {params.serotype_tax_id} > {output.genbank_ndjson}
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
