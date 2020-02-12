#!/bin/bash
set -euo pipefail

# Usage: bash /data/pipelines/DragenWGS/DragenWGS-1.0.0/DragenWGS.sh /staging/data/fastq/191010_D00501_0366_BH5JWHBCX3/Data/IlluminaTruSightOne/18M01315

version=1.0.0
sampleDir=$1

. *.variables
. /data/pipelines/"$pipelineName"/"$pipelineName"-"$pipelineVersion"/config/"$panel"/*.variables


# make output dir for results
mkdir -p /staging/data/results/$seqId/$panel/$sampleId

cp *.variables /staging/data/results/$seqId/$panel/$sampleId
cp /data/pipelines/"$pipelineName"/"$pipelineName"-"$pipelineVersion"/config/"$panel"/*.variables /staging/data/results/$seqId/$panel


# make csv with fastqs in

echo "RGID,RGSM,RGLB,Lane,Read1File,Read2File" > fastqs.csv


for fastqPair in $(ls "$sampleId"_S*.fastq.gz | cut -d_ -f1-3 | sort | uniq); do
   
   laneId=$(echo "$fastqPair" | cut -d_ -f3)
   read1Fastq=$(ls "$fastqPair"_R1_*fastq.gz)
   read2Fastq=$(ls "$fastqPair"_R2_*fastq.gz)

   echo "$seqId"_"$laneId","$sampleId","$seqId","$laneId","$PWD/$read1Fastq,$PWD/$read2Fastq" >> fastqs.csv

done

cp /data/pipelines/"$pipelineName"/"$pipelineName"-"$pipelineVersion"/commands/run_dragen.sh .

echo $callCNV
if [ "$callCNV" == true ]
then

echo '--enable-cnv true \' >> run_dragen.sh
echo '--cnv-enable-self-normalization true \' >> run_dragen.sh 

fi



echo $callRepeats
if [ "$callRepeats" == true ]
then

echo '--repeat-genotype-enable true \' >> run_dragen.sh
echo "--repeat-genotype-specs /data/pipelines/"$pipelineName"/"$pipelineName"-"$pipelineVersion"/config/"$panel"/smn-catalog.grch37.json  \\" >> run_dragen.sh
echo '--auto-detect-sample-sex true \' >> run_dragen.sh

fi


bash run_dragen.sh $seqId $sampleId $pipelineName $pipelineVersion $panel


# add gvcfs for joint SNP/Indel calling
if [ -e /staging/data/results/$seqId/$panel/$sampleId/"$seqId"_"$sampleId".hard-filtered.gvcf.gz ]; then
    echo /staging/data/results/$seqId/$panel/$sampleId/"$seqId"_"$sampleId".hard-filtered.gvcf.gz >> /staging/data/results/$seqId/$panel/gVCFList.txt
fi


# add bam files for joint SV calling
if [ -e /staging/data/results/$seqId/$panel/$sampleId/"$seqId"_"$sampleId".bam ]; then
    echo "--bam-input /staging/data/results/$seqId/$panel/$sampleId/"$seqId"_"$sampleId".bam \\" >> /staging/data/results/$seqId/$panel/BAMList.txt
fi


# add tn.tsv files for joint CNV calling 
if [ -e /staging/data/results/$seqId/$panel/$sampleId/"$seqId"_"$sampleId".tn.tsv ]; then
    echo "--cnv-input /staging/data/results/$seqId/$panel/$sampleId/"$seqId"_"$sampleId".tn.tsv \\" >> /staging/data/results/$seqId/$panel/TNList.txt
fi



expGVCF=$(ls -d /staging/data/fastq/$seqId/Data/$panel/*/ | wc -l)

# observed number
obsGVCF=$(wc -l < /staging/data/results/$seqId/$panel/gVCFList.txt)


if [ $expGVCF == $obsGVCF ]; then

    echo "performing joint genotyping"

    dragen \
        -r  /staging/human/reference/GRCh37/ \
        --output-directory /staging/data/results/$seqId/$panel/ \
        --output-file-prefix "$seqId" \
        --enable-joint-genotyping true \
        --variant-list /staging/data/results/$seqId/$panel/gVCFList.txt \
        --strict-mode true \
        --enable-vqsr true \
        --vqsr-config /data/pipelines/"$pipelineName"/"$pipelineName"-"$pipelineVersion"/config/"$panel"/dragen-VQSR.cfg
  
    if [ $callCNV == true ]; then

    echo Joint Calling CNVs

    cp /data/pipelines/"$pipelineName"/"$pipelineName"-"$pipelineVersion"/commands/joint_call_cnvs.sh .

    cat /staging/data/results/$seqId/$panel/TNList.txt >> joint_call_cnvs.sh

    bash joint_call_cnvs.sh $seqId $panel

    fi

    if [ $callSV == true ]; then

    echo Joint Calling SVs

    cp /data/pipelines/"$pipelineName"/"$pipelineName"-"$pipelineVersion"/commands/joint_call_svs.sh .

    cat /staging/data/results/$seqId/$panel/BAMList.txt >> joint_call_svs.sh

    bash joint_call_svs.sh $seqId $panel


    fi
     

    # delete gvcfs
    ls /staging/data/results/$seqId/$panel/*/*.gvcf.gz | xargs rm

else
    echo "sampleId is not the last sample"

fi

