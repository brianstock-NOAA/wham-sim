# Brian Stock
# June 15 2020
# Simulation test WHAM

# source(here::here("code","bias_correct_oe","GBhaddock_NAA_oe","1_fit_GBhaddock_NAA.R"))

# devtools::load_all("/home/bstock/Documents/wham")
# devtools::install_github("timjmiller/wham", dependencies=TRUE)
library(wham)
library(here)
library(tidyverse)

res_dir <- here("results","bias_correct_oe","GBhaddock_NAA_oe")
dir.create(res_dir, showWarnings=FALSE)
ins_dir <- here("data","simdata","bias_correct_oe","GBhaddock_NAA_oe")

# Georges Bank haddock
# see /home/bstock/Documents/wg_MGWG/state-space/GBhaddock/WHAM/fit_wham_models.r
# Fbar.ages = 5:7
# 9 ages
# 4 selectivity blocks, all logistic (default, specified in ASAP file)
# age comps: 7 (logistic normal, treat 0 obs as missing)
asap3 <- read_asap3_dat(here("data","GBhaddock_ASAP.dat"))

# Fit 4 NAA operating models:
#  1. rec 	iid
#  2. rec 	ar1_y
#  3. rec+1 iid
#  4. rec+1 2dar1
df.mods <- data.frame(NAA_cor = c('iid','ar1_y','iid','2dar1'),
                      NAA_sigma = c('rec','rec','rec+1','rec+1'), stringsAsFactors=FALSE)
n.mods <- dim(df.mods)[1]
df.mods$Model <- paste0("m",1:n.mods)
df.mods <- df.mods %>% select(Model, everything()) # moves Model to first col
df.mods

# Fit models
for(m in 1:n.mods){
  input <- prepare_wham_input(asap3, recruit_model = 2,
                              model_name = df.mods$Model[m],                         
                              NAA_re = list(cor=df.mods[m,"NAA_cor"], sigma=df.mods[m,"NAA_sigma"]))
  # input <- prepare_wham_input(asap3, recruit_model = 2,
  #                             model_name = df.mods$Model[m],                         
  #                             NAA_re = list(cor=df.mods[m,"NAA_cor"], sigma=df.mods[m,"NAA_sigma"]),
  #                             selectivity=list(model=c("logistic","age-specific","age-specific","logistic"),
  #                                initial_pars=list(c(3,3), c(.5,.5,.5,1,.5,.5,1,1,0), c(.5,1,.5,.5,1,1,1,1,1), c(3,3)),
  #                                fix_pars=list(NULL, c(4,8,9), c(2,5), NULL)))

  # age comp = 7, logistic normal, treat 0 obs as missing, 1 par
  input$data$age_comp_model_indices = rep(7, input$data$n_indices)
  input$data$age_comp_model_fleets = rep(7, input$data$n_fleets)
  input$data$n_age_comp_pars_indices = rep(1, input$data$n_indices)
  input$data$n_age_comp_pars_fleets = rep(1, input$data$n_fleets)
  input$par$index_paa_pars = rep(0, input$data$n_indices)
  input$par$catch_paa_pars = rep(0, input$data$n_fleets)
  input$map = input$map[!(names(input$map) %in% c("index_paa_pars", "catch_paa_pars"))]

  # analytical bias correction, both obs and process error
  input$data$bias_correct_oe = 1
  input$data$bias_correct_pe = 0

  input$data$Fbar_ages = 5:7

  # Fit model
  # mod <- fit_wham(input, do.retro=F, do.osa=F, do.proj=F) # no TMB bias correction
  mod <- fit_wham(input, do.sdrep=F, do.retro=F, do.osa=F, do.proj=F)  
  if(exists("err")) rm("err") # need to clean this up
  mod$sdrep = TMB::sdreport(mod, bias.correct=TRUE) # also do bias correction
  # simdata <- mod$simulate(par=mod$env$last.par.best, complete=TRUE)

  # Save model
  if(exists("err")) rm("err") # need to clean this up
  saveRDS(mod, file=file.path(res_dir, paste0(df.mods$Model[m],".rds")))
  saveRDS(input, file=file.path(ins_dir, paste0(df.mods$Model[m],"_input.rds")))
}

# check that all models converged, pdHess, and bias correction succeeded
mod.list <- file.path(res_dir,paste0("m",1:n.mods,".rds"))
mods <- lapply(mod.list, readRDS)
conv = sapply(mods, function(x) if(x$sdrep$pdHess) TRUE else FALSE)
conv

# a50 par is -15 for 2nd block... try age-specific?
