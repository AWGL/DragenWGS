## Verification of DragenWGS v1.1.0

### ChangeLog

* Move to Wren HPC Architecture. Compatible with Slurm job sheduler.
* Move to new Dragen Software (3.7)
* Code Quality Updates

### Verification Evidence

#### Recall and Precision

* To verify that the DragenWGS software has eqivilent performance to v1.0.0 the GIAB samples HG001 and HG002 were run through the pipeline. Recall and Precision were calculated using the Hap.py software [1]. The following command was used when using the Docker version of hap.py

```
sudo docker run -it -v `pwd`:/data pkrusche/hap.py /opt/hap.py/bin/hap.py /data/ref_files/HG001_GRCh37_GIAB_highconf_CG-IllFB-IllGATKHC-Ion-10X-SOLID_CHROM1-X_v.3.3.2_highconf_PGandRTGphasetransfer.vcf.gz /data/input/200826_A00748_0039_BHLKNLDRXX.18M01316.qual.vcf.gz -f /data/ref_files/HG001_GRCh37_GIAB_highconf_CG-IllFB-IllGATKHC-Ion-10X-SOLID_CHROM1-X_v.3.3.2_highconf_nosomaticdel.bed -r /data/ref_files/human_g1k_v37.fasta -o /data/output/200826_A00748_0039_BHLKNLDRXX_18M01316_wren --stratification /data/ref_files/benchmarking-tools-master/resources/stratification-bed-files/ga4gh_all.tsv  --roc QUAL

```

The precision and recall values were equivalent or higher for all samples examined (see recall_and_precision_table.csv)

##### Stratification

The variant detail metrics produced by the Hap.py software were also examined. These metrics describe the precision and recall for different variant types and different genomic locations.

The recall_by_genomic_location_gt60variants.csv file shows the regions of the genome with more than 60 Truth set variants in sorted by recall. As we saw in the original validation regions outside the CDS such as low complexity regions have lower recall and precision than other regions. This is a known limitation of the test.

The file metrics_by_variant_type.csv shows the recall and precision of variants of different variant types both over the whole high confidence ROI and the func_cds ROI. As seen in the original validation larger insertions and deletions as well as complex indels have worse recall and precision than SNPs and simple indels.


#### Coverage

To ensure that the software update had not affected the coverage metrics produced by the Dragen the percentage of bases over 20x over the whole exon +-20bps was compared with the previous data. There were no differences between the two sets of values.

#### QC Metrics

The sex calculation was checked to ensure the sex estimation tool still worked correctly. The sex calculations were accurate.

### References

[1] https://github.com/Illumina/hap.py