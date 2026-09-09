# Part 3 — Component 4: TRIAL DESIGN
#
# Everything between "patients exist" and "we have a decision":
#
#   Milestone   a single final analysis at full enrollment
#   Analyses    Dunnett AND MCP-Mod, both run on every replicate
#   Decision    an MED (minimally efficacious dose) rule per method
#
# Both analysis models are computed on the same simulated data. That is
# cheaper than -- and equivalent to -- carrying "analysis model" as a design
# column, and it lets you compare the two methods on identical trials.
#
# Sourced by 6-runsim.R and 7-exercise.R. Requires 1-scenarios.R.

suppressPackageStartupMessages({
  library(rxsim)
  library(DoseFinding)
  library(multcomp)
  library(dplyr)
})

# ---- Candidate model set for MCP-Mod --------------------------------------
# The part 1 candidate set: two hyperbolic Emax, two sigmoid Emax, linear and
# exponential, standardized to top_effect. Candidates are SHAPES, not truths --
# they span the plausible dose-response space so that whatever the world does,
# some candidate is close.

make_candidate_models <- function(doses) {
  DoseFinding::Mods(
    emax        = c(5, 25),                 # hyperbolic
    sigEmax     = rbind(c(5, 2), c(25, 2)), # sigmoid, h = 2
    linear      = NULL,
    exponential = 25,
    doses       = doses,
    placEff     = 0,
    maxEff      = top_effect
  )
}

# ---- MED rule -------------------------------------------------------------
# The MED is chosen from the STUDIED doses, not a continuous dose axis: it is
# the lowest studied dose whose ESTIMATED placebo-adjusted effect clears
# Delta. `eligible` lets a method impose an extra requirement (Dunnett also
# requires the dose to be statistically significant on its own adjusted
# p-value). NA means "no dose selected".

med_from_effects <- function(doses, effects, Delta. = Delta, eligible = TRUE) {
  ok <- !is.na(effects) & effects >= Delta. & eligible
  if (any(ok)) min(doses[ok]) else NA_real_
}

# ---- The analysis ---------------------------------------------------------
# A factory, so the returned closure carries its own copy of the design it
# belongs to rather than looking anything up globally when rxsim calls it.
#
# The returned data.frame IS the output schema -- whatever columns you put
# here are the columns you get back from collect_results().

make_analysis <- function(doses, alpha. = alpha, Delta. = Delta) {
  force(doses)
  arm_names <- paste0("d", doses)
  cand      <- make_candidate_models(doses)

  function(df, current_time) {
    d_e <- df |>
      dplyr::filter(!is.na(enroll_time), !is.na(y)) |>
      dplyr::mutate(
        arm  = factor(arm, levels = arm_names),   # d0 is the Dunnett control
        dose = as.numeric(dose)
      )

    # --- Dunnett: each active dose vs placebo, FWER-controlled ---
    # Contrasts come back in factor-level order, i.e. active doses in
    # increasing order, so they line up with doses[-1].
    fit <- stats::lm(y ~ arm, data = d_e)
    dun <- multcomp::glht(fit, linfct = multcomp::mcp(arm = "Dunnett"),
                          alternative = "greater")
    dunn_p   <- as.numeric(summary(dun)$test$pvalues)
    dunn_eff <- as.numeric(coef(dun))

    med_dunn <- med_from_effects(doses[-1], dunn_eff, Delta.,
                                 eligible = dunn_p < alpha.)

    # --- MCP-Mod: multiple contrast test, then AIC-averaged model fit ---
    mm <- DoseFinding::MCPMod(
      dose        = d_e$dose,
      resp        = d_e$y,
      models      = cand,
      type        = "normal",
      alternative = "one.sided",
      Delta       = Delta.,
      alpha       = alpha.,
      selModel    = "aveAIC"
    )
    mcp_p <- min(attr(mm$MCTtest$tStat, "pVal"), na.rm = TRUE)

    # The AIC-averaged effect curve, read off at our studied doses. `mods` is
    # NULL when the MCP step found no signal -- exactly the case where no dose
    # should be selected.
    mod_eff <- if (is.null(mm$mods)) {
      rep(NA_real_, length(doses))
    } else {
      eff_curve <- vapply(
        mm$mods,
        function(m) predict(m, doseSeq = doses, predType = "effect-curve"),
        numeric(length(doses))
      )
      as.numeric(eff_curve %*% mm$selMod[colnames(eff_curve)])
    }
    med_mcp <- med_from_effects(doses, mod_eff, Delta.)

    out <- data.frame(
      n_total    = nrow(d_e),
      dunn_min_p = min(dunn_p),
      dunn_sig   = as.integer(min(dunn_p) < alpha.),
      dunn_med   = med_dunn,
      mcp_min_p  = mcp_p,
      mcp_sig    = as.integer(mcp_p < alpha.),
      mcp_med    = med_mcp
    )

    # Per-dose ESTIMATES of the placebo-adjusted effect, so a replicate can be
    # compared against what is actually true at each dose:
    #   obs_d<dose>  observed arm mean minus placebo   (what Dunnett acts on)
    #   mod_d<dose>  MCP-Mod's fitted dose-response    (borrows across doses)
    # Designs study different dose sets, so these columns differ by design and
    # come back NA-filled for doses a design did not study.
    for (k in seq_along(doses[-1]))
      out[[paste0("obs_d", doses[-1][k])]] <- dunn_eff[k]
    for (k in seq_along(doses))
      out[[paste0("mod_d", doses[k])]] <- mod_eff[k]

    out
  }
}

# ---- Milestone: one look, at full enrollment ------------------------------

make_analysis_generators <- function(doses, sample_size) {
  list(
    final = list(
      trigger  = enroll_trigger(1.0, sample_size),
      analysis = make_analysis(doses)
    )
  )
}
