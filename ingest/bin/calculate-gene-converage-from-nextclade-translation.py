#! /usr/bin/env python3

import argparse
from sys import stderr

from Bio import SeqIO
import re


def parse_args():
    parser = argparse.ArgumentParser(
        description="Calculate gene coverage from amino acid sequence",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        "--fasta",
        type=str,
        help="FASTA file of CDS translations from Nextclade.",
    )
    parser.add_argument(
        "--out-col",
        type=str,
        default="gene_coverage",
        help="Output column name.",
    )
    return parser.parse_args()


def calculate_gene_coverage_from_nextclade_cds(fasta, out_col):
    """
    Calculate gene coverage from amino acid sequence in gene translation FASTA file from Nextclade.
    """
    print(f"genbank_accession\t{out_col}")
    # Iterate over the sequences in the FASTA file
    for record in SeqIO.parse(fasta, "fasta"):
        sequence_id = record.id
        sequence = str(record.seq)
        
        # Calculate gene coverage
        results = re.findall(r"([ACDEFGHIKLMNPQRSTVWY])",  sequence.upper())
        gene_coverage = round(len(results) / len(sequence), 3)

        # Print the results
        print(f"{sequence_id}\t{gene_coverage}")


def main():
    args = parse_args()

    calculate_gene_coverage_from_nextclade_cds(args.fasta, args.out_col)


if __name__ == "__main__":
    main()