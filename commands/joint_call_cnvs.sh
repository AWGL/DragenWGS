#!/bin/bash
set -euo pipefail

seqId=$1
panel=$2


/opt/edico/bin/dragen -r \
/staging/human/reference/GRCh37/ \
--output-directory /staging/data/results/$seqId/$panel/ \
--output-file-prefix $seqId \
--enable-cnv true \
--cnv-enable-ref-calls false \
