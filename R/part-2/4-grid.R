# 4. Wrap the two-look simulation in a function, then iterate a scenario grid.
# Parameters, generators, analyses, trial build, run, and collect move inside.
# The seed, the calls, and printing stay outside.

library(rxsim)

## ---- s4-function --------------------------------------------------------------
# One scenario = one call. delta = treatment mean minus control mean.
# The function tags every result row with the scenario that produced it.
simulate_scenario <- function(n_total, delta, n_sim = 5) {
  gen_pbo <- function(n) {
    data.frame(
      id = seq_len(n),
      y = rnorm(n = n, mean = 0, sd = 1),
      readout_time = 0
    )
  }

  gen_trt <- function(n) {
    data.frame(
      id = seq_len(n),
      y = rnorm(n = n, mean = delta, sd = 1),
      readout_time = 0
    )
  }

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
  res <- collect_results(trials)
  cbind(n_total = n_total, delta = delta, res)
}

## ---- s4-one-call --------------------------------------------------------------
set.seed(20260916)
one_scenario <- simulate_scenario(
  n_total = 100,
  delta = 0.5,
  n_sim = 3
)
print(transform(
  one_scenario[, c("n_total", "delta", "replicate", "analysis", "effect", "p_value")],
  p_value = round(x = p_value, digits = 3)
), row.names = FALSE)

## ---- s4-grid ------------------------------------------------------------------
grid <- expand.grid(n_total = c(50, 100), delta = c(0, 0.5))
print(grid, row.names = FALSE)

set.seed(20260916)
results <- do.call(
  what = rbind,
  args = lapply(
    X = seq_len(nrow(grid)),
    FUN = function(i) simulate_scenario(
      n_total = grid$n_total[i],
      delta = grid$delta[i]
    )
  )
)

## ---- s4-summarize -------------------------------------------------------------
# Final look only. reject = p < 0.05 (two-sided) at the final look.
# delta = 0 rows estimate Type I error; delta = 0.5 rows estimate power.
final <- subset(x = results, subset = analysis == "final")
final$reject <- final$p_value < 0.05
aggregate(reject ~ n_total + delta, data = final, FUN = mean)

## ---- s4-mc-error --------------------------------------------------------------
# These are only 5 replicates. They show the mechanics, not precise power.
# When 0 of 5 reject, the 95% interval for the rejection rate is wide, not zero.
binom.test(x = 0, n = 5)$conf.int
