"""
This part of the workflow prepares reference files and sequences for constructing the gene phylogenetic trees.
REQUIRED INPUTS:
    reference   = path to reference sequence or genbank
    sequences   = path to all sequences from which gene sequences can be extracted

OUTPUTS:
    gene_fasta = reference fasta for the gene (e.g. E gene)
    gene_genbank = reference genbank for the gene (e.g. E gene)
    sequences = sequences with gene sequences extracted and aligned to the reference gene sequence
This part of the workflow usually includes the following steps:
    - newreference.py: Creates new gene genbank and gene reference FASTA from the whole genome reference genbank
    - nextclade: Aligns sequences to the reference gene sequence and extracts the gene sequences to ensure the reference files are valid
See Nextclade or script usage docs for these commands for more details.
"""

ruleorder: align_and_extract_E > decompress

rule generate_E_reference_files:
    """
    Generating reference files for the E gene
    """
    input:
        reference = "defaults/reference_{serotype}_genome.gb",
    output:
        fasta = "results/defaults/reference_{serotype}_E.fasta",
        genbank = "results/defaults/reference_{serotype}_E.gb",
    params:
        gene = "E",
    shell:
        """
        python3 scripts/newreference.py \
            --reference {input.reference} \
            --output-fasta {output.fasta} \
            --output-genbank {output.genbank} \
            --gene {params.gene}
        """

rule align_and_extract_E:
    """
    Cutting sequences to the length of the E gene reference sequence
    """
    input:
        sequences = "data/sequences_{serotype}.fasta",
        reference = "results/defaults/reference_{serotype}_E.fasta"
    output:
        sequences = "results/E/sequences_{serotype}.fasta"
    params:
        min_length = 1000,
    shell:
        """
        nextclade run \
           -j 1 \
           --input-ref {input.reference} \
           --output-fasta {output.sequences} \
           --min-seed-cover 0.01 \
           --min-length {params.min_length} \
           --silent \
           {input.sequences}
        """
