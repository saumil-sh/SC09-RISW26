# Part 3 — Component 3: DATA GENERATION MODEL
#
# One rxsim population generator per arm. Each generator is a closure that
# takes n and returns a data.frame of n patients:
#
#   id            patient identifier within the arm
#   dose          numeric dose -- MCP-Mod needs actual dose values, not labels
#   y             % change from baseline in body weight at Week 24
#   readout_time  time from enrollment to the endpoint being observed
#
# Deliberately the simplest model that could work:
#
#   Y_ij ~ N(f(d_j), sigma^2),   sigma = 10
#
# No dropout beyond the trial-level dropout function, no longitudinal
# structure, no covariates. Every elaboration you would want is an addition
# to this one function, not a different tool.
#
# Sourced by 6-runsim.R and 7-exercise.R. Requires 1-scenarios.R.

suppressPackageStartupMessages(library(rxsim))

# ---- Closure factory ------------------------------------------------------
# force() matters: without it, all generators would share whatever d/mu/sd
# happened to be current when the closure was finally called from inside the
# trial machinery, rather than each carrying its own copy.

mk_pop_gen <- function(d, mu, sd) {
  force(d); force(mu); force(sd)
  function(n) {
    data.frame(
      id           = seq_len(n),
      dose         = d,
      y            = rnorm(n, mean = mu, sd = sd),
      readout_time = 1
    )
  }
}

# ---- One named generator per arm ------------------------------------------
# Returns a list named d0, d5, ... matching the arm names, which is the shape
# replicate_trial() expects.

make_population_generators <- function(doses, true_means, sd = sigma) {
  gens <- Map(mk_pop_gen, doses, true_means, MoreArgs = list(sd = sd))
  names(gens) <- paste0("d", doses)
  gens
}
