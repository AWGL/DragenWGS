#!/bin/bash
set -euo pipefail

seqId=$1
panel=$2
dragen_ref=$3

/opt/edico/bin/dragen \
-r $dragen_ref \
--output-directory . \
--output-file-prefix $seqId \
--enable-cnv true \
--cnv-enable-ref-calls false \
