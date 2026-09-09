# 2. Add a control arm, then replace the analysis with a t-test.
# What changed: two arms, two generators, and analyze() now compares them.
# Generic normal endpoint (higher = larger response). Effect = trt - pbo.

library(rxsim)

## ---- s2-params ----------------------------------------------------------------
n_total <- 100        # total across both arms, so 50 per arm at 1:1
sigma   <- 1
n_sim   <- 1

## ---- s2-generators ------------------------------------------------------------
mu_pbo <- 0
mu_trt <- 0.5

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

## ---- s2-arms ------------------------------------------------------------------
arms <- c("pbo", "trt")
allocation <- c(1, 1)

## ---- s2-analysis --------------------------------------------------------------
# Split the snapshot by its `arm` column and run a two-sided Welch t-test.
# Name the two vectors explicitly so `effect` is always treatment minus control.
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

## ---- s2-looks -----------------------------------------------------------------
analysis_generators <- list(
  final = list(
    trigger = enroll_trigger(
      fraction = 1,
      sample_size = n_total
    ),
    analysis = analyze
  )
)

## ---- s2-trial -----------------------------------------------------------------
set.seed(20260916)
trials <- replicate_trial(
  trial_name = "two_arm",
  sample_size = n_total,
  arms = arms,
  allocation = allocation,
  enrollment = function(n) rep(x = 1, times = n),
  dropout = NULL,
  analysis_generators = analysis_generators,
  population_generators = list(pbo = gen_pbo, trt = gen_trt),
  n = n_sim
)

## ---- s2-run -------------------------------------------------------------------
invisible(run_trials(trials))
results <- collect_results(trials)
print(transform(results, p_value = round(x = p_value, digits = 3)))
