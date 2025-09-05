#!/bin/bash

set -euo pipefail

# set max processes and open files as these differ between wren and head node
ulimit -S -u 16384
ulimit -S -n 65535

# Usage: cd /staging/data/results/$seqId/$panel/$sampleId && bash DragenWGS.sh

version=3.0.0

##############################################
# SETUP                                      #
##############################################

pipeline_dir="/mnt/Data-MSA/diagnostics/pipelines/"
output_dir="/mnt/Data-MSA/results/"
bcftools_path="/mnt/Data-MSA/diagnostics/apps/miniconda3/envs/bcftools/bin/"


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
echo "--repeat-genotype-specs config/builds/"$assembly"/repeat_spec_${assembly}.json  \\" >> commands/run_dragen_per_sample.sh
echo '--auto-detect-sample-sex true \' >> commands/run_dragen_per_sample.sh

fi

#Enable SMN and other gene specific callers
if [[ "$callTargeted" == true ]] && [[ $sampleId != *"NTC"* ]];
then

echo '--enable-targeted=true \' >> commands/run_dragen_per_sample.sh

fi

# run sample level script

bash commands/run_dragen_per_sample.sh $seqId $sampleId $pipelineName $pipelineVersion $panel $dragen_ref $assembly

touch "$seqId"_"$sampleId".mapping_metrics.csv


# add gvcfs for joint SNP/Indel calling
if [ -e "$seqId"_"$sampleId".hard-filtered.gvcf.gz ]; then
    echo "${output_dir}/${seqId}/${panel}/raw_vcf/${sampleId}/${seqId}_${sampleId}.hard-filtered.gvcf.gz" >> ../gVCFList.txt
fi


# add tn.tsv files for joint CNV calling 
if [[ -e "$seqId"_"$sampleId".tn.tsv.gz ]] && [[ $sampleId != *"NTC"* ]]; then
    echo "--cnv-input ${output_dir}/${seqId}/${panel}/raw_cnv_vcf/${sampleId}/${seqId}_${sampleId}.tn.tsv.gz \\" >> ../TNList.txt
fi

#Move over the sample results into the exact folder structure
#Alignments
if [ -d "$output_dir/$seqId/$panel/alignments/$sampleId/" ]; then
        echo "$output_dir/$seqId/$panel/alignments/$sampleId/ already exists"
else
        mkdir $output_dir/$seqId/$panel/alignments/$sampleId/
fi
mv ${seqId}_${sampleId}.cram* $output_dir/$seqId/$panel/alignments/$sampleId/
#VCFs
if [ -d "$output_dir/$seqId/$panel/raw_vcf/$sampleId/" ]; then
        echo "$output_dir/$seqId/$panel/raw_vcf/$sampleId/ already exists"
else
        mkdir $output_dir/$seqId/$panel/raw_vcf/$sampleId/
fi
mv ${seqId}_${sampleId}.hard-filtered.gvcf.gz* $output_dir/$seqId/$panel/raw_vcf/$sampleId/
#CNVs
if [ -d "$output_dir/$seqId/$panel/raw_cnv_vcf/$sampleId/" ]; then
        echo "$output_dir/$seqId/$panel/raw_cnv_vcf/$sampleId/ already exists"
else
        mkdir $output_dir/$seqId/$panel/raw_cnv_vcf/$sampleId/
fi
if [ -e "${seqId}_${sampleId}.tn.tsv.gz" ]; then
	mv ${seqId}_${sampleId}.tn.tsv.gz $output_dir/$seqId/$panel/raw_cnv_vcf/$sampleId/
	mv ${seqId}_${sampleId}.target.counts.bw $output_dir/$seqId/$panel/raw_cnv_vcf/$sampleId/
	mv ${seqId}_${sampleId}.cnv_metrics.csv $output_dir/$seqId/$panel/raw_cnv_vcf/$sampleId/
fi
#Repeats
if [ -d "$output_dir/$seqId/$panel/raw_repeat_vcf/$sampleId/" ]; then
        echo "$output_dir/$seqId/$panel/raw_repeat_vcf/$sampleId/ already exists"
else
        mkdir $output_dir/$seqId/$panel/raw_repeat_vcf/$sampleId/
fi
if [ -e "${seqId}_${sampleId}.repeats.vcf.gz" ]; then
	mv ${seqId}_${sampleId}.repeats.vcf* $output_dir/$seqId/$panel/raw_repeat_vcf/$sampleId/
fi
if [ -d "$output_dir/$seqId/$panel/repeat_alignments/$sampleId/" ]; then
        echo "$output_dir/$seqId/$panel/repeat_alignments/$sampleId/ already exists"
else
        mkdir $output_dir/$seqId/$panel/repeat_alignments/$sampleId/
fi
if [ -e "${seqId}_${sampleId}.repeats.bam" ]; then
	mv ${seqId}_${sampleId}.repeats.bam $output_dir/$seqId/$panel/repeat_alignments/$sampleId/
fi
#Variables
mv ${sampleId}.variables $output_dir/$seqId/$panel/variables
#Metrics
if [ -d "$output_dir/$seqId/$panel/metrics/$sampleId/" ]; then
        echo "$output_dir/$seqId/$panel/metrics/$sampleId/ already exists"
else
        mkdir $output_dir/$seqId/$panel/metrics/$sampleId/
fi
mv ${seqId}_${sampleId}.mapping_metrics.csv $output_dir/$seqId/$panel/metrics/$sampleId/
mv ${seqId}_${sampleId}.ploidy_estimation_metrics.csv $output_dir/$seqId/$panel/metrics/$sampleId/
mv ${seqId}_${sampleId}.qc-coverage-region-1_coverage_metrics.csv $output_dir/$seqId/$panel/metrics/$sampleId/
mv ${seqId}_${sampleId}.vc_metrics.csv $output_dir/$seqId/$panel/metrics/$sampleId/
mv ${seqId}_${sampleId}.wgs_coverage_metrics.csv $output_dir/$seqId/$panel/metrics/$sampleId/
#Tar up everything else
mkdir ${sampleId}_analysis
mv ${seqId}_* ${sampleId}_analysis
mv *_usage.txt ${sampleId}_analysis
mv fastqs.csv ${sampleId}_analysis
mv streaming_log_dragen.csv ${sampleId}_analysis
tar -czvf ${sampleId}_analysis.tar.gz ${sampleId}_analysis/
mv ${sampleId}_analysis.tar.gz $output_dir/$seqId/$panel/archive



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
    mv commands/create_ped.py ..
    mv commands/by_family.py ..    

    cd ..

    /opt/edico/bin/dragen \
        -r  $dragen_ref \
        --output-directory . \
        --output-file-prefix "$seqId" \
        --vc-enable-joint-detection true \
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

        python create_ped.py --variables '/mnt/Data-MSA/results/'"$seqId"'/'"$panel"'/variables/*.variables' > "$seqId".ped

        python by_family.py "$seqId".ped "$seqId" "$panel"
        
        mkdir sv_calling
	mkdir temp_crams

        for family in *_for_sv.family; do 
         
	   #Need to copy the crams back. This loop reads the family file, removes the line breaks at the end of the line, pulls the name of the cram file from the line and appends it onto the end of a path to copy the cram back
	   #This is because the cram files are too big to be read over the samba share between the dragen and the vstor
	   while IFS= read -r line; do
	       clean_line="${line% \\}"
	       path=$(echo "$clean_line" | cut -f 2 -d " " | cut -f 2 -d "/")
	       cp /mnt/Data-MSA/results/$seqId/$panel/alignments/*/${path}* temp_crams/
           done < $family

           cp joint_call_svs.sh joint_call_svs.sh_"$family".sh
           cat $family >> joint_call_svs.sh_"$family".sh
           bash joint_call_svs.sh_"$family".sh $family $dragen_ref $fasta

           rm joint_call_svs.sh_"$family".sh
	   rm temp_crams/*
           
        done

        #Adding in if statement if only a single family as bcftools merge doesn't work with a single vcf
	if [ `ls -1 sv_calling/*vcf.gz | wc -l` -eq 1 ]; then
        	cp sv_calling/*.vcf.gz "$seqId".sv.vcf.gz
	else
		   ${bcftools_path}/bcftools merge -m none -F x sv_calling/*.vcf.gz > "$seqId".sv.vcf
	       ${bcftools_path}/bgzip "$seqId".sv.vcf
	fi
        
        ${bcftools_path}/tabix "$seqId".sv.vcf.gz

        md5sum "$seqId".sv.vcf.gz | cut -d" " -f 1 > "$seqId".sv.vcf.gz.md5sum

        
        rm -r sv_calling
        rm *.family
        rm create_ped.py
        rm by_family.py
    fi

    #Copy everything else
    #ped
    if [ -d "$output_dir/$seqId/$panel/ped/" ]; then
        echo "$output_dir/$seqId/$panel/ped/ already exists"
    else
        mkdir $output_dir/$seqId/$panel/ped/
    fi
    mv ${seqId}.ped $output_dir/$seqId/$panel/ped/
    #SV
    mv ${seqId}.sv.vcf.gz* $output_dir/$seqId/$panel/raw_sv_vcf/
    #CNV
    mv ${seqId}.cnv.vcf.gz* $output_dir/$seqId/$panel/raw_cnv_vcf/
    mv ${seqId}.cnv_metrics.csv $output_dir/$seqId/$panel/raw_cnv_vcf/
    #VCFs
    mv ${seqId}.vcf.gz* $output_dir/$seqId/$panel/raw_vcf/
    mv ${seqId}.hard-filtered.vcf.gz* $output_dir/$seqId/$panel/raw_vcf/
    #Variables
    mv ${panel}.variables $output_dir/$seqId/$panel/
    #Metrics
    mv ${seqId}.time_metrics.csv $output_dir/$seqId/$panel/metrics
    mv ${seqId}.vc_hethom_ratio_metrics.csv $output_dir/$seqId/$panel/metrics
    mv ${seqId}.vc_metrics.csv $output_dir/$seqId/$panel/metrics

    # mark results as complete - do this first so post processing can start asap
    touch "$output_dir"/"$seqId"/"$panel"/dragen_complete.txt
    touch "$output_dir"/"$seqId"/"$panel"/post_processing_required.txt

    # clean up staging results
    rm -r /staging/data/results/"$seqId"/"$panel"
    # clean up staging fastq
    if [ -d "/staging/data/fastq/$seqId/Data/$panel" ]; then
        rm -r /staging/data/fastq/"$seqId"/Data/"$panel"
    else
	rm -r /mnt/Data-MSA/results/"$seqId"/fastq/Data/"$panel"
    fi

    # clean up staging fastq if we have processed all panels
    if [ -d "/staging/data/fastq/$seqId" ]; then
        if [ "$(ls -A /staging/data/fastq/"$seqId"/Data/)" ]; then
            echo "Not all panels processed - keeping staging fastq"
	else
            echo "All panels processed - removing staging fastq directory"
	    rm -r /staging/data/fastq/"$seqId"/
        fi
    else
	if [ "$(ls -A /mnt/Data-MSA/results/"$seqId"/fastq/Data/)" ]; then
            echo "Not all panels processed - keeping staging fastq"
        else
            echo "All panels processed - removing staging fastq directory"
            rm -r /mnt/Data-MSA/results/"$seqId"/fastq/
        fi

    fi

    # clean up staging results if we have processed all panels
    if [ "$(ls -A /staging/data/results/"$seqId"/)" ]; then
        echo "Not all panels processed - keeping staging results"
    else
        echo "All panels processed - removing staging results directory"
        rm -r /staging/data/results/"$seqId"/

    fi

    # Remove lock file from dragen
    rm /mnt/Data-MSA/raw/dragen_markers/${seqId}_*_locked

else
    echo "$sampleId is not the last sample"

fi



