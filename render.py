#!/bin/env python
import argparse
import json
import os
import sys

import chevron


def parse_args():
    def is_file_or_pipe(arg):
        if not os.path.exists(arg) or os.path.isdir(arg):
            parser.error("The file {0} does not exist!".format(arg))
        else:
            return arg

    parser = argparse.ArgumentParser(description="Render templates")
    parser.add_argument(
        "-d",
        "--data",
        dest="data",
        help="The json data file",
        type=is_file_or_pipe,
        default={},
    )
    parser.add_argument(
        "-z",
        "--zone",
        dest="zone",
        required=False,
        help="The zone name",
        default={},
    )
    parser.add_argument("template", metavar="template", help="The mustache file")
    return parser.parse_args()


def main():
    args = parse_args()

    with open(args.data, "r") as j:
        d = json.load(j)
        if args.zone:
            all_zones = d["hosts"] + d["announcers"] + d["party-zones"]
            d["zone"] = next(z for z in all_zones if z["name"] == args.zone)
        with open(args.template, "r") as t:
            print(chevron.render(t, d))


if __name__ == "__main__":
    main()
