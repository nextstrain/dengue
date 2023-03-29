"""
This part of the workflow handles fetching sequences from various sources.
Uses `config.sources` to determine which sequences to include in final output.

Currently only fetches sequences from GenBank, but other sources can be
defined in the config. If adding other sources, add a new rule upstream
of rule `fetch_all_sequences` to create the file `data/{source}.ndjson` or the
file must exist as a static file in the repo.

Produces final output as

    sequences_ndjson = "data/sequences_{serotype}.ndjson"

"""
workflow.global_resources.setdefault("concurrent_deploys", 2)

def download_serotype(wildcards):
    serotype = {
        'all': '12637',
        'denv1': '11053',
        'denv2': '11060',
        'denv3': '11069',
        'denv4': '11070'
    }
    return serotype[wildcards.serotype]

rule fetch_from_genbank:
    resources:
        concurrent_deploys=1,
    output:
        genbank_ndjson="data/genbank_{serotype}.ndjson",
    params:
        serotype_tax_id=download_serotype,
    shell:
        """
        ./bin/fetch-from-genbank {params.serotype_tax_id} > {output.genbank_ndjson}
        """


def _get_all_sources(wildcards):
    return [f"data/{source}_{wildcards.serotype}.ndjson" for source in config["sources"]]


rule fetch_all_sequences:
    input:
        all_sources=_get_all_sources,
    output:
        sequences_ndjson="data/sequences_{serotype}.ndjson",
    shell:
        """
        cat {input.all_sources} > {output.sequences_ndjson}
        """
