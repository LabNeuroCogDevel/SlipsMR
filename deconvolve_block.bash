?®#!/usr/bin/env bash
set -euo pipefail

scriptdir=$(cd $(dirname $0);pwd)
subjsdir=$scriptdir/../preproc/func
filename=nfaswdktm_func_4.nii.gz

# Find subj id
[ -z "$1" ] && echo "need a subject directory as first argument!" && exit 1
subjid=$(basename "$1")
s=$subjid
[ ! -d "$s" ] && s=$subjsdir/$s
[ ! -d "$s" ] && echo "cannot find subj dir ('$1' or '$s')" && exit 1

# Get task type
#1d/11688/blks/:
#DD_0deval.1d  DD.1d  DD_2deval.1d  DD_4deval.1d  SOA_0deval.1d  SOA.1d  SOA_2deval.1d  SOA_4deval.1d
[ -z "$2" ]&& echo "need a task type as second argument (DD or SOA)" && exit 1
tasktype=$2



prefix=${subjid}_${tasktype}

# Go to subj dir
#sub-11765_task-SOAblk_bold
cd $s/*${tasktype}blk_bold
sdir=$(pwd);
s=$(basename $sdir)

# check for 4d file
fourdfile=$sdir/$filename
[ ! -r "$fourdfile" ] && echo "cannot find input file ($fourdfile)" && exit 1

# Set model type
model="dmBLOCK"
[ $# -ge 3 ] && model="$3"

# Find 1d files
oneddir=$scriptdir/1d/$subjid/blks/
[ ! -d "$oneddir" ] && echo "cannot find 1d dir ($oneddir)" && exit 1

# Find censor file
censorFile=$sdir/motion_info/fd_0.8_censor.1D
[ ! -r "$censorFile" ] && echo "cannot find censor file ($censorFile)" && exit 1


echo "Subj $subjid, input $fourdfile, condition $tasktype... Running!"
3dinfo $fourdfile

#1d files:
# DD_0deval.1d  DD.1d  DD_2deval.1d  DD_4deval.1d  SOA_0deval.1d  SOA.1d  SOA_2deval.1d  SOA_4deval.1d

echo "Logging to ${sdir}/deconv.log"
# Run deconv
3dDeconvolve  \
    -input $fourdfile \
        -allzero_OK \
        -local_times \
        -polort 2 \
        -GOFORIT 8 \
        -jobs 32 \
        -censor $censorFile \
        -num_stimts 3 \
        -stim_times_AM1 1 $oneddir/${tasktype}_0deval.1d $model -stim_label 1 0deval \
        -stim_times_AM1 2 $oneddir/${tasktype}_2deval.1d $model -stim_label 2 2deval \
        -stim_times_AM1 3 $oneddir/${tasktype}_4deval.1d $model -stim_label 3 4deval \
        -num_glt 5 \
	-gltsym 'SYM:.33*0deval +.33*2deval +.33*4deval' -glt_label 1 allblocks \
	-gltsym 'SYM:.5*4deval +.5*2deval -1*4deval' -glt_label 2 deval_vs_0deval \
	-gltsym 'SYM:4deval -1*0deval' -glt_label 3 4deval_vs_0deval \
	-gltsym 'SYM:2deval -1*0deval' -glt_label 4 2deval_vs_0deval \
	-gltsym 'SYM:4deval -1*2deval' -glt_label 5 4deval_vs_2deval \
        -overwrite \
        -fout -tout -x1D Xmat.x1D -bucket ${prefix}_${model}_stats2 \
        -errts nfaswdktm_${model}_resid.nii.gz \
        > ${sdir}/deconv.log
