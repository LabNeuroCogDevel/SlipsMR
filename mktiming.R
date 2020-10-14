#!/usr/bin/env Rscript

#
# write 1d files for all subjects
# outpus like 
#  1d/$id/{ID,OD,SOA,DD}_score.1d 
#  1d/$id/{ID,OD,SOA,DD}_{L,R}_val_{err,cor}.1d 
#  1d/$id/{OD,SOA,DD}_{L,R}_deval_{err,cor}.1d 
#  1d/$id/{SOA,DD}_grid.1d 
#
OVERWRITE = FALSE

suppressPackageStartupMessages({
   library(dplyr)})

mktime <- function(d, pfix) {
   phase <- unique(d$phase) %>% gsub('PhaseType.', '', .)
   if(length(phase) != 1L){
      cat("# bad input dataframe! have phases: ", paste(phase, collapse=','))
      return()
    }
   
   # use save1D to make e.g. "$subj/DD_grid.1d"
   quicksave <- function(., name){
      out1d <- ifelse(grepl('/$',pfix),
                      sprintf("%s%s.1d",pfix,name),
                      sprintf("%s_%s.1d",pfix,name))
      if(nrow(.) == 0L) {
         cat('# WARNING:', pfix, 'no rows for', name, '\n')
         sink(out1d); cat('*\n'); sink()
         return()
      }
      cat("# writting", out1d, "\n")
      #print(.)
      LNCDR::save1D(., 'onset', out1d)
   }

   # all one block. set side deval and if response was correct
   # ID_{start,end} should already have blocks set
   if(! "block" %in% names(d)) d$block <- 1

   d <- d %>%
      mutate(disp_side=substr(LR1, 0, 1),
             deval=deval=='True',
             resp_cor=ifelse(deval, score_raw > -1, score_raw >= 1))

   # grid and score
   d %>% filter(ttype=='TrialType.SCORE') %>% quicksave('score')
   if(phase %in% c("DD","SOA")) 
      d %>% filter(ttype=='TrialType.GRID') %>% quicksave('grid')

   # save e.g. 'L_deval_cor.1d'
   devalname <- list('TRUE'='deval','FALSE'='val')
   corname <- list('TRUE'='cor','FALSE'='err')

   # ID only has valued options
   # do not want to write out a bunch of nulls
   deval_opts = c(T,F)
   if(phase == "ID") deval_opts = c(F)

   for(side in c('L', 'R')){
      for(isdeval in deval_opts){
         for(iscor in c(T, F)) {
            # like "L_deval_cor"
            outname <- paste(side,
                             devalname[[as.character(isdeval)]],
                             corname[[as.character(iscor)]],
                             sep="_")
            #print(outname)
            d %>%
               filter(ttype=='TrialType.SHOW',
                      disp_side==side,
                      deval==isdeval,
                      resp_cor==iscor) %>%
               quicksave(outname)
         }
      }
   }
}

# find last csv file for a given phase name
# if multiple, should be sorted by time stamp in filename
# do not want "wide" versions
# TODO: check length is > 230?
findcsv <- function(path, phase)
   paste0(path, '/', phase,'_*.csv') %>% Sys.glob %>%
     grep(pattern="wide", value=T, invert=T) %>%
     last %>% read.csv

mk1d_from_folder <- function(infolder){
  subj <- gsub('.*SlipsOfAction/|/$','', infolder) %>% gsub('/','_',.)
  subj <- gsub('_.*','', subj)
  outfolder <- sprintf('1d/%s/', subj)
  
  if(dir.exists(outfolder) && !OVERWRITE){
     cat("# skipping: already have", outfolder, "\n")
     return()
  }

  if(!dir.exists(outfolder))
     dir.create(outfolder,recursive=T)

  findcsv(infolder, 'OD')  %>% mktime(pfix=paste0(outfolder,'OD'))

  soa_data <- findcsv(infolder, 'SOA') 
  dd_data <- findcsv(infolder, 'DD') 
  # old version doesn't have blocks
  if(! 'extra' %in% names(soa_data)){
     cat("# old soa input, skipping 1d files creation for", infolder, "\n")
     return()
   }

  soa_data  %>%
      fix_bad_onsets %>%
      mktime(pfix=paste0(outfolder,'SOA'))
  dd_data %>%
      fix_bad_onsets %>%
      mktime(pfix=paste0(outfolder,'DD'))

  ## ID is special. we want to break up for "learning" contrasts
  # # 20201008 - OLD if we had ID as one long run
  # idphase <- findcsv(infolder, 'ID_[0-9]') %>%
  #    mutate(score_block = 1+lag(cumsum(ttype=='TrialType.SCORE'),default=0),
  #           block_name  = cut(score_block,
  #                             c(0,2,4,6,8),
  #                             c("1-2","3-4","5-6","7-8")))
  # idphase %>% mktime(pfix=paste0(outfolder,'ID'))
  # > idphase %>% select(score_block,block_name) %>% distinct
  # score_block block_name
  #           1        1-2
  #           2        1-2
  #           3        3-4
  #           4        3-4
  #           5        5-6
  #           6        5-6
  #           7        7-8
  #           8        7-8

  # 20201008 - truncated ID in two sets. merge back together
  idphase_start <- findcsv(infolder, 'ID_start') %>%
     mutate(block=1, block_name  = "start")
  idphase_end <- findcsv(infolder, 'ID_end') %>%
     mutate(block=2, block_name  = "end")
  idphase <- rbind(idphase_start, idphase_end)
  idphase %>% mktime(pfix=paste0(outfolder,'ID'))



  for(bn in unique(idphase$block_name)) {
     blockedfolder <- paste(sep="/", outfolder, 'IDblks', bn)
     if(!dir.exists(blockedfolder)) dir.create(blockedfolder, recursive=T)
     # fake ID for learning
     mktime(idphase %>% filter(block_name == bn),
            pfix=paste0(blockedfolder,'/'))
  }

  # block format for SOA and DD
  # TODO!!
  blkdir <- paste(sep="/", outfolder, 'blks')
  if(!dir.exists(blkdir)) dir.create(blkdir, recursive=T)

  cat("# by block")
  cat("# writting SOA.1d and DD.1d to", blkdir,"\n")
  soa_blk <- soa_data %>% to_block %>%
      LNCDR::save1D('onset', file.path(blkdir,"SOA.1d"), dur='dur', nblocks=1)
  dd_blk <- dd_data %>% to_block %>%
      LNCDR::save1D('onset', file.path(blkdir,"DD.1d"), dur='dur', nblocks=1)


   write_byndeval <- function(d, name) {
      filter(d, extra != "None") %>%
           mutate(ndeval=stringr::str_match(extra, '\\d$')) %>%
           split(.$ndeval) %>%
           lapply(function(x){
                     ndeval <- first(x$ndeval)
                     outfile <- file.path(blkdir,sprintf("%s_%sdeval.1d",name, ndeval))
                     cat("#  ",outfile,"\n")
                     x %>% to_block %>% LNCDR::save1D('onset', outfile, dur='dur', nblocks=1)
           })

   }
  soa_blkval <- soa_data %>% write_byndeval('SOA')
  dd_blkval <- dd_data %>% write_byndeval('DD')
}

fix_bad_onsets <- function(soadd) {
    # pilot did not set onset time for GRID and SCORE (it's negative starttime instaed)
    bad_grid <- which(grepl("GRID", soadd$ttype) & soadd$onset < 0)
    soadd$onset[bad_grid] <- soadd$onset[bad_grid +1] - 5
    bad_score <- which(grepl("SCORE", soadd$ttype) & soadd$onset < 0)
    soadd$onset[bad_score] <- soadd$onset[bad_score -1] +
        soadd$rt_raw[bad_score -1]
    return(soadd)
}

to_block <- function(d_all, iti_time=40) {
  d <- filter(d_all, grepl("SHOW",ttype))
  start_idx <- which(c(Inf,diff(d$onset)) >= iti_time)
  end_idx <- c(start_idx[-1] - 1, nrow(d))
  # N.B. group_by(extra) doesn't work because repeated. 2x {DD|SOA}_2 and {DD|SOA}_4
  blk_df <- d[start_idx, c('extra', 'onset')] %>%
      mutate(onset = onset,
             end = d$onset[end_idx],
             last_tr = d$rt_raw[end_idx],
             dur = end - onset + last_tr,
             n = 1:n(),
             block=1)

}

## do it for pilot
subjs_dirs <- Sys.glob('/Volumes/L/bea_res/Data/Tasks/SlipsOfAction/*/2*/')
discard <- lapply(subjs_dirs, mk1d_from_folder)

