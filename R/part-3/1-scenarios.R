# Part 3 — Component 2: SCENARIOS
#
# Design scenarios = what we CHOOSE   (arm sets, sample size, allocation)
# Truth scenarios  = what we ASSUME   (dose-response shape and effect size)
#
# Both are plain data frames, one row per scenario, so the full simulation
# grid is just their cross-product via tidyr::expand_grid(). Adding a new
# scenario means adding a row -- never editing the simulation code.
#
# Sourced by 6-runsim.R and 7-exercise.R.

suppressPackageStartupMessages({
  library(DoseFinding)
  library(dplyr)
  library(tidyr)
  library(tibble)
})

# ---- Study-level constants (fixed across every scenario) ------------------

sigma      <- 10     # residual SD of % change from baseline
alpha      <- 0.10   # one-sided FWER for both Dunnett and the MCP step
Delta      <- 15     # clinically viable placebo-adjusted % weight loss
top_dose   <- 100    # highest studied dose (the MTD)
top_effect <- 18     # positive truths deliver this effect AT the top dose
neg_effect <- 13     # negative truth delivers this effect AT the top dose

enrollment_fn <- function(n) rexp(n, rate = 1)
dropout_fn    <- function(n) rexp(n, rate = 0.01)

# ---- Truth scenarios ------------------------------------------------------
# Dose response is a (sigmoid) Emax curve on the % weight-loss scale:
#
#     f(d) = eMax * d^h / (ed50^h + d^h)
#
# eMax is the ASYMPTOTE, not the effect at any dose we actually study. Fixing
# eMax at a common value for every scenario would leave each curve delivering a
# different amount at the top dose -- which confounds "shape" with "how much the
# top dose is worth". Instead we fix the thing we care about (the effect at
# 100 mg) and back-solve eMax:
#
#     f(d*) = top_effect  =>  eMax = top_effect * (1 + (ed50 / d*)^h)

emax_for <- function(effect, ed50, h, d = top_dose) effect * (1 + (ed50 / d)^h)

# Three positive truths, numbered by the answer they imply: their true MEDs are
# 25, 50 and 100 mg. One truth per plausible recommendation, no redundancy.
truth_scenarios <- tibble::tribble(
  ~truth,     ~kind,      ~ed50, ~h,
  "Negative", "Negative",   7.5,  1,   # never viable
  "Emax1",    "Positive",     4,  1,   # hyperbolic, true MED  25 mg
  "Emax2",    "Positive",    20,  3,   # sigmoid,    true MED  50 mg
  "Emax3",    "Positive",    50,  3    # sigmoid,    true MED 100 mg
) |>
  dplyr::mutate(
    # Every truth -- negative included -- is specified by its effect at the top
    # dose, then eMax is back-solved. The negative truth delivers a real 13% at
    # 100 mg, so there IS a dose response; it is just never clinically viable
    # (13% < Delta = 15%). That distinction drives the false-positive rule.
    eMax = emax_for(dplyr::if_else(kind == "Positive", top_effect, neg_effect),
                    ed50, h)
  )

# ---- Design scenarios -----------------------------------------------------
# `doses` is a list-column because a design is defined by a whole dose set,
# not a single dose. Every other design parameter is its own atomic column.

arm_sets <- tibble::tibble(
  n_active = c(3L, 4L, 5L),
  doses    = list(
    c(0, 25, 50, 100),
    c(0, 10, 25, 50, 100),
    c(0, 5, 10, 25, 50, 100)
  )
)

design_scenarios <- tidyr::expand_grid(
  arm_sets,
  sample_size = 240,                     # fixed for teaching; add values here
  allocation  = c("equal", "weighted")
) |>
  dplyr::mutate(design = paste0(n_active, "act_", allocation), .before = 1)

# Equal (1:...:1), or placebo and top dose weighted twice as heavily
# (2:1:...:1:2).
allocation_weights <- function(doses, scheme) {
  k <- length(doses)
  switch(scheme,
    equal    = rep(1, k),
    weighted = c(2, rep(1, k - 2), 2),
    stop("unknown allocation scheme: ", scheme)
  )
}

# ---- The simulation grid --------------------------------------------------
# 6 designs x 4 truths = 24 cells. Both analysis models are computed on every
# replicate, so the analysis-model dimension of part 1's grid is free.

scenarios <- tidyr::expand_grid(design_scenarios, truth_scenarios)

# ---- Truth helpers --------------------------------------------------------

# True mean response at each dose under a truth scenario.
true_means_for <- function(doses, eMax, ed50, h) {
  setNames(DoseFinding::sigEmax(doses, e0 = 0, eMax = eMax, ed50 = ed50, h = h),
           as.character(doses))
}

# True MED: the lowest STUDIED dose whose true effect clears Delta.
# NA when no studied dose is clinically viable (the negative truth).
true_med_for <- function(doses, eMax, ed50, h, Delta. = Delta) {
  tm <- true_means_for(doses, eMax, ed50, h)
  ok <- tm >= Delta.
  if (any(ok)) min(doses[ok]) else NA_real_
}

# Convenience: attach true means / true MED to a single grid row.
describe_cell <- function(row) {
  doses <- row$doses[[1]]
  list(
    doses      = doses,
    arm_names  = paste0("d", doses),
    allocation = allocation_weights(doses, row$allocation),
    true_means = true_means_for(doses, row$eMax, row$ed50, row$h),
    true_med   = true_med_for(doses, row$eMax, row$ed50, row$h)
  )
}
