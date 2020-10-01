#!/usr/bin/env bash
set -euo pipefail
trap 'e=$?; [ $e -ne 0 ] && echo "$0 exited in error"' EXIT
env|grep -q ^DRYRUN= && DRYRUN=echo || DRYRUN=
env|grep -q ^OVERWRITE= && OVERWRITE="--overwrite" || OVERWRITE=

bidsdir=../bids
rawdir=../raw
#
# use heudiconv to make bids compatible dataset
#  20200930WF  init
for d in $rawdir/*/1*_2*/; do
   s=$(basename $d|cut -f1 -d_)
   nconv=$(find -L $bidsdir/sub-$s -iname '*nii.gz' 2>/dev/null |wc -l)
   [ -z "$OVERWRITE" -a $nconv -gt 0 ] &&
      echo "# skipping '$d': already have $nconv niftis" && continue
   $DRYRUN heudiconv $OVERWRITE -b -o $bidsdir -c dcm2niix -f $bidsdir/hconf.py  -d "$rawdir/20*/{subject}_*/*/*" -s $s
done
