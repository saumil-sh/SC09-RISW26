# =========================================================================
# PART 3 EXERCISE — read a completed simulation study
# =========================================================================
#
# The simulation has already been run: 6 designs x 4 truths x 1,000 replicates
# = 24,000 virtual trials. The code that produced it is in R/part-3/1-*.R through
# R/part-3/4-*.R -- read it whenever you like, but you do not need it today.
#
# Your job is the part that actually decides a trial: turning 30,000 simulated
# trials into a recommendation you would defend in a design meeting.
#
# Everything below the SETUP section is yours. There are no blanks to fill --
# the questions are open. Stuck, or want to compare? R/part-3/8-exercise-solution.R
# produces exactly the summaries and figures shown in the slides.
#
# -------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
})

source("R/part-3/1-scenarios.R")   # scenario definitions and study constants
source("R/part-3/4-evaluate.R")    # the objectives, and what "success" means


# =========================================================================
# SETUP — the data, and the helpers you are given
# =========================================================================

results <- readRDS(Sys.getenv("P3_RESULTS", "data/p3-results.rds"))
reps <- results$replicates    # 30,000 rows: ONE ROW PER SIMULATED TRIAL

# `reps` columns -----------------------------------------------------------
#   design       "3act_equal", "5act_weighted", ...   (6 of them)
#   n_active     3, 4 or 5 active dose arms
#   allocation   "equal" or "weighted"
#   truth        "Negative", "Emax1", "Emax2", "Emax3"  (4 of them)
#   kind         "Negative" or "Positive"
#   replicate    1..1000 within each design x truth cell
#   dunn_sig     1 if Dunnett declared a dose-response signal, else 0
#   mcp_sig      1 if MCP-Mod declared a signal
#   dunn_med     the dose Dunnett selected   (NA = none selected)
#   mcp_med      the dose MCP-Mod selected   (NA = none selected)
#   dunn_min_p   smallest adjusted p-value across active doses
#   mcp_min_p    MCP-Mod's contrast test p-value
#   obs_d<dose>  that trial's OBSERVED effect at <dose> (arm mean - placebo)
#   mod_d<dose>  that trial's MCP-Mod FITTED effect at <dose>
#                e.g. obs_d25, mod_d50. NA for doses a design did not study,
#                so a 3-arm design has no obs_d5 or obs_d10.
#
# results$oc also exists: the same thing already summarised, 30 rows. Use it to CHECK
# your answers -- but compute your own from `reps` first, or you will not learn
# anything.

# ---- Helpers, all from R/part-3/4-evaluate.R ---------------------------------
# That file is the SINGLE definition of what success means -- the stored
# results were computed with these same functions, so anything you work out
# yourself is directly comparable.
#
#   true_effect(truth, dose)        what is actually TRUE at that dose
#   acceptable(truth, med)          was the selected dose worth taking forward?
#                                     (a dose was selected AND its TRUE effect
#                                      clears Delta = 15%; NA is never OK)
#   claimed_viable(sig, med)        did the trial claim a viable dose exists?
#   is_success(truth, sig, med)     signal detected AND acceptable
#   mc_se(p, n_rep)                 Monte Carlo SE of a proportion
#   success_target / claim_target   0.70 and 0.15
#
# Two composed helpers also come along -- summarise_replicates() and
# check_objectives(). They do most of question 1 for you. Work it out from
# `reps` first; then use them to check.

cat(sprintf("Loaded %s trials: %d designs x %d truths x %d replicates\n",
            format(nrow(reps), big.mark = ","),
            dplyr::n_distinct(reps$design), dplyr::n_distinct(reps$truth),
            results$n_rep))
cat("True effect by truth and dose:\n")
print(round(outer(truth_scenarios$truth, c(5, 10, 25, 50, 100),
                  Vectorize(true_effect)) |>
              `dimnames<-`(list(truth_scenarios$truth,
                                paste0(c(5, 10, 25, 50, 100), "mg"))), 2))


# =========================================================================
# THE OBJECTIVES  (from Part 1)
# =========================================================================
#
#   A.  >= 70% probability of SUCCESS under EACH positive truth
#       Success = a signal was detected AND the selected dose is acceptable
#
#   B.  <= 15% probability of selecting a dose as clinically viable under the
#       NEGATIVE truth, where no dose is viable
#
# Note B is not "declared a signal". The negative truth has a real dose
# response -- it reaches 13% at 100 mg -- it is just never clinically viable.
# Check the signal rate under Negative and see for yourself.


# =========================================================================
# >>> YOUR TURN <<<
# =========================================================================
#
# The question a design meeting would actually ask:
#
#       WHICH DESIGN SHOULD WE RUN, AND WHY?
#
# Work it out from `reps`. Some directions worth taking -- do the ones you
# find interesting, not all of them:
#
#   1. Does ANY design meet both objectives? Compute success by design and
#      truth, and the negative-truth claim rate. Report Monte Carlo error.
#
#   2. Every design has a BINDING truth -- the one where it does worst. Which
#      is it, and is it the same for all six designs? Why might that be?
#
#   3. Does studying MORE doses help? Compare 3 / 4 / 5 active arms at the
#      same total N. Predict the direction before you compute it.
#
#   4. MCP-Mod vs Dunnett: both ran on identical trials, so this is a paired
#      comparison. Where is the difference biggest, and does it matter?
#
#   5. Go down to the replicates. Pick one design x truth cell and ask what
#      the FAILURES have in common. Which dose do they pick instead, and what
#      is that dose truly worth?
#
#   6. Make ONE figure you would put in front of a design team.
#
# Then: what would you change about the study to do better? More patients? A
# different dose set? Both are one more row in `design_scenarios`.

# your code here
