# DragenWGS


 ## Introduction


 A pipeline to perform joint calling on WGS NGS data on the Dragen server.


 Calls SNPs/Indels, SVs, CNVs and Repeat Expansions


 ## Requirements

 dragen Version 07.021.408.3.4.12 (Software Release v3.4)

 ## Run

 The script should be run on a per sample basis in a directory structure such as this:


 ```
IlluminaTruSightOne/
├── sample1/
│   ├── sample1_S1_L001_R1_001.fastq.gz
│   ├── sample1_S1_L001_R2_001.fastq.gz
│   ├── sample1_S2_L002_R1_001.fastq.gz
│   ├── sample1_S2_L002_R2_001.fastq.gz
│   └── sample1.variables
```

 This can be found within the staging area fastq directory on the Dragen e.g. /staging/data/fastq/191010_D00501_0366_BH5JWHBCX3/Data/NexteraDNAFlex

 Once within this folder:

 ```
bash DragenWGS.sh $sample_folder_location
```
Where $sample_folder_location is something like /staging/data/fastq/191010_D00501_0366_BH5JWHBCX3/Data/NexteraDNAFlex/sample1

 Once the gvcf creation is complete for each sample the joint genotyping will be called and produce the final joint vcf.


 ## Results

 Produces results in:

 /staging/data/results/$run_id/$panel/

 Will produce:

 Sample Level:

 - BAM file
- QC Metrics
- Repeat Expansion VCF

 Run Level:
- Joint VCF
- Joint VCF hard filtered
- Variant Calling Metrics
- Joint SV VCF
- Join CNV VCF


 ## Authors

 Chris Medway and Joseph Halstead

 ## References

 https://support.illumina.com/content/dam/illumina-support/documents/documentation/software_documentation/dragen-bio-it/dragen-bio-it-platform-user-guide-1000000070494-06.pdf
