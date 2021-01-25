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
cd $s/*IDshort_run-01_bold
sdir1=$(pwd);
fourdfile1=$sdir1/$filename
[ ! -r "$fourdfile1" ] && echo "cannot find input file ($fourdfile1)" && exit 1

cd $s/*IDshort_run-02_bold
sdir2=$(pwd);
fourdfile2=$sdir2/$filename
[ ! -r "$fourdfile2" ] && echo "cannot find input file ($fourdfile2)" && exit 1

echo $fourdfile1
echo $fourdfile2

cd $s
pwd

# Set model type
model="GAM"
[ $# -ge 2 ] && model="$2"

# Find 1d files
oneddir=$scriptdir/1d/$subjid/IDblks
[ ! -d "$oneddir" ] && echo "cannot find 1d dir ($oneddir)" && exit 1

# Find censor file
censorFile1=$sdir1/motion_info/fd_0.8_censor.1D
[ ! -r "$censorFile1" ] && echo "cannot find censor file ($censorFile1)" && exit 1
censorFile2=$sdir2/motion_info/fd_0.8_censor.1D
[ ! -r "$censorFile2" ] && echo "cannot find censor file ($censorFile2)" && exit 1

censorFile="merged_cens_fd_0.8.1D"
cat $censorFile1 > $censorFile
cat $censorFile2 >> $censorFile

echo "Running!"

# Run deconv
3dDeconvolve  \
    -input $fourdfile1 $fourdfile2 \
        -allzero_OK \
        -local_times \
        -polort 2 \
        -GOFORIT 32 \
        -jobs 32 \
        -censor $censorFile \
        -num_stimts 10 \
        -stim_times 1 $oneddir/start/L_val_cor.1d  $model -stim_label 1 block1_L_cor \
        -stim_times 2 $oneddir/start/L_val_err.1d  $model -stim_label 2 block1_L_err \
        -stim_times 3 $oneddir/start/R_val_cor.1d  $model -stim_label 3 block1_R_cor \
        -stim_times 4 $oneddir/start/R_val_err.1d  $model -stim_label 4 block1_R_err \
        -stim_times 5 $oneddir/start/score.1d      $model -stim_label 5 block1_score \
        -stim_times 6 $oneddir/end/L_val_cor.1d  $model -stim_label 6 block4_L_cor \
        -stim_times 7 $oneddir/end/L_val_err.1d  $model -stim_label 7 block4_L_err \
        -stim_times 8 $oneddir/end/R_val_cor.1d  $model -stim_label 8 block4_R_cor \
        -stim_times 9 $oneddir/end/R_val_err.1d  $model -stim_label 9 block4_R_err \
        -stim_times 10 $oneddir/end/score.1d     $model -stim_label 10 block4_score \
        -num_glt 3 \
        -gltsym 'SYM:.5*block1_L_cor +.5*block1_R_cor' -glt_label 1 early_cor \
        -gltsym 'SYM:.5*block4_L_cor +.5*block4_R_cor' -glt_label 2 late_cor \
        -gltsym 'SYM:.5*block4_L_cor +.5*block4_R_cor -.5*block1_L_cor -.5*block1_R_cor' -glt_label 3 cor_late_early \
        -overwrite \
        -fout -tout -x1D Xmat.x1D -bucket ${prefix}_${model}_stats2 \
        -errts nfaswdktm_${model}_resid.nii.gz
