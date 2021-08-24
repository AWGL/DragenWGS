#!/usr/bin/env python

import argparse
import glob
from pathlib import Path

"""
Get the variables files and make a PED file from them

"""


parser = argparse.ArgumentParser(description='Create a ped file from variables files.')
parser.add_argument('--variables', type=str, nargs=1, required=True,
				help='glob string for variables files')

args = parser.parse_args()



variable_files = glob.glob(args.variables[0])

ped_dict = {}


for file in variable_files:

	sample_name = Path(file).stem

	f = open(file, 'r')

	variables_dict = {}

	for line in f:

		new_line = line.strip()

		if len(new_line) == 0:

			pass

		elif new_line[0] == '#':

			pass

		else:

			split_line = new_line.split('=')

			variables_dict[split_line[0]] = split_line[1]

	ped_dict[sample_name] = variables_dict


for key in ped_dict:

	sample_id = ped_dict[key].get('sampleId')

	sex = ped_dict[key].get('sex')

	familyId = ped_dict[key].get('familyId')

	paternalId = ped_dict[key].get('paternalId')

	maternalId = ped_dict[key].get('maternalId')

	phenotype = ped_dict[key].get('phenotype')

	if sex == None:

		sex = 0

	if familyId == None:

		familyId = 0

	if paternalId == None:

		paternalId = 0

	if maternalId == None:

		maternalId = 0

	if phenotype == None:

		phenotype = 2

	print (f'{familyId}\t{sample_id}\t{paternalId}\t{maternalId}\t{sex}\t{phenotype}') 