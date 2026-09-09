# 1. One arm, one look: generate patients, then describe them.
# Generic normal endpoint (continuous, higher = larger response).

library(rxsim)

## ---- params -------------------------------------------------------------------
n_total <- 100        # patients across all arms (one arm here)
mu      <- 0.5        # assumed true mean response
sigma   <- 1          # between-patient SD
n_sim   <- 1          # whole-trial reruns; we keep this at 1 for now

## ---- generator ----------------------------------------------------------------
# One row per patient. rxsim calls this once per replicate, so each replicate
# gets fresh patients. Required columns: id, readout_time, plus your endpoint.
gen_trt <- function(n) {
  data.frame(
    id           = seq_len(n),
    y            = rnorm(n = n, mean = mu, sd = sigma),
    readout_time = 0
  )
}

## ---- preview ------------------------------------------------------------------
# Look at five generated patients before building any trial. This preview owns
# its own seed and is separate from the trial below.
set.seed(20260916)
gen_trt(5)

## ---- analysis -----------------------------------------------------------------
# rxsim calls analyze(df, current_time) at each look. df is the snapshot of the
# trial at that moment. Return one row; it becomes a row of your results.
analyze <- function(df, current_time) {
  data.frame(
    n      = nrow(df),
    mean_y = mean(df$y),
    sd_y   = sd(df$y)
  )
}

## ---- looks --------------------------------------------------------------------
# One look, when 100% of patients have enrolled. Verified in this repo on
# 2026-09-08: enroll_trigger() hands analyze() only enrolled patients.
analysis_generators <- list(
  final = list(
    trigger = enroll_trigger(
      fraction = 1,
      sample_size = n_total
    ),
    analysis = analyze
  )
)

## ---- trial --------------------------------------------------------------------
# Build the replicate trial(s). No dropout, one patient per time unit.
set.seed(20260916)
trials <- replicate_trial(
  trial_name = "one_arm",
  sample_size = n_total,
  arms = "trt",
  allocation = 1,
  enrollment = function(n) rep(x = 1, times = n),
  dropout = NULL,
  analysis_generators = analysis_generators,
  population_generators = list(trt = gen_trt),
  n = n_sim
)

## ---- run ----------------------------------------------------------------------
# run_trials() stores results inside each trial object, so we do not assign its
# output. collect_results() gathers them into one table.
invisible(run_trials(trials))
results <- collect_results(trials)
print(results)
