#! /usr/bin/env python
"""
Updates the title and journal fields of the NDJSON record from stdin and outputs by making Entrez queries to fetch citations
"""

import argparse
import json
import re
from sys import stderr, stdin, stdout
import time

from Bio import SeqIO
from Bio import Entrez
import requests
import warnings


def parse_args():
    parser = argparse.ArgumentParser(
        description="Use Entrez query to extract citations. Fetch in batches of group size."
    )
    parser.add_argument(
        "--genbank-id-field",
        default="genbank_accession",
    )
    parser.add_argument(
        "--group-size",
        default=200,
        help="Fetch in batches of group size [default:200]",
        required=False,
    )
    parser.add_argument(
        "--entrez-email",
        default="hello@nextstrain.org",
        help="Entrez email address [default:hello@nextstrain.org]",
        required=False,
    )
    return parser.parse_args()


def fetch_and_print_citations(data: dict, genbank_id_field: str):
    genbank_ids = ",".join([d[genbank_id_field] for d in data])

    try:
        handle = Entrez.efetch(
            db="nucleotide", id=genbank_ids, rettype="gb", retmode="text", retmax=1000
        )
        record = SeqIO.parse(handle, "genbank")

        results_dict = dict()
        for row in record:
            results_dict[row.id.split(".")[0]] = row.annotations["references"][0].title

        # Maintain the order in data
        for d in data:
            if d["genbank_accession"] in results_dict:
                d["title"] = results_dict[d["genbank_accession"]]

            # Always print the record
            json.dump(d, stdout, allow_nan=False, indent=None, separators=",:")
            print()

        handle.close()
    except Exception as exception_msg:
        for d in data:
            fetch_one_citation(d, genbank_id_field)
            time.sleep(1)

    return None


def fetch_one_citation(data: dict, genbank_id_field: str):
    genbank_id = data[genbank_id_field]

    try:
        handle = Entrez.efetch(
            db="nucleotide", id=genbank_id, rettype="gb", retmode="text", retmax=1000
        )
        record = SeqIO.read(handle, "genbank")

        data["title"] = record.annotations["references"][0].title

        json.dump(data, stdout, allow_nan=False, indent=None, separators=",:")
        print()

        handle.close()

    except Exception as exception_msg:
        warnings.warn(f"Pass through and skip title processing for {data[genbank_id_field]}: {exception_msg}", stacklevel=2)

        # example: GenBank ON123563-81 records are in the ndjson but were removed from Entrez
        json.dump(data, stdout, allow_nan=False, indent=None, separators=",:")
        print()

    return None


def main():
    args = parse_args()

    data = []
    chunk_size = args.group_size
    genbank_id_field = args.genbank_id_field

    Entrez.email = args.entrez_email

    for index, record in enumerate(stdin):
        data.append(json.loads(record))
        if (index + 1) % chunk_size == 0:
            fetch_and_print_citations(data, genbank_id_field)
            data = []

    if data:
        fetch_and_print_citations(data, genbank_id_field)


if __name__ == "__main__":
    main()
