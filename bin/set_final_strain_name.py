#! /usr/bin/env python

import json, argparse
import augur


def parse_args():
    parser = argparse.ArgumentParser(
        description="Swaps out the strain names in the Auspice JSON with the final strain name",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        "--input-auspice-json", type=str, required=True, help="input auspice_json"
    )
    parser.add_argument("--metadata", type=str, required=True, help="input data")
    parser.add_argument(
        "--display-strain-name",
        type=str,
        required=True,
        help="field to use as strain name in auspice",
    )
    parser.add_argument(
        "--output", type=str, metavar="JSON", required=True, help="output Auspice JSON"
    )
    return parser.parse_args()


def replace_name_recursive(node, lookup):
    if node["name"] in lookup:
        node["name"] = lookup[node["name"]]

    if "children" in node:
        for child in node["children"]:
            replace_name_recursive(child, lookup)


def set_final_strain_name(auspice_json, metadata_file, display_strain_name, output):
    with open(auspice_json, "r") as fh:
        data = json.load(fh)

    metadata = augur.io.read_metadata(metadata_file)
    if display_strain_name not in metadata.columns:
        with open(output, "w") as fh:
            json.dump(data, fh, allow_nan=False, indent=None, separators=",:")
        return

    name_lookup = metadata[[display_strain_name]].to_dict()[display_strain_name]
    replace_name_recursive(data["tree"], name_lookup)
    with open(output, "w") as fh:
        json.dump(data, fh, allow_nan=False, indent=None, separators=",:")


def main():
    args = parse_args()
    set_final_strain_name(
        args.input_auspice_json, args.metadata, args.display_strain_name, args.output
    )


if __name__ == "__main__":
    main()
