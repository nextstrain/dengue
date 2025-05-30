"""
This part of the workflow collects the phylogenetic tree and annotations to
export a Nextstrain dataset.
REQUIRED INPUTS:
    metadata        = data/metadata_all.tsv
    tree            = results/tree.nwk
    branch_lengths  = results/branch_lengths.json
    node_data       = results/*.json
OUTPUTS:
    auspice_json = auspice/${build_name}.json
    There are optional sidecar JSON files that can be exported as part of the dataset.
    See Nextstrain's data format docs for more details on sidecar files:
    https://docs.nextstrain.org/page/reference/data-formats.html
This part of the workflow usually includes the following steps:
    - augur export v2
    - augur frequencies
See Augur's usage docs for these commands for more details.
"""

import json


rule colors:
    input:
        color_schemes = "../phylogenetic/defaults/color_schemes.tsv",
        color_orderings = "../phylogenetic/defaults/color_orderings.tsv",
        metadata = "data/metadata_{serotype}.tsv",
    output:
        colors = "results/colors_{serotype}.tsv"
    benchmark:
        "benchmarks/{serotype}/colors.txt"
    shell:
        """
        python3 ../phylogenetic/scripts/assign-colors.py \
            --color-schemes {input.color_schemes} \
            --ordering {input.color_orderings} \
            --metadata {input.metadata} \
            --output {output.colors}
        """


rule prepare_auspice_config:
    """Prepare the auspice config file for each serotypes"""
    output:
        auspice_config="results/config/{gene}/auspice_config_{serotype}.json",
    benchmark:
        "benchmarks/{serotype}/{gene}/prepare_auspice_config.txt"
    params:
        replace_clade_key=lambda wildcard: r"clade_membership" if wildcard.gene in ['genome'] else r"genotype_nextclade",
        replace_clade_title=lambda wildcard: r"Serotype" if wildcard.serotype in ['all'] else r"Dengue Genotype (Nextclade)",
    run:
        data = {
            "title": "Nextclade dataset for dengue virus evolution",
            "maintainers": [
              {"name": "the Nextstrain team", "url": "https://nextstrain.org/team"}
            ],
            "data_provenance": [
              {
                "name": "GenBank",
                "url": "https://www.ncbi.nlm.nih.gov/genbank/"
              }
            ],
            "build_url": "https://github.com/nextstrain/dengue",
            "colorings": [
              {
                "key": "gt",
                "title": "Genotype",
                "type": "categorical"
              },
              {
                "key": "num_date",
                "title": "Date",
                "type": "continuous"
              },
              {
                "key": "country",
                "title": "Country",
                "type": "categorical"
              },
              {
                "key": "region",
                "title": "Region",
                "type": "categorical"
              },
              {
                "key": "genotype_nextclade",
                "title": "Dengue Genotype (Nextclade)",
                "type": "categorical"
              },
              {
                "key": "serotype_genbank",
                "title": "Serotype (Genbank metadata)",
                "type": "categorical"
              }
            ],
            "geo_resolutions": [
              "country",
              "region"
            ],
            "display_defaults": {
              "map_triplicate": True,
              "color_by": params.replace_clade_key,
              "tip_label": "strain"
            },
            "filters": [
              "country",
              "region",
              "author"
            ],
            "metadata_columns": [
              "strain"
            ]
          }

        # During genome/dengue_all workflows, clade membership represents Serotype
        # While genome/dengue_denvX workflows, clade_membership represents the more detailed Genotype
        if params.replace_clade_key == 'clade_membership':
            if wildcards.gene in ['genome'] and wildcards.serotype in ['all']:
                clade_membership_title="Serotype (Nextstrain)"
            else:
                clade_membership_title="Dengue Genotype (Nextstrain)"

            data["colorings"].append({
                "key": "clade_membership",
                "title": clade_membership_title,
                "type": "categorical"
            })
        else:
            # During E/dengue_all workflows, default color by Serotype
            if wildcards.serotype in ['all']:
                data["display_defaults"]["color_by"]="serotype_genbank"

        with open(output.auspice_config, 'w') as fh:
            json.dump(data, fh, indent=2)


rule export:
    """Exporting data files for auspice"""
    input:
        tree = "results/{gene}/tree_{serotype}.nwk",
        metadata = "data/metadata_{serotype}.tsv",
        branch_lengths = "results/{gene}/branch-lengths_{serotype}.json",
        traits = "results/{gene}/traits_{serotype}.json",
        clades = lambda wildcard: "results/{gene}/clades_{serotype}.json" if wildcard.gene in ['genome'] else [],
        nt_muts = "results/{gene}/nt-muts_{serotype}.json",
        aa_muts = "results/{gene}/aa-muts_{serotype}.json",
        auspice_config = "results/config/{gene}/auspice_config_{serotype}.json",
        colors = "results/colors_{serotype}.tsv",
    output:
        auspice_json = "auspice/dengue_{serotype}_{gene}.json"
    benchmark:
        "benchmarks/{serotype}/{gene}/export.txt"
    params:
        strain_id = config.get("strain_id_field", "strain"),
    shell:
        """
        augur export v2 \
            --tree {input.tree} \
            --metadata {input.metadata} \
            --metadata-id-columns {params.strain_id} \
            --node-data {input.branch_lengths} {input.traits} {input.clades} {input.nt_muts} {input.aa_muts} \
            --colors {input.colors} \
            --auspice-config {input.auspice_config} \
            --include-root-sequence-inline \
            --output {output.auspice_json}
        """
