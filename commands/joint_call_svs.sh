#!/bin/bash
set -euo pipefail

seqId=$1
panel=$2


dragen -f \
--sv-reference /staging/human/reference/GRCh37/human_g1k_v37.fasta \
--ref-dir /staging/human/reference/GRCh37/ \
--enable-map-align false \
--enable-sv true \
--output-directory /staging/data/results/$seqId/$panel/ \
--output-file-prefix $seqId \
