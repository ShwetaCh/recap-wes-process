#!/bin/bash
#only if there are format issues, rerun vcf2maf for vep
#cmo_maf2maf --version 1.6.14 --vep-release 88 --input-maf data_mutations_unfiltered_93017_21batches.txt --outpput-maf data_mutations_unfiltered_93017_21batches.vep.maf

#--Edit this block
INPUT_MAF=Proj_06049_U___SOMATIC.vep.filtered.facets.V3.postprocessed.filter.maf
OUT_DIR=signatures
STUDY_ID="Proj_06049_U"
#-----------------

FILENAME=$(basename "$INPUT_MAF")
EXTENSION="${FILENAME##*.}"
PREFIX="${FILENAME%.*}"
echo $PREFIX
PDF_PLOT=${PREFIX}_mut_sig.pdf

#create snp-sorted input file

python /home/chavans/git/mutation-signatures/make_trinuc_maf.py \
  <(awk -F"\t" '{ if($1 == "Hugo_Symbol" || length($11) == 1 && length($13)==1)  print }' $INPUT_MAF) \
  $OUT_DIR/${PREFIX}_snpsorted.maf

#decompose

CI_CMD2="python /home/chavans/git/mutation-signatures/main.py \
  /home/chavans/git/mutation-signatures/Stratton_signatures30.txt \
  --spectrum_output $OUT_DIR/${PREFIX}_spectrum.txt \
  $OUT_DIR/${PREFIX}_snpsorted.maf \
  $OUT_DIR/${PREFIX}_snpsorted_decomposed.maf"

/common/lsf/9.1/linux2.6-glibc2.3-x86_64/bin/bsub \
-q sol -J mut_sig \
-cwd $OUT_DIR \
-e mut_sig1.stderr -o mut_sig1.stdout \
-We 00:59 -R "rusage[mem=5]" -M 10 -n 2 \
$CI_CMD2

#create bootstrapped input for CI calculation

/home/chavans/git/mutation-signatures/sigsig.R \
  $OUT_DIR/${PREFIX}_snpsorted.maf 1000 \
  $OUT_DIR/${PREFIX}_resamp.maf

#bsub CI calculation

CI_CMD="python /home/chavans/git/mutation-signatures/main.py \
  /home/chavans/git/mutation-signatures/Stratton_signatures30.txt \
  $OUT_DIR/${PREFIX}_resamp.maf $OUT_DIR/${PREFIX}_resampled_sig.txt"

echo $CI_CMD

/common/lsf/9.1/linux2.6-glibc2.3-x86_64/bin/bsub \
  -q sol -J mut_sig \
  -cwd $OUT_DIR \
  -e mut_sig.stderr -o mut_sig.stdout \
  -We 24:00 -R "rusage[mem=5]" -M 10 -n 20 \
  $CI_CMD

# -------------------------------------------------------------------------------------------------------------------
#run R script to get CI file

Rscript /home/chavans/git/mutation-signatures/sigsig_conf_int.R \
  $OUT_DIR/${PREFIX}_resampled_sig.txt \
  $OUT_DIR/${PREFIX}_conf_int.txt

#run R script to get the PDF plot # also creates the list file

Rscript /home/chavans/WES_QC_filters/scripts/plot_mut_sig.R \
  $OUT_DIR/${PREFIX}_snpsorted_decomposed.maf \
  $OUT_DIR/${PREFIX}_conf_int.txt \
  $OUT_DIR/$PDF_PLOT \
  $OUT_DIR/${STUDY_ID}_ListSignatures.txt
  












