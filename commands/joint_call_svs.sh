#!/bin/bash
set -euo pipefail

seqId=$1
dragen_ref=$2
fasta=$3


/opt/edico/bin/dragen -f \
--sv-reference "$dragen_ref"/"$fasta" \
--ref-dir $dragen_ref \
--enable-map-align false \
--enable-sv true \
--output-directory sv_calling \
--output-file-prefix $seqId \
