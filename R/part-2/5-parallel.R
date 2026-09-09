# 5. Change only the execution method.
# simulate_scenario() and grid are identical to step 4; only the grid runner changes.

library(rxsim)

## ---- s5-function --------------------------------------------------------------
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

## ---- s5-grid ------------------------------------------------------------------
grid <- expand.grid(
  n_total = c(50, 100),
  delta = c(0, 0.5)
)

## ---- s5-workers ---------------------------------------------------------------
# A worker is another R session on your machine. Two workers is a safe default
# for a workshop laptop. multisession works on Windows, macOS, and Linux.
future::plan(strategy = future::multisession, workers = 2)

## ---- s5-parallel --------------------------------------------------------------
# Same inputs, same output; only the execution method changes.
out <- future.apply::future_lapply(
  X = seq_len(nrow(grid)),
  FUN = function(i) {
    simulate_scenario(
      n_total = grid$n_total[i],
      delta = grid$delta[i]
    )
  },
  future.seed = 20260916
)
results <- do.call(what = rbind, args = out)

## ---- s5-close -----------------------------------------------------------------
# Release the workers when finished. This is cleanup, not an undo.
future::plan(strategy = future::sequential)

## ---- s5-summarize -------------------------------------------------------------
final <- subset(x = results, subset = analysis == "final")
final$reject <- final$p_value < 0.05
aggregate(reject ~ n_total + delta, data = final, FUN = mean)
