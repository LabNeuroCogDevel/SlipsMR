 library(dplyr)
 library(glue)
 library(ggplot2)
 library(tidyr)
 library(cowplot)
 theme_set(theme_cowplot()) 
#remotes::install_github("coolbutuseless/ggpattern")


get_ids <- function(f_name){
   stringr::str_match(f_name, '(?<=/)\\d{5}[^/]*') %>% unique
}
get_files <- function(subjid) {
  cat(glue("# getting files: {subjid}"),"\n")
  files <- Sys.glob(glue('/Volumes/L/bea_res/Data/Tasks/SlipsOfAction/{subjid}*/*/*.csv'))
}


SOADD_data <- function(files) {

  cat("## SOADD\n")
  soadd <- files %>%
    grep(., pattern='DD|SOA', value=T) %>%
    lapply(read.csv) %>%
    bind_rows %>%
    separate(extra,c('task','ndeval')) %>%
    filter(ttype == "TrialType.SHOW") %>%
    mutate(deval = deval == 'True',
	   resp_type = case_when(
	     resp_raw != "None" & score_raw %in% c(-1, 1) ~ "correct_dir",
	     resp_raw != "None" & score_raw == 0          ~ "wrong_dir", 
	     resp_raw == "None"                           ~ "None",
	     TRUE                                         ~ "unkown_state"),
    trial_type=ifelse(deval,'devalued','valued'))

  # before we had a "ver" column, inside and outside fruit were swapped!
  # wasn't used (yet)
  if(!'ver' %in% names(soadd)){
      cat("# WARNING: swaping inside and outside fruit columns b/c old version of output\n")
      outside_swap <- soadd$fruit_inside
      soadd$fruit_inside <- soadd$fruit_outside
      soadd$fruit_outside <- outside_swap
  }
  return(soadd)
}

plot_SOADD <-function (files) { 
  subjid <- get_ids(files)
  soadd <- SOADD_data(files)

  plt_correct <-
    ggplot(soadd) +
    aes(x=resp_type, fill=trial_type) +
    geom_bar(stat="count")+
    facet_grid(task~ndeval) +
    scale_fill_manual(values=c("pink","lightgreen")) +
    theme(axis.text.x=element_text(angle=20, hjust=1))

  soadd_smry <- soadd %>%
    mutate(responded = resp_raw!="None") %>%
    group_by(deval, task, ndeval) %>%
    mutate(total_trials=n()) %>%
    group_by(responded, deval, task, ndeval, total_trials) %>%
    tally() %>%
    mutate(trial_type=ifelse(deval,'devalued','valued'),
           rat = n/total_trials) 

  plt_resp <-
    ggplot(soadd_smry)+
    aes(x=trial_type, y=rat, fill=responded, label=paste(n,"/",total_trials))+
    geom_bar(stat="identity")+
    geom_label(data=soadd_smry%>%filter(!responded), aes(y=1)) +
    facet_grid(task~ndeval) + 
    scale_fill_manual(values=c("gray50","lightblue"))+
    theme(axis.text.x=element_text(angle=20, hjust=1))+
    ggtitle(glue("SOA+DD"))

  return(plot_grid(plt_resp, plt_correct, nrow=2, rel_heights = c(.6,.4)))
}

get_boxes <- function(files) {
  box_file <- sprintf("%s/boxes.txt",dirname(files[1]))
  boxes <- read.table(text=system(glue("sed 's/[^A-Za-z.0-9]\\+/ /g' {box_file}"),intern=T))
  names(boxes) <- c('LR1','stim_fruit','outcome_fruit','correct_side')
  boxes$file <- box_file
  return(boxes)
}

get_tasklogs <- function(files) {
  tasklogs <- Sys.glob(sprintf("%s/tasklog*.txt",dirname(files[1])))
  return(tasklogs)
}

ID_data <- function(files) {

    cat("## ID\n")
    boxes <- get_boxes(files)
    subjid <- get_ids(files)
  
    # get only the last of each task/run type
    ID_all_files <- files %>%
      grep(pattern="ID", value=T, .)
    ID_files <- ID_all_files %>% split(stringr::str_extract(ID_all_files, '(start|mprage|end)')) %>% lapply(last) %>% unlist


    ID <- ID_files %>%
        lapply(function(f) read.csv(f, stringsAsFactors=F)%>%
		       mutate(resp_raw=as.character(resp_raw),
			      task=gsub('.*ID_(mprage|start|end).*','\\1',f))) %>%
    bind_rows %>%
    filter(ttype=="TrialType.SHOW") %>%
    mutate(inside_fruit=ifelse(is.na(fruit_outside), top, fruit_inside),
	   cor_side = gsub('Direction.(L|R).*','\\1',cor_side),
	   task=factor(task, levels=c("start","mprage","end")),
	   tasknum = as.numeric(task),
           score_raw = ifelse(is.na(score_raw),0, score_raw)) %>%
    select(task,tasknum, trial, onset, LR1, cor_side, score_raw,resp_raw, inside_fruit) %>%
    merge(boxes[,1:3], by="LR1")  %>%
    arrange(tasknum, onset) %>%
    mutate(n=1:n(),
           cmscore=cumsum(score_raw),
           id=subjid)
}
plot_ID <- function(files) {

  subjid <- get_ids(files)
  ID <- ID_data(files)

  # not all that useful
  plt_cumlative_all <- ggplot(ID) +
    aes(x=n,y=cmscore, linetype=task) +
    geom_line() +
    scale_linetype_manual(values=c(2,1,2))+
    theme(legend.position = "none") + 
    ggtitle(glue("{subjid} ID perf"))

  # overall correct
  plt_prct_correct <- ID %>%
      group_by(task) %>%
      summarise(percent_correct=sum(score_raw)/n()) %>% 
      ggplot() + aes(x=task, y=percent_correct, fill=percent_correct) +
      geom_bar(stat="identity") +
      scale_fill_continuous(limits=c(.25, 1.1))+
      scale_y_continuous(limits=c(0,1)) +
      theme(legend.position = "none") + 
      ggtitle(glue("{subjid} ID perf"))
  

  ID_fruitscore <- ID %>%
      group_by(stim_fruit) %>%
      mutate(nseen=1:n(),
	     fruit_cmscore=cumsum(score_raw),
             iscor=score_raw==1)

  plt_cumlative_fruit <-
    ggplot(ID_fruitscore) +
    aes(x=n, y=fruit_cmscore,
	color=stim_fruit, linetype=task,
	group=paste(task,stim_fruit)) +
    geom_line() +
    geom_point(data=ID_fruitscore %>% filter(score_raw!=1),
               aes(shape=iscor))+
    scale_linetype_manual(values=c(2,1,2))+
    scale_x_continuous(limits=c(0,max(ID$n)), breaks=c(0,max(ID$n)))+
    scale_y_continuous(limits=c(0,50)) +
    scale_shape_manual(values=c(4)) + 
    guides(shape=FALSE)

  cor_rat <-  ID %>%
    group_by(task, stim_fruit) %>%
    mutate(total_trials=n()) %>%
    filter(score_raw==1) %>%
    group_by(task,stim_fruit,cor_side,total_trials)  %>%
    summarise(ncorrect=n())

  plt_ratio <- ggplot(cor_rat) +
    aes(x=task, y=ncorrect/total_trials, fill=cor_side, label=paste0(ncorrect, "/",total_trials))  +
    geom_bar(stat="identity") +
    geom_label(aes(y=.9, fill=NULL)) +
    facet_wrap(~stim_fruit) +
    theme(axis.text.x=element_text(angle=45, hjust=1))

  return(plot_grid(
    plot_grid(plt_prct_correct, plt_cumlative_fruit, ncol=2),
    plt_ratio, nrow=2))
}

OD_data <- function(files) {

  cat("## OD\n")
  OD <- files %>%
    grep(pattern="OD", value=T, .) %>%
    last %>%
    read.csv(., stringsAsFactors=F)

  x <- OD %>%
      filter(grepl("SHOW",ttype)) %>%
      select(trial, LR1, LR2, deval, cor_side,
             top, bottom, resp_side_raw, rt_raw, score_raw) %>% 
      mutate(deval=deval=="True",
             devalued_fruit=ifelse(deval,top   , bottom),
             valued_fruit  =ifelse(deval,bottom, top),
             value_pos     =ifelse(deval,'bottom','top'),
             deval_pos     =ifelse(deval,'top'   ,'bottom'),
             cor_side = substr(ifelse(deval,LR2,LR1),0,1))
}
plot_OD <- function(files) {
  OD <- OD_data(files)

  dbled <- OD %>%
      select(cor_side, score=score_raw, devalued_fruit, valued_fruit, value_pos, deval_pos) %>%
      gather(status, fruit, -score, -cor_side, -value_pos, -deval_pos) %>% 
      mutate(correct=factor(score, levels=c(0,1)),
             status =gsub('_fruit','',status),
             pos = ifelse(status=="valued",value_pos, deval_pos))

  x_colors <- OD %>% filter(!deval) %>% select(cor_side, fruit=top) %>% distinct %>% 
            with(cor_side[order(fruit)]) %>% color_lr

  OD_plot <- ggplot(dbled) +
      ggtitle("OD (6 total/fruit - viewed as deval vs valued)") + 
      aes(x=fruit, fill=paste(correct, pos)) +
      geom_bar(stat='count', position='dodge') +
      facet_grid(status~.)+
      scale_fill_manual(values=c("black", "gray33", "green", "lightgreen")) +
      theme(axis.text.x=element_text(angle=20, hjust=1, colour=x_colors))
}

fix_survey <- function(srvy, files, save=FALSE){
    name_order <- names(srvy)
    srvy$rowidx <- 1:nrow(srvy)
    log <- get_tasklogs(files) %>% last
    # boxes <- get_boxes(files) %>% select(fruit=stim_fruit, shown=outcome_fruit)
    perlcmd <- "perl -lne  '
        next unless m/([a-z]+); showing \\[(.*)\\]/;
        $f=$1; $l=$2; $l=~s/\\x27 ?//g;
        print join \" \", $f, split /,/, $l;'"
    x <- read.table(text=system(paste0(perlcmd, " < ", log), intern=T))
    names(x)[1] <- 'correct'
    x$type <- 'pair'
    x$n = 1:nrow(x)
    # we find what index "pick" is in V2-V6.
    # reverse that (5-x) and get the actual pick again from V2-V6
    # if the new pick matches side. it should be correct
    m <- merge(srvy, x, by=c('correct','type')) %>% select(correct, pick, V2:V6)
    w <- m %>% gather(idx, options, -correct,-pick) %>%
        mutate(idx=as.numeric(substr(idx,2,2))-1) %>% # V2..V6 -> 1..5
        group_by(correct, pick) %>%
        mutate(pick_idx=which(pick==options)) %>%
        mutate(f_resp=6-pick_idx)
    redo <- w %>%
        filter(f_resp == idx) %>%
        ungroup() %>%
        select(correct, pick=options, f_resp) %>%
        mutate(type="pair")

    m.sr <- merge(srvy, redo,
            by=c('correct', 'type'), suffixes = c('','.new'),all.x=T)
    corrected <- m.sr %>%
        mutate_if(is.factor, as.character) %>%
        mutate(pick=ifelse(is.na(pick.new),pick,pick.new),
                f_resp=ifelse(is.na(f_resp.new),f_resp,f_resp.new)) %>%
        select(-pick.new, -f_resp.new) %>%
        mutate(iscorrect = ifelse(pick==correct, 'True', 'False'),
               ver="0.0.corrected") %>%
        arrange(rowidx) 

    corrected <- corrected[,c(name_order,'ver')]
    if(save){
        save_as <- grep(pattern="SURVEY", value=T, files) %>%
            last %>% gsub('.csv$','_frtPrCorrected.csv',.)
        write.table(corrected, file=save_as, sep=" ", quote=F, row.names=F)
    }

    return(corrected)
}

survey_data <- function(files){

   cat("## Survey\n")
   srvy <- files %>%
     grep(pattern="SURVEY", value=T, .) %>%
     last() %>%
     read.table(header=T)
   if(! 'ver' %in% names(srvy)) {
       cat("# WARNING: survey old version. FIXING\n")
       srvy <- fix_survey(srvy, files, TRUE)
   }
   parsed_srvy <- srvy %>%
     mutate(iscorrect=iscorrect=="True",
            iscorrect = factor(iscorrect, levels=c(T,F))) %>%
     rename(side=correct, learned=iscorrect, fruit=disp)

   return(parsed_srvy)
}

color_lr <- function(side_col) {
   colors <- ifelse(grepl('L',side_col),'#F8766D','#00BFC4')
}

plot_survey <- function(files) { 
   subjid <- get_ids(files)
   srvy <- survey_data(files)
   TF_colors <- c("#2ca25f","red") # T=green, F=red
   TF_shape <- c(16, 13) # T=filled circle, F=hollow X'ed circle

   boxes <- get_boxes(files)[,1:4]

   sidebar <- srvy %>%
     filter(type=="side") %>%
     ggplot() +
     aes(x=side, fill=learned) +
     geom_bar(stat="count") +
     ggtitle(glue('Survey'))+
     scale_fill_manual(values=TF_colors, drop=F) +
     theme(axis.text.x=element_text(angle=90, hjust=1, vjust=0))

   fruit_side <- srvy %>%
     filter(type=="side") %>%
     merge(boxes[,2:3] %>% gather(ftype,fruit), by='fruit') %>%
     mutate(ftype=gsub('_fruit','',ftype))


   sidepnt <- 
     ggplot(fruit_side) +
     aes(x=side, y=fruit, color=learned, size=c_resp) +
     geom_point() +
     ggtitle('fruit side')+
     scale_color_manual(values=TF_colors, drop=F) +
     facet_grid(ftype~., scales="free_y")
     #theme(axis.text.y=element_text(colour=outin_axis_colors))

   fruit_survey <- srvy %>%
     filter(type=="pair") %>%
     rename(stim_fruit=fruit, picked_pair=pick) %>%
     merge(boxes %>% select(stim_fruit, outcome_fruit, correct_side),
           by='stim_fruit', suffixes = c('','.box')) %>%
     merge(boxes %>% select(outcome_fruit, picked_side=correct_side),
           by.x='picked_pair', by.y='outcome_fruit') %>%
     mutate(picked_correct_side = factor(correct_side == picked_side, levels=c(T,F)))

   x_colors <- color_lr(fruit_survey$correct_side[order(fruit_survey$stim_fruit)])
   y_colors <- color_lr(boxes$correct_side[order(boxes$outcome_fruit)])

   assoc_plt <- ggplot(fruit_survey) +
     aes(x=stim_fruit, y=picked_pair, color=learned) +
     geom_point(aes(y=outcome_fruit, color=NULL),size=1) +
     geom_point(aes(shape=picked_correct_side,size=c_resp)) +
     ggtitle('survey fruit assoc')+
     scale_color_manual(values=TF_colors, drop=F) +
     scale_shape_manual(values=TF_shape, drop=F) +
     theme(axis.text.x=element_text(angle=20, hjust=1, colour=x_colors),
           axis.text.y=element_text(colour=y_colors))

  returned_grid <-
      plot_grid(sidebar,
	     plot_grid(sidepnt   + theme(legend.position="none"),
		       assoc_plt + theme(legend.position="none"),
		       nrow=2),
	     rel_widths=c(1,2))
}

subj_data <- function(subjid) {
  files <- get_files(subjid)
  list(ID=ID_data(files),
       SOADD=SOADD_data(files),
       survey=survey_data(files),
       boxes=get_boxes(files),
       files=files)
}

plot_behave <- function(subjid) {
  files <- get_files(subjid)
  return(list(ID=plot_ID(files),
              SOADD=plot_SOADD(files),
              OD=plot_OD(files),
              survey=plot_survey(files)))
}

plot_pdfs <- function() {
    subjs_IDmprage <- Sys.glob('/Volumes/L/bea_res/Data/Tasks/SlipsOfAction/*/*/ID_mprage*.csv') %>% get_ids
    cat("# have", length(subjs_IDmprage), " subjects\n")
    subj_plots <- lapply(subjs_IDmprage, plot_behave)

    # pdf('imgs/behave.pdf')
    # for(p in subj_plots) {
    #     print(p)
    # }
    # dev.off()

    # pdf('imgs/behave-SOADD.pdf')
    # for(p in subj_plots) {
    #     print(p$SOADD)
    # }
    # dev.off()

    pdf('imgs/behave-perpart.pdf', height=11, width=11)
    for(p in subj_plots) {
                                        #p[['ncol']]=3
        print(do.call(plot_grid, p))
    }
    dev.off()
}

examples <- function(){
    d88 <-subj_data(subjid='11688') # inspect ID. fix NA score
    d93 <-subj_data(subjid='11793') # fix colors
}

# when ./visualize_behave.R,  not when sourced
if (sys.nframe() == 0)
    plot_pdfs()

