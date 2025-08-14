"""
Program to generate optimal batches for joint SV calling

1) Joint calling of SVs allows de novo calling
2) Therefore samples in same family should be joint called together
3) Dragen SV caller has max valid joint calling sample size of ~10
4) More batches equals more runtime
5) Therefore need to put families into batches of <=10

For example given a run with:

FAM001 - 3 samples
FAM002 - 4 samples
FAM003 - 2 samples
FAM005 - 8 samples
FAM006 - 1 sample
FAM007 - 1 sample
FAM008 - 3 samples

Could break into batches of:

10 samples (FAM005, FAM006, FAM007)
10 samples (FAM008, FAM001, FAM002)
3 samples (FAM003)

Usage:

python by_family.py 200923_A00748_0043_BHLK2CDRXX.ped 200923_A00748_0043_BHLK2CDRXX
"""

import csv
import sys
import glob
#import knapsack

def greedy_knapsack(weights, capacity):
    """
    Simple greedy knapsack implementation for Python 2
    Returns (total_weight, [indices]) similar to the knapsack package
    Written by Claude! Need a knapsack replacement
    """
    # Create list of (weight, original_index) and sort by weight descending
    indexed_weights = [(weights[i], i) for i in range(len(weights))]
    indexed_weights.sort(reverse=True)  # Largest first

    selected_indices = []
    total_weight = 0

    for weight, original_index in indexed_weights:
        if total_weight + weight <= capacity:
            selected_indices.append(original_index)
            total_weight += weight

    return (total_weight, selected_indices)


# set some params
min_depth = 5 # samples below this min depth - exclude SV calling
capacity = 4 # max number of samples to SV call at a time


# ped file
ped = sys.argv[1]

#seq id
seq_id = sys.argv[2]

#panel 
panel = sys.argv[3]

# id for singletons
no_fam_int = 0

# we need the metric files (Dragen v3.7) and wgs coverage metric files (Dragen v3.10.8) for excluding low coverage samples
metrics_files = glob.glob('/mnt/Data-MSA/results/{}/{}/metrics/*/*.mapping_metrics.csv'.format(seq_id, panel))
wgs_metrics_files = glob.glob('/mnt/Data-MSA/results/{}/{}/metrics/*/*.wgs_coverage_metrics.csv'.format(seq_id, panel))

# make a dict of samples with coverage > min_depth
sample_dict = {}

#Check if we need to be using metrics or wgs metrics files for depth, using just the first file

if "Average sequenced coverage over genome" in open(metrics_files[0]).read():
	for coverage_file in metrics_files:

		with open(coverage_file) as csvfile:
			spamreader = csv.reader(csvfile, delimiter=',')
			for row in spamreader:
				key = row[2]
				value = row[3]
				if key == 'Average sequenced coverage over genome':
					if float(value) > min_depth:
						sample_id = coverage_file.split('/')[7]
						sample_dict[sample_id] = sample_id
						break
else:
	for coverage_file in wgs_metrics_files:
		
		with open(coverage_file) as csvfile:
                        spamreader = csv.reader(csvfile, delimiter=',')
                        for row in spamreader:
                                key = row[2]
                                value = row[3]
                                if key == 'Average alignment coverage over genome':
                                        if float(value) > min_depth:
                                                sample_id = coverage_file.split('/')[7]
                                                sample_dict[sample_id] = sample_id
                                                break

# dict to store family info e.g. key as family key and value as list of samples in that family
fam_dict = {}

with open(ped) as csvfile:
	spamreader = csv.reader(csvfile, delimiter='\t')
	for row in spamreader:

		fam_id = row[0]
		sample_name = row[1]

		if fam_id == 0 or fam_id == '0':

			fam_dict['singleton_{}'.format(no_fam_int)] = [sample_name]
			no_fam_int = no_fam_int + 1

		else:

			if fam_id not in fam_dict:

				fam_dict[fam_id] = [sample_name]

			else:

				fam_dict[fam_id].append(sample_name)

# count for batch ids
count = 1

# while we still have families in the fam_dict
while len(fam_dict) > 0:

	# get a list of family sizes
	fam_sizes = []

	for key in fam_dict:

		fam_sizes.append(len(fam_dict[key]))

	# this is a version of knapsack problem - uses custom greedy knapsack function (instead of knapsack function)
	to_put_in_sack = greedy_knapsack(fam_sizes, capacity)

	# error if no valid solution
	if to_put_in_sack[0] == 0:
		raise Exception('No valid batches')
	
	# get the families/samples identified in to_put_in_sack and put their sizes in this_current_batch
	this_current_batch = []
	
	for x in to_put_in_sack[1]:

		this_current_batch.append(fam_sizes[x])

	# rows to include in each batch e.g. --cram-input XXXX.cram
	batch_rows = []

	# loop through each family
	for key in fam_dict.copy():

		# if the family has a size matching a size in this_current_batch
		if len(fam_dict[key]) in this_current_batch:

			# remove an instance of that size from this_current_batch
			this_current_batch.remove(len(fam_dict[key]))

			# add a row for each sample in that family if it is > min_depth
			for sample in fam_dict[key]:

				if sample in sample_dict:

					batch_rows.append('--cram-input temp_crams/{}_{}.cram \\'.format(seq_id, sample))

			# remove family from fam_dict
			fam_dict.pop(key)		

	# write batch to file
	out_file = '{}_for_sv.family'.format(count)
	if len(batch_rows) >0:
		with open(out_file, 'w') as csvfile:
			spamwriter = csv.writer(csvfile, delimiter='\t', lineterminator='\n')
		
			for row in batch_rows:

				spamwriter.writerow([row])

	# increment batch name
	count = count + 1
