#!/usr/bin/env bash
set -euo pipefail

scriptdir=$(cd $(dirname $0);pwd)
subjsdir=$scriptdir/../preproc/func
filename=nfaswdktm_func_4.nii.gz

# Find subj id
[ $# -ne 1 ] && echo "need a subject directory as first argument!" && exit 1
subjid=$(basename "$1")
s=$subjid
[ ! -d "$s" ] && s=$subjsdir/$s
[ ! -d "$s" ] && echo "cannot find subj dir ('$1' or '$s')" && exit 1

prefix=${subjid}_SOA

# Go to subj dir
cd $s/*SOA_bold
sdir=$(pwd);
s=$(basename $sdir)

# check for 4d file
fourdfile=$sdir/$filename
[ ! -r "$fourdfile" ] && echo "cannot find input file ($fourdfile)" && exit 1

# Set model type
model="GAM"
[ $# -ge 2 ] && model="$2"

# Find 1d files
oneddir=$scriptdir/1d/$subjid
[ ! -d "$oneddir" ] && echo "cannot find 1d dir ($oneddir)" && exit 1

# Find censor file
censorFile=$sdir/motion_info/fd_0.8_censor.1D
[ ! -r "$censorFile" ] && echo "cannot find censor file ($censorFile)" && exit 1


echo "Running!"

#SOA_grid.1d         SOA_L_deval_err.1d  SOA_L_val_err.1d    SOA_R_deval_err.1d  SOA_R_val_err.1d
#SOA_L_deval_cor.1d  SOA_L_val_cor.1d    SOA_R_deval_cor.1d  SOA_R_val_cor.1d    SOA_score.1d

# Run deconv
3dDeconvolve  \
    -input $fourdfile \
        -allzero_OK \
        -local_times \
        -polort 2 \
        -GOFORIT 8 \
        -jobs 32 \
        -censor $censorFile \
        -num_stimts 10 \
        -stim_times 1 $oneddir/SOA_L_val_cor.1d $model -stim_label 1 SOA_L_val_cor \
        -stim_times 2 $oneddir/SOA_L_val_err.1d $model -stim_label 2 SOA_L_val_err \
        -stim_times 3 $oneddir/SOA_L_deval_cor.1d $model -stim_label 3 SOA_L_deval_cor \
        -stim_times 4 $oneddir/SOA_L_deval_err.1d $model -stim_label 4 SOA_L_deval_err \
        -stim_times 5 $oneddir/SOA_R_val_cor.1d $model -stim_label 5 SOA_R_val_cor \
        -stim_times 6 $oneddir/SOA_R_val_err.1d $model -stim_label 6 SOA_R_val_err \
        -stim_times 7 $oneddir/SOA_R_deval_cor.1d $model -stim_label 7 SOA_R_deval_cor \
        -stim_times 8 $oneddir/SOA_R_deval_err.1d $model -stim_label 8 SOA_R_deval_err \
        -stim_times 9 $oneddir/SOA_score.1d $model -stim_label 9 SOA_score \
        -stim_times 10 $oneddir/SOA_grid.1d $model -stim_label 10 SOA_grid \
        -num_glt 9 \
        -gltsym 'SYM:.25*SOA_L_val_cor +.25*SOA_L_deval_cor +.25*SOA_R_val_cor +.25*SOA_R_deval_cor' -glt_label 1 cor \
        -gltsym 'SYM:.5*SOA_L_val_cor -.5*SOA_L_deval_cor +.5*SOA_R_val_cor -.5*SOA_R_deval_cor' -glt_label 2 val_vs_deval_cor \
        -gltsym 'SYM:.5*SOA_L_val_cor +.5*SOA_R_val_cor -.5*SOA_L_val_err -.5*SOA_R_val_err' -glt_label 3 val_cor_vs_err \
        -gltsym 'SYM:.5*SOA_L_deval_cor +.5*SOA_R_deval_cor -.5*SOA_L_deval_err -.5*SOA_R_deval_err' -glt_label 4 deval_cor_vs_err \
        -gltsym 'SYM:.5*SOA_L_val_cor +.5*SOA_R_val_cor -.5*SOA_L_deval_err -.5*SOA_R_deval_err' -glt_label 5 val_vs_deval_respond \
        -gltsym 'SYM:.5*SOA_L_deval_cor +.5*SOA_R_deval_cor' -glt_label 6 deval_cor \
        -gltsym 'SYM:.5*SOA_L_deval_err +.5*SOA_R_deval_err' -glt_label 7 deval_err \
        -gltsym 'SYM:.5*SOA_L_val_cor +.5*SOA_R_val_cor' -glt_label 8 val_cor \
        -gltsym 'SYM:.5*SOA_L_val_err +.5*SOA_R_val_err' -glt_label 9 val_err \
        -overwrite \
        -fout -tout -x1D Xmat.x1D -bucket ${prefix}_${model}_stats2 \
        -errts nfaswdktm_${model}_resid.nii.gz \
        > ${sdir}/deconv.log
