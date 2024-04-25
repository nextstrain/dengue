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


rule prepare_auspice_config:
    """Prepare the auspice config file for each serotypes"""
    output:
        auspice_config="results/config/auspice_config_{serotype}.json",
    params:
        replace_clade_key="clade_membership",
        replace_clade_title=lambda wildcard: r"Serotype" if wildcard.serotype in ['all'] else r"DENV genotype",
    run:
        data = {
            "title": "Real-time tracking of dengue virus evolution",
            "maintainers": [
              {"name": "the Nextstrain team", "url": "https://nextstrain.org/team"}
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
                "key": params.replace_clade_key,
                "title": params.replace_clade_title,
                "type": "categorical"
              },
              {
                "key": "nextclade_subtype",
                "title": "Nextclade genotype",
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
              "distance_measure": "div"
            },
            "filters": [
              "country",
              "region",
              "author"
            ]
          }

        with open(output.auspice_config, 'w') as fh:
            json.dump(data, fh, indent=2)


rule export:
    """Exporting data files for auspice"""
    input:
        tree = "results/tree_{serotype}.nwk",
        metadata = "data/metadata_{serotype}.tsv",
        branch_lengths = "results/branch-lengths_{serotype}.json",
        traits = "results/traits_{serotype}.json",
        clades = "results/clades_{serotype}.json",
        nt_muts = "results/nt-muts_{serotype}.json",
        aa_muts = "results/aa-muts_{serotype}.json",
        auspice_config = "results/config/auspice_config_{serotype}.json",
    output:
        auspice_json = "results/raw_dengue_{serotype}.json"
    params:
        strain_id = config.get("strain_id_field", "strain"),
    shell:
        """
        augur export v2 \
            --tree {input.tree} \
            --metadata {input.metadata} \
            --metadata-id-columns {params.strain_id} \
            --node-data {input.branch_lengths} {input.traits} {input.clades} {input.nt_muts} {input.aa_muts} \
            --auspice-config {input.auspice_config} \
            --include-root-sequence-inline \
            --output {output.auspice_json}
        """

rule final_strain_name:
    input:
        auspice_json="results/raw_dengue_{serotype}.json",
        metadata="data/metadata_{serotype}.tsv",
    output:
        auspice_json="auspice/dengue_{serotype}_genome.json"
    params:
        strain_id=config.get("strain_id_field", "strain"),
        display_strain_field=config.get("display_strain_field", "strain"),
    shell:
        """
        python3 bin/set_final_strain_name.py \
            --metadata {input.metadata} \
            --metadata-id-columns {params.strain_id} \
            --input-auspice-json {input.auspice_json} \
            --display-strain-name {params.display_strain_field} \
            --output {output.auspice_json}
        """
