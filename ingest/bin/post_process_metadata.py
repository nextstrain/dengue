#! /usr/bin/env python3

import argparse
import json
from sys import stdin, stdout

def parse_args():
    parser = argparse.ArgumentParser(
        description="Reformat a NCBI Virus metadata.tsv file for a pathogen build."
    )
    return parser.parse_args()


def _set_strain_name(record):
    """Replace spaces, dashes, and periods with underscores in strain name."""
    strain_name = record["strain"]

    return (
        strain_name.replace(" ", "_")
        .replace("-", "_")
        .replace(".", "_")
        .replace("(", "_")
        .replace(")", "_")
    )


def _set_url(record):
    """Set url column from accession"""
    return "https://www.ncbi.nlm.nih.gov/nuccore/" + str(record["accession"])


def _set_paper_url(record):
    """Set paper_url from a comma separate list of PubMed IDs in publication. Only use the first ID."""
    if (not record["publications"]):
        return ""

    return (
        "https://www.ncbi.nlm.nih.gov/pubmed/"
        + str(record["publications"]).split(",")[0]
    )


def _set_dengue_serotype(record):
    """Set dengue serotype from viruslineage_ids"""
    dengue_types = {
        "11053": "denv1",
        "11060": "denv2",
        "11069": "denv3",
        "11070": "denv4",
    }

    ids = set(record["viruslineage_ids"].split(","))

    for taxid, serotype in dengue_types.items():
        if taxid in ids:
            return serotype

    return ""


def main():
    args = parse_args()

    for index, record in enumerate(stdin):
        record = json.loads(record)
        record["strain"] = _set_strain_name(record)
        record["url"] = _set_url(record)
        record["paper_url"] = _set_paper_url(record)
        record["serotype"] = _set_dengue_serotype(record)
        record["authors"] = record["abbr_authors"]
        stdout.write(json.dumps(record) + "\n")


if __name__ == "__main__":
    main()
