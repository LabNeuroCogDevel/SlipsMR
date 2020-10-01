#!/usr/bin/env bash
set -euo pipefail
trap 'e=$?; [ $e -ne 0 ] && echo "$0 exited in error"' EXIT

#
# run preprocessFunctional using lncdprep
# 
# NB. !!hard linked!! in 
#   /Volumes/Hera/Projects/SlipsOfAction
#   /Volumes/Hera/preproc/Slips
#
#  20200930WF  init

lncdprep /Volumes/Hera/Raw/BIDS/SlipsPilot /Volumes/Hera/preproc/Slips --task 
