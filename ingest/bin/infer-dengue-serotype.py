#! /usr/bin/env python3

import argparse
import json
from sys import stdin, stdout

def parse_args():
    parser = argparse.ArgumentParser(
        description="Dengue specific processing of metadata, infer serotype from virus_tax_id",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        "--virus-tax-id",
        type=str,
        default="virus_tax_id",
        help="Column name containing the NCBI taxon id of the virus serotype.",
    )
    parser.add_argument(
        "--out-col",
        type=str,
        default="ncbi_serotype",
        help="Column name to store the inferred serotype.",
    )
    return parser.parse_args()


def _get_dengue_serotype(record, col="virus_tax_id"):
    """Set dengue serotype from virus_tax_id"""
    dengue_types = {
        "11053": "denv1",
        "11060": "denv2",
        "11069": "denv3",
        "11070": "denv4",
        "31634": "denv2", # Dengue virus 2 Thailand/16681/84
    }

    taxon_id = record[col]

    return dengue_types.get(taxon_id, "")


def main():
    args = parse_args()

    for record in stdin:
        record = json.loads(record)
        record[args.out_col] = _get_dengue_serotype(record, col=args.virus_tax_id)
        stdout.write(json.dumps(record) + "\n")


if __name__ == "__main__":
    main()
