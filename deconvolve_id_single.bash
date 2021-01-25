#!/usr/bin/env bash
set -euo pipefail
env |grep -q ^DRYRUN= && DRYRUN=echo || DRYRUN=""
[ -n "$DRYRUN" ] && DRYTEE(){ tee;} || DRYEE(){ echo "# would save output to $@"; cat;}

scriptdir=$(cd $(dirname $0);pwd)
subjsdir=$scriptdir/../preproc/func
filename=nfaswdktm_func_4.nii.gz

# Find subj id
[ $# -ne 1 ] && echo "need a subject directory as first argument!" && exit 1
subjid=$(basename "$1")
s=$subjid
[ ! -d "$s" ] && s=$subjsdir/$s
[ ! -d "$s" ] && echo "cannot find subj dir ('$1' or '$s')" && exit 1

prefix=${subjid}_ID

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
oneddir=$scriptdir/1d/$subjid/IDblks
[ ! -d "$oneddir" ] && echo "cannot find 1d dir ($oneddir)" && exit 1

# Find censor file
censorFile=$sdir/motion_info/fd_0.8_censor.1D
[ ! -r "$censorFile" ] && echo "cannot find censor file ($censorFile)" && exit 1

cd ..
pwd

echo "Running!"

# Run deconv
3dDeconvolve  \
    -input $fourdfile \
        -allzero_OK \
        -local_times \
        -polort 2 \
        -GOFORIT 32 \
        -jobs 32 \
        -censor $censorFile \
        -num_stimts 20 \
        -stim_times 1 $oneddir/1-2/L_val_cor.1d  $model -stim_label 1 block1_L_cor \
        -stim_times 2 $oneddir/1-2/L_val_err.1d  $model -stim_label 2 block1_L_err \
        -stim_times 3 $oneddir/1-2/R_val_cor.1d  $model -stim_label 3 block1_R_cor \
        -stim_times 4 $oneddir/1-2/R_val_err.1d  $model -stim_label 4 block1_R_err \
        -stim_times 5 $oneddir/1-2/score.1d      $model -stim_label 5 block1_score \
        -stim_times 6 $oneddir/3-4/L_val_cor.1d  $model -stim_label 6 block2_L_cor \
        -stim_times 7 $oneddir/3-4/L_val_err.1d  $model -stim_label 7 block2_L_err \
        -stim_times 8 $oneddir/3-4/R_val_cor.1d  $model -stim_label 8 block2_R_cor \
        -stim_times 9 $oneddir/3-4/R_val_err.1d  $model -stim_label 9 block2_R_err \
        -stim_times 10 $oneddir/3-4/score.1d     $model -stim_label 10 block2_score \
        -stim_times 11 $oneddir/5-6/L_val_cor.1d $model -stim_label 11 block3_L_cor \
        -stim_times 12 $oneddir/5-6/L_val_err.1d $model -stim_label 12 block3_L_err \
        -stim_times 13 $oneddir/5-6/R_val_cor.1d $model -stim_label 13 block3_R_cor \
        -stim_times 14 $oneddir/5-6/R_val_err.1d $model -stim_label 14 block3_R_err \
        -stim_times 15 $oneddir/5-6/score.1d     $model -stim_label 15 block3_score \
        -stim_times 16 $oneddir/7-8/L_val_cor.1d $model -stim_label 16 block4_L_cor \
        -stim_times 17 $oneddir/7-8/L_val_err.1d $model -stim_label 17 block4_L_err \
        -stim_times 18 $oneddir/7-8/R_val_cor.1d $model -stim_label 18 block4_R_cor \
        -stim_times 19 $oneddir/7-8/R_val_err.1d $model -stim_label 19 block4_R_err \
        -stim_times 20 $oneddir/7-8/score.1d     $model -stim_label 20 block4_score \
        -num_glt 3 \
        -gltsym 'SYM:.5*block1_L_cor +.5*block1_R_cor' -glt_label 1 early_cor \
        -gltsym 'SYM:.5*block4_L_cor +.5*block4_R_cor' -glt_label 2 late_cor \
        -gltsym 'SYM:.5*block4_L_cor +.5*block4_R_cor -.5*block1_L_cor -.5*block1_R_cor' -glt_label 3 cor_late_early \
        -overwrite \
        -fout -tout -x1D Xmat.x1D -bucket ${prefix}_${model}_stats2 \
        -errts nfaswdktm_${model}_resid.nii.gz
