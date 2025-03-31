"""
This part of the workflow handles curating the data into standardized
formats and expects input file

    ndjson      = data/ncbi.ndjson

This will produce output files as

    metadata = "results/metadata_all.tsv"
    sequences = "results/sequences_all.fasta"

Parameters are expected to be defined in `config.curate`.
"""


def format_field_map(field_map: dict[str, str]) -> str:
    """
    Format dict to `"key1"="value1" "key2"="value2"...` for use in shell commands.
    """
    return " ".join([f'"{key}"="{value}"' for key, value in field_map.items()])

# This curate pipeline is based on existing pipelines for pathogen repos using NCBI data.
# You may want to add and/or remove steps from the pipeline for custom metadata
# curation for your pathogen. Note that the curate pipeline is streaming NDJSON
# records between scripts, so any custom scripts added to the pipeline should expect
# the input as NDJSON records from stdin and output NDJSON records to stdout.
# The final step of the pipeline should convert the NDJSON records to two
# separate files: a metadata TSV and a sequences FASTA.
rule curate:
    input:
        sequences_ndjson="data/ncbi.ndjson",
        geolocation_rules=config["curate"]["local_geolocation_rules"],
        annotations=config["curate"]["annotations"],
        manual_mapping="defaults/host_hostgenus_hosttype_map.tsv",
    output:
        metadata="data/all_metadata_curated.tsv",
        sequences="results/sequences_all.fasta",
    log:
        "logs/curate.txt",
    benchmark:
        "benchmarks/curate.txt",
    params:
        field_map=format_field_map(config["curate"]["field_map"]),
        strain_regex=config["curate"]["strain_regex"],
        strain_backup_fields=config["curate"]["strain_backup_fields"],
        date_fields=config["curate"]["date_fields"],
        expected_date_formats=config["curate"]["expected_date_formats"],
        genbank_location_field=config["curate"]["genbank_location_field"],
        articles=config["curate"]["titlecase"]["articles"],
        abbreviations=config["curate"]["titlecase"]["abbreviations"],
        titlecase_fields=config["curate"]["titlecase"]["fields"],
        authors_field=config["curate"]["authors_field"],
        authors_default_value=config["curate"]["authors_default_value"],
        abbr_authors_field=config["curate"]["abbr_authors_field"],
        annotations_id=config["curate"]["annotations_id"],
        serotype_field=config["curate"]["serotype_field"],
        id_field=config["curate"]["output_id_field"],
        sequence_field=config["curate"]["output_sequence_field"],
    shell:
        """
        (cat {input.sequences_ndjson} \
            | augur curate rename \
                --field-map {params.field_map} \
            | augur curate normalize-strings \
            | augur curate transform-strain-name \
                --strain-regex {params.strain_regex} \
                --backup-fields {params.strain_backup_fields} \
            | augur curate format-dates \
                --date-fields {params.date_fields} \
                --expected-date-formats {params.expected_date_formats} \
            | augur curate parse-genbank-location \
                --location-field {params.genbank_location_field} \
            | augur curate titlecase \
                --titlecase-fields {params.titlecase_fields} \
                --articles {params.articles} \
                --abbreviations {params.abbreviations} \
            | augur curate abbreviate-authors \
                --authors-field {params.authors_field} \
                --default-value {params.authors_default_value} \
                --abbr-authors-field {params.abbr_authors_field} \
            | augur curate apply-geolocation-rules \
                --geolocation-rules {input.geolocation_rules} \
            | ./scripts/infer-dengue-serotype.py \
                --out-col {params.serotype_field} \
            | ./scripts/transform-new-fields \
                --map-tsv {input.manual_mapping} \
                --map-id host \
                --metadata-id host \
                --map-fields host_genus host_type \
                --pass-through true \
            | augur curate apply-record-annotations \
                --annotations {input.annotations} \
                --id-field {params.annotations_id} \
                --output-metadata {output.metadata} \
                --output-fasta {output.sequences} \
                --output-id-field {params.id_field} \
                --output-seq-field {params.sequence_field} ) 2>> {log}
        """

rule add_metadata_columns:
    """Add columns to metadata
    Notable columns:
    - [NEW] url: URL linking to the NCBI GenBank record ('https://www.ncbi.nlm.nih.gov/nuccore/*').
    """
    input:
        metadata="data/all_metadata_curated.tsv",
    output:
        metadata = temp("data/all_metadata_added.tsv")
    params:
        accession=config['curate']['genbank_accession']
    shell:
        """
        csvtk mutate2 -t \
          -n url \
          -e '"https://www.ncbi.nlm.nih.gov/nuccore/" + ${params.accession}' \
          {input.metadata} \
        > {output.metadata}
        """

rule subset_metadata:
    input:
        metadata="data/all_metadata_added.tsv",
    output:
        subset_metadata="data/metadata_all.tsv",
    params:
        metadata_fields=",".join(config["curate"]["metadata_columns"]),
    shell:
        """
        tsv-select -H -f {params.metadata_fields} \
            {input.metadata} > {output.subset_metadata}
        """
