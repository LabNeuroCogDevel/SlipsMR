#!/usr/bin/env bash
set -euo pipefail

scriptdir=$(cd $(dirname $0);pwd)
subjsdir=$scriptdir/../preproc/func
filename=nfaswdktm_func_4.nii.gz
prefix=ID

# Find subj id
[ $# -ne 1 ] && echo "need a subject directory as first argument!" && exit 1
subjid=$(basename "$1")
s=$subjid
[ ! -d "$s" ] && s=$subjsdir/$s
[ ! -d "$s" ] && echo "cannot find subj dir ('$1' or '$s')" && exit 1

# Go to subj dir
cd $s/*ID_bold
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

# Run deconv
3dDeconvolve  \
    -input $fourdfile \
        -allzero_OK \
        -local_times \
        -polort 2 \
        -GOFORIT 2 \
        -jobs 32 \
        -censor $censorFile \
        -num_stimts 5 \
        -stim_times 1 $oneddir/ID_L_val_cor.1d $model -stim_label 1 ID_L_cor \
        -stim_times 2 $oneddir/ID_L_val_err.1d $model -stim_label 2 ID_L_err \
        -stim_times 3 $oneddir/ID_R_val_cor.1d $model -stim_label 3 ID_R_cor \
        -stim_times 4 $oneddir/ID_R_val_err.1d $model -stim_label 4 ID_R_err \
        -stim_times 5 $oneddir/ID_score.1d $model -stim_label 5 ID_score \
        -num_glt 3 \
        -gltsym 'SYM:.5*ID_L_cor +.5*ID_R_cor' -glt_label 1 cor \
        -gltsym 'SYM:.5*ID_L_cor +.5*ID_R_cor -.5*ID_L_err -.5*ID_R_err' -glt_label 2 cor_vs_err \
        -gltsym 'SYM:.5*ID_L_cor -.5*ID_R_cor +.5*ID_L_err -.5*ID_R_err' -glt_label 3 L_vs_R \
        -overwrite \
        -fout -tout -x1D Xmat.x1D -bucket ${prefix}_${model}_stats2 \
        -errts nfswdktm_${model}_resid.nii.gz \
        > ${sdir}/deconv.log
