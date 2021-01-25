#!/usr/bin/env bash



for f in 1d/*/blks/SOA_0deval.1d; do
	subj=$(echo $f|cut -d / -f2)
	echo $subj

	./deconvolve_block.bash $subj SOA
	./deconvolve_block.bash $subj DD

done

