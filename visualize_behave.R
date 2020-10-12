 library(dplyr)
 library(glue)
 library(ggplot2)
 library(tidyr)
 library(cowplot)
 theme_set(theme_cowplot()) 


get_ids <- function(f_name){
   stringr::str_match(f_name, '(?<=/)\\d{5}') %>% unique
}
get_files <- function(subjid) {
  files <- Sys.glob(glue('/Volumes/L/bea_res/Data/Tasks/SlipsOfAction/{subjid}*/*/*.csv'))
}


SOADD_data <- function(files) {
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
    iscorrect = factor(iscorrect, levels=c(T,F)),
    trial_type=ifelse(deval,'devalued','valued')) %>%
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
    mutate(trial_type=ifelse(deval,'devalued','valued')) %>%
    mutate(rat = n/total_trials) 

  plt_resp <-
    ggplot(soadd_smry)+
    aes(x=trial_type, y=rat, fill=responded, label=paste(n,"/",total_trials))+
    geom_bar(stat="identity")+
    geom_label(data=soadd_smry%>%filter(!responded), aes(y=1)) +
    facet_grid(task~ndeval) + 
    scale_fill_manual(values=c("gray50","lightblue"))+
    theme(axis.text.x=element_text(angle=20, hjust=1))+
    ggtitle(glue("{subjid} SOA+DD"))

  return(plot_grid(plt_resp, plt_correct, nrow=2, rel_heights = c(.6,.4)))
}

ID_data <- function(files) {
  box_file <- sprintf("%s/boxes.txt",dirname(files[1]))
  boxes <- read.table(text=system(glue("sed 's/[^A-Za-z.0-9]\\+/ /g' {box_file}"),intern=T))
  names(boxes) <- c('LR1','stim_fruit','resp_fruit','corret_side')

  ID <- files %>%
    grep(pattern="ID", value=T, .) %>%
    grep(invert=T,pattern="10.39.46", value=T, .) %>%
    lapply(function(f) read.csv(f, stringsAsFactors=F)%>%
		       mutate(resp_raw=as.character(resp_raw),
			      task=gsub('.*ID_(mprage|start|end).*','\\1',f))) %>%
    bind_rows %>%
    filter(ttype=="TrialType.SHOW") %>%
    mutate(inside_fruit=ifelse(is.na(fruit_outside), top, fruit_inside),
	   cor_side = gsub('Direction.(L|R).*','\\1',cor_side),
	   task=factor(task, levels=c("start","mprage","end")),
	   tasknum = as.numeric(task)) %>%
    select(task,tasknum, trial, onset, LR1, cor_side, score_raw,resp_raw, inside_fruit) %>%
    merge(boxes[,1:3], by="LR1")  %>%
    arrange(tasknum, onset) %>% mutate(n=1:n(), cmscore=cumsum(score_raw))
}
plot_ID <- function(files) {

  subjid <- get_ids(files)
  ID <- ID_data(files)

  plt_cumlative_all <- ggplot(ID) +
    aes(x=n,y=cmscore, linetype=task) +
    geom_line() +
    scale_linetype_manual(values=c(2,1,2))+
    theme(legend.position = "none") + 
    ggtitle(glue("{subjid} ID perf"))

  plt_cumlative_fruit <-
    ID %>% group_by(stim_fruit) %>%
    mutate(nseen=1:n(),
	   fruit_cmscore=cumsum(score_raw)) %>%
    ggplot() +
    aes(x=n, y=fruit_cmscore,
	color=stim_fruit, linetype=task,
	group=paste(task,stim_fruit)) +
    geom_line() +
    scale_linetype_manual(values=c(2,1,2))

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
    plot_grid(plt_cumlative_all, plt_cumlative_fruit, ncol=2),
    plt_ratio, nrow=2))
}

survey_data <- function(files){
   srvy <- files %>%
     grep(pattern="SURVEY", value=T, .) %>%
     read.table(header=T) %>%
     mutate(iscorrect=iscorrect=="True",
            iscorrect = factor(iscorrect, levels=c(T,F))) %>%
     $rename(side=correct, learned=iscorrect, fruit=disp)
}

plot_survey <- function(files) { 
   subjid <- get_ids(files)
   srvy <- survey_data(files)
   TF_colors <- c("red","green")

   sidebar <- srvy %>%
     filter(type=="side") %>%
     ggplot() +
     aes(x=side, fill=learned) +
     geom_bar(stat="count", position = "dodge") +
     ggtitle(glue('{subjid} survey'))+
     scale_fill_manual(values=TF_colors, drop=F)

   sidepnt <-
     srvy %>%
     filter(type=="side") %>%
     ggplot() +
     aes(x=side, y=fruit, color=learned) +
     geom_point(size=2) +
     ggtitle('fruit side')+
     scale_color_manual(values=TF_colors, drop=F)


   assoc_plt <- srvy %>%
     filter(type=="pair") %>%
     ggplot() + aes(x=fruit, y=pick, color=learned) +
     geom_point(size=3) +
     ggtitle('survey fruit assoc')+
     scale_color_manual(values=TF_colors, drop=F)


  return(plot_grid(sidebar,
	     plot_grid(sidepnt   + theme(legend.position="none"),
		       assoc_plt + theme(legend.position="none"),
		       nrow=2),
	     rel_widths=c(1,2)))
}

plot_behave <- function(subjid) {
  files <- get_files(subjid)
  return(list(ID=plot_ID(files),
              SOADD=plot_SOADD(files),
              survey=plot_survey(files)))
}

plot_pdfs <- function() {
    subjs_IDmprage <- Sys.glob('/Volumes/L/bea_res/Data/Tasks/SlipsOfAction/*/*/ID_mprage*.csv') %>% get_ids
    subjid<-'11793'
    subj_plots <- lapply(subjs_IDmprage, plot_behave)

    pdf('imgs/behave.pdf')
    for(p in subj_plots) {
        print(p)
    }
    dev.off()

    pdf('imgs/behave-SOADD.pdf')
    for(p in subj_plots) {
        print(p$SOADD)
    }
    dev.off()

    pdf('imgs/behave-perpart.pdf', height=11, width=11)
    for(p in subj_plots) {
                                        #p[['ncol']]=3
        print(do.call(plot_grid, p))
    }
    dev.off()
}

plot_pdfs()
