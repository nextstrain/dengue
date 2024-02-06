"""
This part of the workflow handles splitting the data by serotype either based on the 
NCBI metadata or Nextclade dataset. Could use both if necessary to cross-validate.

    metadata = "results/metadata_all.tsv"
    sequences = "results/sequences_all.fasta"

This will produce output files as

    metadata_{serotype} = "results/metadata_{serotype}.tsv"
    sequences_{serotype} = "results/sequences_{serotype}.fasta"

Parameters are expected to be defined in `config.transform`.
"""

rule split_by_ncbi_serotype:
    """
    Split the data by serotype based on the NCBI metadata.
    """
    input:
        metadata = "results/metadata_all.tsv",
        sequences = "results/sequences_all.fasta"
    output:
        metadata = "results/metadata_{serotype}.tsv",
        sequences = "results/sequences_{serotype}.fasta"
    params:
        id_field = config["transform"]["id_field"]
    shell:
        """
        augur filter \
          --sequences {input.sequences} \
          --metadata {input.metadata} \
          --metadata-id-columns {params.id_field} \
          --query "ncbi_serotype=='{wildcards.serotype}'" \
          --output-sequences {output.sequences} \
          --output-metadata {output.metadata}
        """
