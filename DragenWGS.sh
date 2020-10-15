#!/bin/bash

set -euo pipefail

# set max processes and open files as these differ between wren and head node
ulimit -S -u 16384
ulimit -S -n 65535


# Usage: cd /staging/data/results/$seqId/$panel/$sampleId && bash DragenWGS.sh 

version=2.0.0

##############################################
# SETUP                                      #
##############################################

pipeline_dir="/data/diagnostics/pipelines/"
dragen_ref="/staging/resources/human/reference/GRCh37"
output_dir="/Output/results/"


# load variables for sample and pipeline
. *.variables
. "$pipeline_dir"/"$pipelineName"/"$pipelineName"-"$pipelineVersion"/config/"$panel"/*.variables


# copy relevant variables files to the results directory
cp "$pipeline_dir"/"$pipelineName"/"$pipelineName"-"$pipelineVersion"/config/"$panel"/*.variables ..
cp -r "$pipeline_dir"/"$pipelineName"/"$pipelineName"-"$pipelineVersion"/commands .
cp -r "$pipeline_dir"/"$pipelineName"/"$pipelineName"-"$pipelineVersion"/config .

#############################################
# Get FASTQs                                #
#############################################

# make csv with fastqs in
echo "RGID,RGSM,RGLB,Lane,Read1File,Read2File" > fastqs.csv

for fastqPair in $(ls "$sampleId"_S*.fastq.gz | cut -d_ -f1-3 | sort | uniq); do
   
   laneId=$(echo "$fastqPair" | cut -d_ -f3)
   read1Fastq=$(ls "$fastqPair"_R1_*fastq.gz)
   read2Fastq=$(ls "$fastqPair"_R2_*fastq.gz)

   echo "$seqId"_"$laneId","$sampleId","$seqId","$laneId","$read1Fastq","$read2Fastq" >> fastqs.csv

done

#############################################
# Sample Level Calling   	       	    # 
#############################################

# we copy a template script to the working directory and add extra lines based on the variables file 

echo User Selected to Call CNVS: $callCNV

# If user has selected to call CNVS then add the relevant lines to the run_dragen.sh template script
if [[ "$callCNV" == true ]] && [[ $sampleId != *"NTC"* ]];
then

echo '--enable-cnv true \' >> commands/run_dragen_per_sample.sh
echo '--cnv-enable-self-normalization true \' >> commands/run_dragen_per_sample.sh 

fi

echo User Selected to Call Repeat Regions: $callRepeats
# Of user has selected to call repeat regions then add the relevant lines to the run_dragen.sh template script
if [[ "$callRepeats" == true ]] && [[ $sampleId != *"NTC"* ]];
then

echo '--repeat-genotype-enable true \' >> commands/run_dragen_per_sample.sh
echo "--repeat-genotype-specs config/"$panel"/smn-catalog.grch37.json  \\" >> commands/run_dragen_per_sample.sh
echo '--auto-detect-sample-sex true \' >> commands/run_dragen_per_sample.sh

fi

# run sample level script
bash commands/run_dragen_per_sample.sh $seqId $sampleId $pipelineName $pipelineVersion $panel $dragen_ref

# add gvcfs for joint SNP/Indel calling
if [ -e "$seqId"_"$sampleId".hard-filtered.gvcf.gz ]; then
    echo "$sampleId"/"$seqId"_"$sampleId".hard-filtered.gvcf.gz >> ../gVCFList.txt
fi


# add bam files for joint SV calling
if [[ -e "$seqId"_"$sampleId".bam ]] && [[ $sampleId != *"NTC"* ]]; then
    echo "--bam-input "$sampleId"/"$seqId"_"$sampleId".bam \\" >> ../BAMList.txt
fi


# add tn.tsv files for joint CNV calling 
if [[ -e "$seqId"_"$sampleId".tn.tsv ]] && [[ $sampleId != *"NTC"* ]]; then
    echo "--cnv-input "$sampleId"/"$seqId"_"$sampleId".tn.tsv \\" >> ../TNList.txt
fi


# expected number of gvcfs
expGVCF=$(ls -d ../*/ | wc -l)

# observed number
obsGVCF=$(wc -l < ../gVCFList.txt)

#############################################
# Joint Calling                             #
#############################################

if [ $expGVCF == $obsGVCF ]; then

    echo "performing joint genotyping of snps/indels"
     
    mv commands/joint_call_cnvs.sh ..
    mv commands/joint_call_svs.sh ..

    cd ..

    /opt/edico/bin/dragen \
        -r  $dragen_ref \
        --output-directory . \
        --output-file-prefix "$seqId" \
        --enable-joint-genotyping true \
        --variant-list gVCFList.txt \
        --strict-mode true \
     
    if [ $callCNV == true ]; then

        echo Joint Calling CNVs

        cat TNList.txt >> joint_call_cnvs.sh

        bash joint_call_cnvs.sh $seqId $panel $dragen_ref

    fi

    if [ $callSV == true ]; then

        echo Joint Calling SVs

        cat BAMList.txt >> joint_call_svs.sh

        bash joint_call_svs.sh $seqId $panel $dragen_ref

    fi


    # move results data - don't move symlinks fastqs
    if [ -d "$output_dir"/"$seqId"/"$panel" ]; then
        echo "$output_dir/$seqId/$panel already exists - cannot rsync"
        exit 1
    else

        mkdir -p "$output_dir"/"$seqId"/"$panel"
        rsync -azP --no-links . "$output_dir"/"$seqId"/"$panel"
    fi

    # mark results as complete - do this first so post processing can start asap
    touch "$output_dir"/"$seqId"/"$panel"/dragen_complete.txt
    touch "$output_dir"/"$seqId"/"$panel"/post_processing_required.txt

    # clean up staging results
    rm -r /staging/data/results/"$seqId"/"$panel"
    # clean up staging fastq
    rm -r /staging/data/fastq/"$seqId"/Data/"$panel"


    # clean up staging fastq if we have processed all panels
    if [ "$(ls -A /staging/data/fastq/"$seqId"/Data/)" ]; then
        echo "Not all panels processed - keeping staging fastq"
    else
        echo "All panels processed - removing staging fastq directory"
        rm -r /staging/data/fastq/"$seqId"/

    fi

    # clean up staging results if we have processed all panels
    if [ "$(ls -A /staging/data/results/"$seqId"/)" ]; then
        echo "Not all panels processed - keeping staging results"
    else
        echo "All panels processed - removing staging results directory"
        rm -r /staging/data/results/"$seqId"/

    fi

else
    echo "$sampleId is not the last sample"

fi



