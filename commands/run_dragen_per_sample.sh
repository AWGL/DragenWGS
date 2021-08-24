#!/bin/bash
set -euo pipefail

seqId=$1
sampleId=$2
pipelineName=$3
pipelineVersion=$4
panel=$5
dragen_ref=$6
assembly=$7

/opt/edico/bin/dragen \
-r $dragen_ref \
--output-directory . \
--output-file-prefix "$seqId"_"$sampleId" \
--output-format CRAM \
--enable-map-align-output true \
--fastq-list fastqs.csv \
--fastq-list-sample-id $sampleId \
--enable-duplicate-marking true \
--enable-variant-caller true \
--vc-enable-joint-detection true \
--qc-cross-cont-vcf config/"$panel"/sample_cross_contamination_resource_${assembly}.vcf \
--vc-sample-name "$sampleId" \
--vc-emit-ref-confidence GVCF \
--strict-mode true \
--qc-coverage-region-1 config/"$panel"/"$panel"_coverage.bed \
--qc-coverage-reports-1 cov_report \
--qc-coverage-filters-1 'mapq<20,bq<10' \
