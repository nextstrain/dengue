"""
This part of the workflow handles splitting the data by serotype either based on the 
NCBI metadata or Nextclade dataset. Could use both if necessary to cross-validate.

    metadata = "data/metadata_all.tsv"
    sequences = "results/sequences_all.fasta"

This will produce output files as

    sequences_{serotype} = "results/sequences_{serotype}.fasta"

Parameters are expected to be defined in `config.curate`.
"""

rule split_by_serotype_genbank:
    """
    Split the data by serotype based on the NCBI Genbank metadata.
    """
    input:
        metadata = "data/all/metadata.tsv",
        sequences = "results/all/sequences.fasta"
    output:
        sequences = "results/{serotype}/sequences.fasta"
    params:
        id_field = config["curate"]["id_field"],
        serotype_field = config["curate"]["serotype_field"]
    shell:
        """
        augur filter \
          --sequences {input.sequences} \
          --metadata {input.metadata} \
          --metadata-id-columns {params.id_field} \
          --query "{params.serotype_field}=='{wildcards.serotype}'" \
          --output-sequences {output.sequences}
        """
