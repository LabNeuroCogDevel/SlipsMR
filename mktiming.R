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
   # TODO: does no response make it throug filter??
   #   make make all NA -> False?
   d <- d %>%
      mutate(block=1,
             disp_side=substr(LR1, 0, 1),
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
  findcsv(infolder, 'SOA') %>% mktime(pfix=paste0(outfolder,'SOA'))
  findcsv(infolder, 'DD')  %>% mktime(pfix=paste0(outfolder,'DD'))

  # ID is special. we want to break up for "learning" contrasts
  idphase <- findcsv(infolder, 'ID') %>%
     mutate(score_block = 1+lag(cumsum(ttype=='TrialType.SCORE'),default=0),
            block_name  = cut(score_block,
                              c(0,2,4,6,8),
                              c("1-2","3-4","5-6","7-8")))
  idphase %>% mktime(pfix=paste0(outfolder,'ID'))



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
  for(bn in unique(idphase$block_name)) {
     blockedfolder <- paste(sep="/", outfolder, 'IDblks', bn)
     if(!dir.exists(blockedfolder)) dir.create(blockedfolder, recursive=T)
     # fake ID for learning
     mktime(idphase %>% filter(block_name == bn),
            pfix=paste0(blockedfolder,'/'))
  }
}

## do it for pilot
subjs_dirs <- Sys.glob('/Volumes/L/bea_res/Data/Tasks/SlipsOfAction/*/2*/')
discard <- lapply(subjs_dirs, mk1d_from_folder)

