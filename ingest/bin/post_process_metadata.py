#! /usr/bin/env python3

import argparse
import os
import sys

import numpy as np
import pandas as pd


def parse_args():
    parser = argparse.ArgumentParser(
        description="Reformat a NCBI Virus metadata.tsv file for a pathogen build."
    )
    parser.add_argument(
        "--metadata", help="NCBI Virus metadata.tsv file.", required=True
    )
    parser.add_argument(
        "--outfile",
        help="Output file name, e.g. processed_metadata.tsv.",
        required=True,
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
    if pd.isna(record["publications"]):
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
    df = pd.read_csv(args.metadata, sep="\t", header=0)

    df["strain"] = df.apply(_set_strain_name, axis=1)
    df["url"] = df.apply(_set_url, axis=1)
    df["paper_url"] = df.apply(_set_paper_url, axis=1)
    df["serotype"] = df.apply(_set_dengue_serotype, axis=1)
    df["authors"] = df["abbr_authors"]
    df["city"] = df["location"]

    METADATA_COLUMNS = [
        "strain",
        "accession",
        "genbank_accession_rev",
        "serotype",
        "date",
        "updated",
        "region",
        "country",
        "division",
        "city",
        "authors",
        "url",
        "title",
        "paper_url",
    ]
    df.to_csv(args.outfile, sep="\t", index=False, columns=METADATA_COLUMNS)


if __name__ == "__main__":
    main()
