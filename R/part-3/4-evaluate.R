# Part 3 — Components 1 & 5: OBJECTIVES and EVALUATION CRITERIA
#
# The objectives are the thresholds; the evaluation criteria are the metrics
# that measure them. They live together because a metric that does not map to
# an objective usually should not be computed.
#
# This is the SINGLE definition of what "success" means. The pre-run script
# (6-runsim.R) and the exercise (7-exercise.R) both source this file, so
# the stored results and anything you compute yourself use the same rule.
#
# Part 1 objectives for this study:
#   A.  >= 70% success under EACH positive truth
#   B.  <= 15% chance of selecting a dose as clinically viable under the
#       negative truth
#
# Success = statistical significance AND acceptable dose selection.
#
# Requires 1-scenarios.R (for `truth_scenarios` and `Delta`).

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
})

# ---- Objectives (thresholds) ----------------------------------------------

success_target <- 0.70   # objective A, under every positive truth
claim_target   <- 0.15   # objective B, under the negative truth

# ---- What is TRUE at a dose, under a given truth --------------------------
# Vectorised over both arguments, so it works on a whole results table.

true_effect <- function(truth_name, dose) {
  t <- truth_scenarios[match(truth_name, truth_scenarios$truth), ]
  DoseFinding::sigEmax(dose, e0 = 0, eMax = t$eMax, ed50 = t$ed50, h = t$h)
}

# ---- Evaluation criteria (metrics) ----------------------------------------

# "Acceptable dose selection" = we selected a dose AND that dose really is
# worth taking forward.
#
# Part 1 states this as two clauses: the MED is either (1) correct for the
# scenario, or (2) incorrect but still has at least a 15% treatment effect in
# truth. Clause 1 is subsumed by clause 2 -- the true MED is BY DEFINITION the
# lowest dose whose true effect clears Delta -- so the whole rule collapses to
# a single check against the TRUE dose-response curve.
#
# Why the second clause at all? Landing on a dose that is not the true MED but
# still delivers clinically meaningful efficacy is a good outcome, and a metric
# that scored it as a failure would make the design look worse than it is for
# reasons that are an artifact of the dose grid.
acceptable <- function(truth_name, med, Delta. = Delta) {
  truth_name <- rep_len(truth_name, length(med))
  ok <- !is.na(med)                      # selecting nothing is never acceptable
  ok[ok] <- true_effect(truth_name[ok], med[ok]) >= Delta.
  ok
}

# Did the trial claim a clinically viable dose exists? Significance alone is
# NOT the false-positive event: the negative truth has a real dose response
# (it reaches 13% at 100 mg), so both tests detect a signal almost always.
# The error that matters is claiming a VIABLE dose when none exists.
claimed_viable <- function(sig, med) sig == 1 & !is.na(med)

# Success = significance AND acceptable dose selection.
is_success <- function(truth_name, sig, med, Delta. = Delta) {
  sig == 1 & acceptable(truth_name, med, Delta.)
}

# Monte Carlo standard error of a proportion -- how much of a difference
# between two numbers is just noise.
mc_se <- function(p, n_rep) sqrt(p * (1 - p) / n_rep)

# ---- Replicate-level results -> one row of operating characteristics ------
# `truth_name` identifies which truth this cell was run under; `true_med` is
# that truth's true MED given the design's dose set.

summarise_replicates <- function(res, truth_name, true_med) {
  correct <- function(med) {
    if (is.na(true_med)) mean(is.na(med)) else mean(!is.na(med) & med == true_med)
  }
  data.frame(
    n_rep        = nrow(res),
    # Objective A
    dunn_success = mean(is_success(truth_name, res$dunn_sig, res$dunn_med)),
    mcp_success  = mean(is_success(truth_name, res$mcp_sig,  res$mcp_med)),
    # Objective B (only meaningful under the negative truth)
    dunn_claim   = mean(claimed_viable(res$dunn_sig, res$dunn_med)),
    mcp_claim    = mean(claimed_viable(res$mcp_sig,  res$mcp_med)),
    # Diagnostics -- not objectives, but they explain WHY a design behaves
    # the way it does
    dunn_sig     = mean(res$dunn_sig),
    mcp_sig      = mean(res$mcp_sig),
    dunn_correct = correct(res$dunn_med),
    mcp_correct  = correct(res$mcp_med),
    dunn_none    = mean(is.na(res$dunn_med)),
    mcp_none     = mean(is.na(res$mcp_med))
  )
}

# ---- Do the objectives hold? ----------------------------------------------
# One row per design x method: the binding (worst) success across the positive
# truths, the claim rate under the negative truth, and whether both hold.

check_objectives <- function(oc, success_target. = success_target,
                             claim_target. = claim_target) {
  long <- oc |>
    tidyr::pivot_longer(
      cols = c(dunn_success, mcp_success, dunn_claim, mcp_claim),
      names_to = c("method", "metric"), names_sep = "_"
    ) |>
    dplyr::mutate(method = dplyr::recode(method, dunn = "Dunnett", mcp = "MCP-Mod"))

  worst_pos <- long |>
    dplyr::filter(kind == "Positive", metric == "success") |>
    dplyr::group_by(design, method) |>
    dplyr::summarise(min_success = min(value),
                     binding_truth = truth[which.min(value)], .groups = "drop")

  neg_claim <- long |>
    dplyr::filter(kind == "Negative", metric == "claim") |>
    dplyr::select(design, method, claim_rate = value)

  worst_pos |>
    dplyr::left_join(neg_claim, by = c("design", "method")) |>
    dplyr::mutate(
      meets_A = min_success >= success_target.,
      meets_B = claim_rate  <= claim_target.,
      meets   = meets_A & meets_B
    ) |>
    dplyr::arrange(dplyr::desc(meets), dplyr::desc(min_success))
}
