# Measure the Step 5 sequential-versus-parallel timing at n_sim = 200.
# Run this file with source("R/part-2/6-timing-comparison.R") or Rscript.

library(rxsim)

simulate_scenario <- function(n_total, delta, n_sim = 200) {
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
  collect_results(trials)
}

measure_timing <- function(n_sim = 200, workers = 2) {
  grid <- expand.grid(
    n_total = c(50, 100),
    delta = c(0, 0.5)
  )

  set.seed(20260916)
  sequential_elapsed <- system.time(
    lapply(
      X = seq_len(nrow(grid)),
      FUN = function(i) {
        simulate_scenario(
          n_total = grid$n_total[i],
          delta = grid$delta[i],
          n_sim = n_sim
        )
      }
    )
  )[["elapsed"]]

  future::plan(strategy = future::multisession, workers = workers)
  on.exit(future::plan(strategy = future::sequential), add = TRUE)

  parallel_elapsed <- system.time(
    future.apply::future_lapply(
      X = seq_len(nrow(grid)),
      FUN = function(i) {
        simulate_scenario(
          n_total = grid$n_total[i],
          delta = grid$delta[i],
          n_sim = n_sim
        )
      },
      future.seed = 20260916
    )
  )[["elapsed"]]

  data.frame(
    method = c("sequential", "parallel"),
    n_sim = n_sim,
    scenarios = nrow(grid),
    workers = c(1, workers),
    elapsed_seconds = c(sequential_elapsed, parallel_elapsed)
  )
}

timings <- measure_timing(
  n_sim = 200,
  workers = 2
)

print(timings)
