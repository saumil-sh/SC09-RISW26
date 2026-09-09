# 3. Add an informational interim look halfway through.
# Everything else is the same: patients, generators, t-test, and sample size.
# Every trial still runs to completion; the final look is the only decision.

library(rxsim)

## ---- s3-params ----------------------------------------------------------------
n_total <- 100
mu_pbo  <- 0
mu_trt  <- 0.5
sigma   <- 1
n_sim   <- 1

## ---- s3-generators ------------------------------------------------------------
gen_pbo <- function(n) {
  data.frame(
    id = seq_len(n),
    y = rnorm(n = n, mean = mu_pbo, sd = sigma),
    readout_time = 0
  )
}

gen_trt <- function(n) {
  data.frame(
    id = seq_len(n),
    y = rnorm(n = n, mean = mu_trt, sd = sigma),
    readout_time = 0
  )
}

## ---- s3-analysis --------------------------------------------------------------
analyze <- function(df, current_time) {
  y_trt <- df$y[df$arm == "trt"]
  y_pbo <- df$y[df$arm == "pbo"]
  tt <- t.test(x = y_trt, y = y_pbo)

  data.frame(
    n_trt = length(y_trt),
    n_pbo = length(y_pbo),
    effect = mean(y_trt) - mean(y_pbo),
    p_value = tt$p.value
  )
}

## ---- s3-looks -----------------------------------------------------------------
# Two looks instead of one. The same analyze() serves both. interim fires at
# 50% enrolled, final at 100%. The final look includes the interim patients with
# their original outcomes; rxsim snapshots one accumulating trial.
analysis_generators <- list(
  interim = list(
    trigger = enroll_trigger(
      fraction = 0.5,
      sample_size = n_total
    ),
    analysis = analyze
  ),
  final = list(
    trigger = enroll_trigger(
      fraction = 1,
      sample_size = n_total
    ),
    analysis = analyze
  )
)

## ---- s3-trial -----------------------------------------------------------------
set.seed(20260916)
trials <- replicate_trial(
  trial_name = "two_look",
  sample_size = n_total,
  arms = c("pbo", "trt"),
  allocation = c(1, 1),
  enrollment = function(n) rep(x = 1, times = n),
  dropout = NULL,
  analysis_generators = analysis_generators,
  population_generators = list(pbo = gen_pbo, trt = gen_trt),
  n = n_sim
)

## ---- s3-run -------------------------------------------------------------------
invisible(run_trials(trials))
results <- collect_results(trials)
print(transform(
  results[, c("replicate", "analysis", "n_trt", "n_pbo", "effect", "p_value")],
  p_value = round(x = p_value, digits = 3)
), row.names = FALSE)

## ---- s3-replicate-setup ---------------------------------------------------------
# Same trial as above; only n_sim changes, so the setup is not re-shown on the slide.
n_sim <- 5
set.seed(20260916)
trials <- replicate_trial(
  trial_name = "two_look",
  sample_size = n_total,
  arms = c("pbo", "trt"),
  allocation = c(1, 1),
  enrollment = function(n) rep(x = 1, times = n),
  dropout = NULL,
  analysis_generators = analysis_generators,
  population_generators = list(pbo = gen_pbo, trt = gen_trt),
  n = n_sim
)
invisible(run_trials(trials))
results <- collect_results(trials)

## ---- s3-replicate -------------------------------------------------------------
# The one edit: n_sim <- 5. Expect 5 x 2 = 10 rows.
print(transform(
  results[, c("replicate", "analysis", "n_trt", "n_pbo", "effect", "p_value")],
  p_value = round(x = p_value, digits = 3)
), row.names = FALSE)
