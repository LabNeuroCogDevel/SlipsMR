.SUFFIXES:
.PHONY: always all

all: glm 

## raw file lists
.make: 
	mkdir .make

.make/raw_dirs.ls: always  | .make
	mkls $@ '../raw/2*/1*_2*/'

.make/task_dirs.ls: always | .make
	mkls $@ '/Volumes/L/bea_res/Data/Tasks/SlipsOfAction/1*'

## BIDS
.make/bids_dir.ls: .make/raw_dirs.ls
	./00_mkBIDS.bash
	mkls $@ '../bids/sub-*/*/*.nii.gz'

## PREPROC
.make/preproc_dirs.ls: .make/bids_dir.ls
	#DRYRUN=1 ./01_preproc_all.bash
	mkls $@ '../preproc/func/*/*_bold/'

## GLM prep
.make/1d_dirs.ls: .make/task_dirs.ls
	./mktiming.R

glm: .make/1d_dirs.ls .make/preproc_dirs.ls
	#mkls $@ ../
