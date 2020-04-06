#!/bin/bash
set -euo pipefail

# Usage: cd /staging/data/fastq/runId/Data/panel/sampleId && bash /data/pipelines/DragenWGS/DragenWGS-1.0.0/DragenWGS.sh 
# Creates results at /staging/data/results/runId/panel/

version=1.0.0

##############################################
# SETUP                                      #
##############################################


# load variables for sample and pipeline
. *.variables
. /data/pipelines/"$pipelineName"/"$pipelineName"-"$pipelineVersion"/config/"$panel"/*.variables


# make output dir for results
mkdir -p /staging/data/results/$seqId/$panel/$sampleId

# copy relevant variables files to thr results directory
cp *.variables /staging/data/results/$seqId/$panel/$sampleId
cp /data/pipelines/"$pipelineName"/"$pipelineName"-"$pipelineVersion"/config/"$panel"/*.variables /staging/data/results/$seqId/$panel

#############################################
# Get FASTQs                                #
#############################################

# make csv with fastqs in
echo "RGID,RGSM,RGLB,Lane,Read1File,Read2File" > fastqs.csv

for fastqPair in $(ls "$sampleId"_S*.fastq.gz | cut -d_ -f1-3 | sort | uniq); do
   
   laneId=$(echo "$fastqPair" | cut -d_ -f3)
   read1Fastq=$(ls "$fastqPair"_R1_*fastq.gz)
   read2Fastq=$(ls "$fastqPair"_R2_*fastq.gz)

   echo "$seqId"_"$laneId","$sampleId","$seqId","$laneId","$PWD/$read1Fastq,$PWD/$read2Fastq" >> fastqs.csv

done

#############################################
# Sample Level Calling   	       	    # 
#############################################

# we copy a template script to the working directory and add extra lines based on the variables file 
cp /data/pipelines/"$pipelineName"/"$pipelineName"-"$pipelineVersion"/commands/run_dragen.sh .

echo User Selected to Call CNVS: $callCNV

# If user has selected to call CNVS then add the relevant lines to the run_dragen.sh template script
if [[ "$callCNV" == true ]] && [[ $sampleId != *"NTC"* ]];
then

echo '--enable-cnv true \' >> run_dragen.sh
echo '--cnv-enable-self-normalization true \' >> run_dragen.sh 

fi

echo User Selected to Call Repeat Regions: $callRepeats
# Of user has selected to call repeat regions then add the relevant lines to the run_dragen.sh template script
if [[ "$callRepeats" == true ]] && [[ $sampleId != *"NTC"* ]];
then

echo '--repeat-genotype-enable true \' >> run_dragen.sh
echo "--repeat-genotype-specs /data/pipelines/"$pipelineName"/"$pipelineName"-"$pipelineVersion"/config/"$panel"/smn-catalog.grch37.json  \\" >> run_dragen.sh
echo '--auto-detect-sample-sex true \' >> run_dragen.sh

fi

# run sample level script
bash run_dragen.sh $seqId $sampleId $pipelineName $pipelineVersion $panel




# add gvcfs for joint SNP/Indel calling
if [ -e /staging/data/results/$seqId/$panel/$sampleId/"$seqId"_"$sampleId".hard-filtered.gvcf.gz ]; then
    echo /staging/data/results/$seqId/$panel/$sampleId/"$seqId"_"$sampleId".hard-filtered.gvcf.gz >> /staging/data/results/$seqId/$panel/gVCFList.txt
fi


# add bam files for joint SV calling
if [[ -e /staging/data/results/$seqId/$panel/$sampleId/"$seqId"_"$sampleId".bam ]] && [[ $sampleId != *"NTC"* ]]; then
    echo "--bam-input /staging/data/results/$seqId/$panel/$sampleId/"$seqId"_"$sampleId".bam \\" >> /staging/data/results/$seqId/$panel/BAMList.txt
fi


# add tn.tsv files for joint CNV calling 
if [[ -e /staging/data/results/$seqId/$panel/$sampleId/"$seqId"_"$sampleId".tn.tsv ]] && [[ $sampleId != *"NTC"* ]]; then
    echo "--cnv-input /staging/data/results/$seqId/$panel/$sampleId/"$seqId"_"$sampleId".tn.tsv \\" >> /staging/data/results/$seqId/$panel/TNList.txt
fi


# expected number of gvcfs
expGVCF=$(ls -d /staging/data/fastq/$seqId/Data/$panel/*/ | wc -l)

# observed number
obsGVCF=$(wc -l < /staging/data/results/$seqId/$panel/gVCFList.txt)

#############################################
# Joint Calling                             #
#############################################

if [ $expGVCF == $obsGVCF ]; then

    echo "performing joint genotyping of snps/indels"

    /opt/edico/bin/dragen \
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

