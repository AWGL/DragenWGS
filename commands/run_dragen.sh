#!/bin/bash
set -euo pipefail

seqId=$1
sampleId=$2
pipelineName=$3
pipelineVersion=$4
panel=$5


dragen \
-r /staging/human/reference/GRCh37/ \
--output-directory /staging/data/results/$seqId/$panel/$sampleId \
--output-file-prefix "$seqId"_"$sampleId" \
--output-format BAM \
--enable-map-align-output true \
--fastq-list fastqs.csv \
--fastq-list-sample-id $sampleId \
--enable-duplicate-marking true \
--enable-variant-caller true \
--qc-cross-cont-vcf /data/pipelines/"$pipelineName"/"$pipelineName"-"$pipelineVersion"/config/"$panel"/sample_cross_contamination_resource_GRCh37.vcf \
--vc-sample-name "$sampleId" \
--vc-emit-ref-confidence BP_RESOLUTION \
--strict-mode true \
--qc-coverage-region-1 /data/pipelines/"$pipelineName"/"$pipelineName"-"$pipelineVersion"/config/"$panel"/"$panel"_coverage.bed \
--qc-coverage-reports-1 cov_report \
