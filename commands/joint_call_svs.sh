#!/bin/bash
set -euo pipefail

seqId=$1
panel=$2


/opt/edico/bin/dragen -f \
--sv-reference /staging/human/reference/GRCh37/human_g1k_v37.fasta \
--ref-dir /staging/human/reference/GRCh37/ \
--enable-map-align false \
--enable-sv true \
--output-directory . \
--output-file-prefix $seqId \
