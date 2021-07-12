import csv

ped = '200923_A00748_0043_BHLK2CDRXX.ped'

seq_id = '200923_A00748_0043_BHLK2CDRXX'

fam_dict = {}

no_fam_int = 0

with open(ped) as csvfile:
	spamreader = csv.reader(csvfile, delimiter='\t')
	for row in spamreader:

		fam_id = row[0]
		sample_name = row[1]

		if fam_id == 0 or fam_id == '0':

			fam_dict[f'singleton_{no_fam_int}'] = [sample_name]
			no_fam_int = no_fam_int +1

		else:

			if fam_id not in fam_dict:

				fam_dict[fam_id] = [sample_name]

			else:

				fam_dict[fam_id].append(sample_name)


for key in fam_dict:

	out_file = f'{key}_for_sv.family'

	with open(out_file, 'w') as csvfile:
		spamwriter = csv.writer(csvfile, delimiter='\t')

		new_row = []
		
		for sample in fam_dict[key]:

			new_row.append(f'{sample}/{seq_id}_{sample}.bam')

		spamwriter.writerow(new_row)