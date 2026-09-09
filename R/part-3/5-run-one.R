# Shared helper: one grid cell = one design x one truth, n_rep replicates.
# Used by 6-runsim.R. Same shape as Part 2's simulate_scenario() (R/part-2/4-grid.R)
# job, just a multi-arm design and two analysis models instead of a t-test.
#
# Everything is passed in or created inside the function, so parallel workers
# receive no globals.

run_one <- function(doses, eMax, ed50, h,
                    allocation_scheme = "equal",
                    n_rep             = 100,
                    sample_size       = 240,
                    seed              = NULL,
                    proj              = getwd()) {

  suppressPackageStartupMessages({
    library(rxsim); library(DoseFinding); library(multcomp); library(dplyr)
  })

  # The components, sourced inside so a worker is self-sufficient.
  source(file.path(proj, "R", "part-3", "1-scenarios.R"), local = TRUE)
  source(file.path(proj, "R", "part-3", "2-datagen.R"),   local = TRUE)
  source(file.path(proj, "R", "part-3", "3-design.R"),    local = TRUE)

  arms       <- paste0("d", doses)
  allocation <- allocation_weights(doses, allocation_scheme)
  true_means <- true_means_for(doses, eMax, ed50, h)

  pop <- make_population_generators(doses, true_means)
  ana <- make_analysis_generators(doses, sample_size)

  if (!is.null(seed)) set.seed(seed)

  trials <- replicate_trial("p3", sample_size, arms, allocation,
                            enrollment = enrollment_fn,
                            dropout    = dropout_fn,
                            analysis_generators = ana, population_generators = pop,
                            n = n_rep)
  run_trials(trials)
  collect_results(trials)
}
