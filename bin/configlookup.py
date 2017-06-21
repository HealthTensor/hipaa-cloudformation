#!/usr/bin/env python3
"""Get the data at path from the provided file.

Copyright Notice
----------------
Copyright (C) HealthTensor, Inc - All Rights Reserved
  Unauthorized copying of this file, via any medium is strictly prohibited
  Proprietary and confidential

"""
import sys
import yaml


def get_data_at_path(data, path_elts):
    if not path_elts:
        return data
    return get_data_at_path(data[path_elts[0]], path_elts[1:])


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser('lookup key in yaml file')
    parser.add_argument('input', help='path to input data file')
    parser.add_argument('path', help='data path to select')
    parser.add_argument('--default', help='the default value to return')
    args = parser.parse_args()

    with open(args.input, 'r') as file_:
        data = yaml.load(file_)
    path_elts = args.path.split('.')
    try:
        value = get_data_at_path(data, path_elts)
    except (KeyError, TypeError):
        if args.default:
            value = args.default
        else:
            print('no value found at path', file=sys.stderr)
            exit(1)
    print(value)
