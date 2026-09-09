# =========================================================================
# PART 3 EXERCISE — SOLUTION
# =========================================================================
#
# One worked answer to "which design should we run, and why?".
#
# These are exactly the summaries and figures shown in the Part 3 slides --
# part3-example.qmd builds them by sourcing this file, so what you see here is
# what is on screen. Every object is left in the environment, so you can pull
# one apart or re-plot it.
#
#     source("R/part-3/7-exercise.R")            # data + helpers
#     source("R/part-3/8-exercise-solution.R")
#
# -------------------------------------------------------------------------

if (!exists("reps")) source("R/part-3/7-exercise.R")

suppressPackageStartupMessages({library(dplyr); library(tidyr); library(ggplot2)})

teal <- "#1d5c4a"; teal_mid <- "#2a7a63"; teal_lt <- "#8fc4b3"
warn <- "#c0392b"; ink <- "#1e2a27"



# =========================================================================
# 1. Success and claim rates, per design x truth
# =========================================================================
# Everything downstream comes from this one summary. Note it is computed from
# the replicates, not taken from P$oc.

cell_summary <- reps |>
  group_by(design, n_active, allocation, truth, kind) |>
  summarise(
    # Objective A: signal detected AND an acceptable dose selected
    dunn_success = mean(is_success(truth, dunn_sig, dunn_med)),
    mcp_success  = mean(is_success(truth, mcp_sig,  mcp_med)),
    # Objective B: claimed SOME dose was viable (only meaningful under Negative)
    dunn_claim   = mean(claimed_viable(dunn_sig, dunn_med)),
    mcp_claim    = mean(claimed_viable(mcp_sig,  mcp_med)),
    # Diagnostics
    dunn_signal  = mean(dunn_sig),
    mcp_signal   = mean(mcp_sig),
    .groups = "drop"
  )

# Long form, one row per design x truth x method -- easier to plot.
long <- cell_summary |>
  pivot_longer(c(dunn_success, mcp_success, dunn_claim, mcp_claim),
               names_to = c("method", "metric"), names_sep = "_") |>
  mutate(method = recode(method, dunn = "Dunnett", mcp = "MCP-Mod"))


# =========================================================================
# 2. Does any design meet both objectives?
# =========================================================================

# Two different questions about the same numbers:
#   mean_success  marginalising over the positive truths, weighting them
#                 equally -- "how does this design do in expectation?"
#   min_success   the worst positive truth -- "is there a plausible truth where
#                 this design lets us down?"
# A design can look fine on the first and fail badly on the second.
worst_positive <- long |>
  filter(kind == "Positive", metric == "success") |>
  group_by(design, n_active, allocation, method) |>
  summarise(mean_success  = mean(value),
            min_success   = min(value),
            binding_truth = truth[which.min(value)],
            .groups = "drop")

neg_claim <- long |>
  filter(kind == "Negative", metric == "claim") |>
  select(design, method, claim_rate = value)

verdict <- worst_positive |>
  left_join(neg_claim, by = c("design", "method")) |>
  mutate(meets_A_mean = mean_success >= success_target,   # on average
         meets_A      = min_success  >= success_target,   # on EVERY truth
         meets_B      = claim_rate   <= claim_target,
         meets        = meets_A & meets_B) |>
  arrange(desc(min_success))

cat("\n=== Which designs meet both objectives? ===\n")
print(as.data.frame(verdict |>
  transmute(design, method,
            `worst success` = round(min_success, 3), binding_truth,
            `neg claim` = round(claim_rate, 3),
            A = ifelse(meets_A, "yes", "NO"),
            B = ifelse(meets_B, "yes", "NO"))), row.names = FALSE)

cat(sprintf("\n  Monte Carlo SE at p = 0.75 with %d reps: %.3f\n",
            results$n_rep, mc_se(0.75, results$n_rep)))
cat(sprintf("  Designs meeting BOTH: %d of %d\n", sum(verdict$meets), nrow(verdict)))


# =========================================================================
# 3. FIGURE — success under every positive truth
# =========================================================================

fig_heatmap <- long |>
  filter(kind == "Positive", metric == "success") |>
  ggplot(aes(truth, design, fill = value)) +
  geom_tile(colour = "white", linewidth = 2) +
  geom_text(aes(label = sprintf("%.2f", value), colour = value > 0.88),
            size = 3.6, show.legend = FALSE) +
  facet_wrap(~ method) +
  scale_fill_gradient2(midpoint = success_target, low = warn, mid = "grey88",
                       high = teal, limits = c(0, 1), name = "P(success)") +
  scale_colour_manual(values = c(`TRUE` = "white", `FALSE` = ink)) +
  labs(x = NULL, y = NULL) +
  theme_minimal(base_size = 13) +
  theme(plot.background = element_rect(fill = "transparent", colour = NA),
        panel.background = element_rect(fill = "transparent", colour = NA)) +
  theme(panel.grid = element_blank(), axis.text = element_text(colour = ink))


# =========================================================================
# 3b. FIGURE — the operating-characteristic plot
# =========================================================================
# Read like an ROC curve: false positives across, success up. The good corner
# is TOP LEFT. Colour = number of active arms (a magnitude, so one hue light to
# dark); shape = analysis method; open points = weighted allocation. The shaded
# box is the region where BOTH objectives hold.

# Three things to encode in one panel: number of arms, analysis method and
# allocation. Colour carries the arms (a magnitude, so one hue light->dark).
# Method and allocation are combined into ONE shape scale -- circle/triangle for
# the method, solid/open for the allocation -- so the reader has a single legend
# to consult rather than mentally crossing two.
oc_shapes <- c("Dunnett · equal"    = 16, "Dunnett · weighted"  = 1,
               "MCP-Mod · equal"    = 17, "MCP-Mod · weighted"  = 2)

oc_plot <- function(dat, yvar, ylab, zoom = FALSE) {
  d <- dat |>
    mutate(mark = factor(paste(method, allocation, sep = " · "),
                         levels = names(oc_shapes)))

  p <- ggplot(d, aes(claim_rate, .data[[yvar]])) +
    geom_vline(xintercept = claim_target, linetype = "dashed",
               colour = warn, linewidth = 0.9) +
    geom_hline(yintercept = success_target, linetype = "dashed",
               colour = warn, linewidth = 0.9) +
    geom_point(aes(colour = factor(n_active), shape = mark),
               size = 4.2, stroke = 1.4) +
    scale_colour_manual(values = c(`3` = teal_lt, `4` = teal_mid, `5` = teal),
                        name = "Active arms") +
    scale_shape_manual(values = oc_shapes, name = NULL) +
    guides(colour = guide_legend(override.aes = list(shape = 16, size = 4))) +
    labs(x = sprintf("P(claim a viable dose | negative truth)   → objective ≤ %.2f",
                     claim_target),
         y = ylab) +
    theme_minimal(base_size = 13) +
    theme(plot.background = element_rect(fill = "transparent", colour = NA),
          panel.background = element_rect(fill = "transparent", colour = NA)) +
    theme(panel.grid.minor = element_blank(),
          axis.title = element_text(size = 11),
          axis.text = element_text(colour = ink))

  if (zoom) {
    # Zoomed to the region where BOTH objectives hold: the thresholds become the
    # right and bottom edges of the panel. coord_cartesian() clips rather than
    # dropping rows, so designs that fail simply fall outside the frame.
    # Few enough points survive the zoom that we can name each one. Label ONLY
    # the points inside the frame -- otherwise ggrepel places labels for the
    # clipped points too and drags leader lines back into view.
    d_in <- d[d$claim_rate <= claim_target & d[[yvar]] >= success_target, ]
    p +
      ggrepel::geom_text_repel(
        data = d_in, aes(label = design, colour = factor(n_active)),
        size = 3.4, fontface = "bold", show.legend = FALSE,
        seed = 1, min.segment.length = 0.2, box.padding = 0.6,
        segment.colour = "grey65", segment.size = 0.3, max.overlaps = Inf) +
      coord_cartesian(xlim = c(0, claim_target),
                      ylim = c(success_target, 1), expand = TRUE)
  } else {
    p +
      annotate("rect", xmin = 0, xmax = claim_target,
               ymin = success_target, ymax = 1, fill = teal, alpha = 0.08) +
      geom_point(aes(colour = factor(n_active), shape = mark),
                 size = 4.2, stroke = 1.4) +
      scale_x_continuous(limits = c(0, 1), breaks = seq(0, 1, 0.2)) +
      scale_y_continuous(limits = c(0, 1), breaks = seq(0, 1, 0.2)) +
      coord_fixed()
  }
}

# Shaded corner = both objectives hold. Read like an ROC curve: the good corner
# is TOP LEFT.
fig_oc <- oc_plot(verdict, "mean_success",
  sprintf("MEAN P(success) across positive truths   → objective ≥ %.2f",
          success_target))

# Same plot, but judging each design on its WORST positive truth rather than
# its average. A design can sit in the shaded corner on the left-hand version
# and fall out of it here -- that gap is the cost of the averaging.
fig_oc_min <- oc_plot(verdict, "min_success",
  sprintf("WORST P(success) across positive truths   → objective ≥ %.2f",
          success_target))

# Zoomed to the passing region -- only the designs that clear BOTH objectives
# appear, so the question shifts from "which pass?" to "which is best?".
fig_oc_zoom <- oc_plot(verdict, "mean_success",
  sprintf("MEAN P(success)   → objective ≥ %.2f", success_target), zoom = TRUE)

fig_oc_min_zoom <- oc_plot(verdict, "min_success",
  sprintf("WORST P(success)   → objective ≥ %.2f", success_target), zoom = TRUE)


# =========================================================================
# 4. FIGURE — the binding constraint
# =========================================================================

fig_binding <- verdict |>
  ggplot(aes(min_success, reorder(design, min_success), colour = method)) +
  geom_vline(xintercept = success_target, linetype = "dashed",
             colour = warn, linewidth = 0.9) +
  geom_line(aes(group = design), colour = "grey80", linewidth = 1.4) +
  geom_point(size = 3.6) +
  scale_colour_manual(values = c(Dunnett = teal_lt, `MCP-Mod` = teal), name = NULL) +
  scale_x_continuous(limits = c(0, 1), breaks = seq(0, 1, 0.2)) +
  labs(x = "Worst-case P(success) across the positive truths", y = NULL) +
  theme_minimal(base_size = 13) +
  theme(plot.background = element_rect(fill = "transparent", colour = NA),
        panel.background = element_rect(fill = "transparent", colour = NA)) +
  theme(panel.grid.major.y = element_blank(),
        axis.text = element_text(colour = ink))


# =========================================================================
# 4b. FIGURE — the MCP-Mod estimate at the true MED, by design size
# =========================================================================
# Replicate level, positive truths only. For each truth we take the dose the
# trial is trying to find -- its true MED -- and show the spread of what
# DUNNETT estimated there, split by how many active arms the design studied.
#
# Restricted to trials that were POSITIVE (significant). That is the honest
# comparison -- an estimate from a trial that failed never gets reported -- but
# it also conditions on significance, which biases the estimates upward. The
# gap between each violin and its truth line IS that bias.

VIOLIN_ALLOC <- "equal"   # one allocation at a time keeps the panels readable

.full_doses <- arm_sets$doses[[which.max(arm_sets$n_active)]]

violin_spec <- truth_scenarios |>
  filter(kind == "Positive") |>
  mutate(dose = mapply(function(e, d, hh) true_med_for(.full_doses, e, d, hh),
                       eMax, ed50, h)) |>
  mutate(truth_val = mapply(true_effect, truth, dose),
         panel     = sprintf("%s  —  true MED %s mg", truth, dose)) |>
  select(truth, dose, truth_val, panel) |>
  as.data.frame()

# cond = "success" -> only trials that SUCCEEDED (significant AND an acceptable
#                     dose selected) -- the trials whose estimate would ever be
#                     reported and acted on
# cond = "all"     -> every simulated trial, successful or not
violin_data <- function(cond = c("success", "all")) {
  cond <- match.arg(cond)
  do.call(rbind, lapply(seq_len(nrow(violin_spec)), function(i) {
    s <- violin_spec[i, ]
    r <- reps[reps$truth == s$truth & reps$allocation == VIOLIN_ALLOC, ]
    keep <- if (cond == "success") {
      is_success(r$truth, r$mcp_sig, r$mcp_med)
    } else rep(TRUE, nrow(r))
    data.frame(panel    = factor(s$panel, levels = violin_spec$panel),
               n_active = factor(r$n_active[keep], levels = c(3, 4, 5)),
               estimate = r[[paste0("mod_d", s$dose)]][keep])
  })) |> subset(!is.na(estimate))
}

violin_spec$panel <- factor(violin_spec$panel, levels = violin_spec$panel)

violin_plot <- function(d, subtitle) {
  ggplot(d, aes(n_active, estimate, fill = n_active)) +
    geom_hline(data = violin_spec, aes(yintercept = truth_val),
               colour = teal, linewidth = 1.1) +
    geom_hline(yintercept = Delta, colour = warn, linetype = "dashed",
               linewidth = 0.9) +
    geom_violin(alpha = 0.9, colour = "white", linewidth = 0.4, width = 0.9,
                trim = FALSE, show.legend = FALSE) +
    geom_boxplot(width = 0.12, outlier.shape = NA, fill = "white",
                 colour = "grey25", linewidth = 0.4, show.legend = FALSE) +
    geom_text(data = violin_spec, aes(x = 0.42, y = truth_val, label = "truth"),
              inherit.aes = FALSE, hjust = 0, vjust = -0.6, colour = teal,
              size = 3.2, fontface = "bold") +
    facet_wrap(~ panel) +
    scale_fill_manual(values = c(`3` = teal_lt, `4` = teal_mid, `5` = teal)) +
    labs(x = "Active dose arms", y = "MCP-Mod estimate at the true MED (%)",
         caption = sprintf("%s allocation; %s; red dashed line is the %d%% viability bar",
                           VIOLIN_ALLOC, subtitle, Delta)) +
    theme_minimal(base_size = 13) +
    theme(plot.background = element_rect(fill = "transparent", colour = NA),
          panel.background = element_rect(fill = "transparent", colour = NA)) +
    theme(panel.grid.minor = element_blank(),
          panel.grid.major.x = element_blank(),
          strip.text = element_text(face = "bold", colour = ink),
          plot.caption = element_text(colour = "grey40", size = 9))
}

est     <- violin_data("success")
est_all <- violin_data("all")

fig_violin     <- violin_plot(est,     "successful trials only")
fig_violin_all <- violin_plot(est_all, "ALL simulated trials")


# =========================================================================
# 5. Where do the failures go? (the replicate-level answer)
# =========================================================================
# Which truth is binding varies by design, so take the one that binds the MOST
# design x method combinations -- that is the scenario the study as a whole is
# weakest against. Under it, what do the trials that fail actually pick?

binding <- names(sort(table(verdict$binding_truth), decreasing = TRUE))[1]
med_binding <- true_med_for(arm_sets$doses[[3]],
                            truth_scenarios$eMax[truth_scenarios$truth == binding],
                            truth_scenarios$ed50[truth_scenarios$truth == binding],
                            truth_scenarios$h[truth_scenarios$truth == binding])

failures <- reps |>
  filter(truth == binding) |>
  mutate(outcome = case_when(
    is.na(mcp_med)                      ~ "no dose selected",
    acceptable(truth, mcp_med)          ~ sprintf("acceptable (>= %d%% true)", Delta),
    TRUE                                ~ "sub-threshold dose selected")) |>
  count(design, outcome) |>
  group_by(design) |>
  mutate(prop = round(n / sum(n), 3)) |>
  ungroup()

cat(sprintf("\n=== Under %s (true MED = %s mg), what MCP-Mod picked ===\n",
            binding, med_binding))
print(as.data.frame(failures |> select(design, outcome, prop) |>
                    pivot_wider(names_from = outcome, values_from = prop)),
      row.names = FALSE)

fail_dat <- reps |>
  filter(truth == binding, allocation == "equal", !is.na(mcp_med)) |>
  count(design, mcp_med) |>
  group_by(design) |>
  mutate(prop = n / sum(n)) |>
  ungroup() |>
  mutate(dose = factor(mcp_med, levels = sort(unique(mcp_med))))

# Position the marker by matching the FACTOR LEVELS actually plotted -- indexing
# into the full dataset's dose list puts the line on the wrong category when a
# design set does not study every dose.
med_x <- match(as.character(med_binding), levels(fail_dat$dose))

fig_failures <- fail_dat |>
  ggplot(aes(dose, prop, fill = design)) +
  geom_col(position = position_dodge(0.8), width = 0.72) +
  geom_vline(xintercept = med_x, linetype = "dashed",
             colour = warn, linewidth = 0.9) +
  scale_fill_manual(values = c(teal_lt, teal_mid, teal), name = NULL) +
  labs(x = "Dose selected (mg)", y = "Proportion of trials",
       title = sprintf("Truth = %s, equal allocation - true MED is %s mg",
                       binding, med_binding)) +
  theme_minimal(base_size = 13) +
  theme(plot.background = element_rect(fill = "transparent", colour = NA),
        panel.background = element_rect(fill = "transparent", colour = NA)) +
  theme(panel.grid.major.x = element_blank(),
        plot.title = element_text(size = 12))


# =========================================================================
# 6. The recommendation
# =========================================================================

# Written from the data, so it stays true if the objectives are re-tuned.

best     <- verdict |> slice_max(min_success, n = 1)
passing  <- verdict |> filter(meets)
fail_A   <- verdict |> filter(!meets_A)
fail_B   <- verdict |> filter(!meets_B)

# How close is each failure to its threshold, in Monte Carlo standard errors?
# A "failure" inside 1 SE is not a distinction you can defend.
margin_A <- fail_A |>
  mutate(short_by = success_target - min_success,
         in_se    = short_by / mc_se(min_success, results$n_rep))
margin_B <- fail_B |>
  mutate(over_by = claim_rate - claim_target,
         in_se   = over_by / mc_se(claim_rate, results$n_rep))

cat("\n=== Recommendation ===\n")
cat(sprintf("  Objectives: success >= %.2f under every positive truth; \n",
            success_target))
cat(sprintf("              claiming a viable dose <= %.2f under the negative truth.\n\n",
            claim_target))
cat(sprintf("  %d of %d design x method combinations meet BOTH.\n",
            nrow(passing), nrow(verdict)))
cat(sprintf("  Best: %s with %s -- worst-case success %.3f (binding truth %s),\n",
            best$design, best$method, best$min_success, best$binding_truth))
cat(sprintf("        claim rate %.3f under the negative truth.\n", best$claim_rate))

cat(sprintf("\n  Objective A fails for: %s\n",
            if (nrow(fail_A)) paste(fail_A$design, fail_A$method, collapse = "; ") else "none"))
cat(sprintf("  Objective B fails for: %s\n",
            if (nrow(fail_B)) paste(fail_B$design, fail_B$method, collapse = "; ") else "none"))

cat("\n  Both objectives now bind, and they bind on DIFFERENT designs -- which is\n")
cat("  the point of carrying more than one. A design can be adequately powered\n")
cat("  and still claim a viable dose too often when none exists.\n")

if (any(margin_A$in_se < 1) || any(margin_B$in_se < 1)) {
  cat("\n  A caveat we are setting aside for this example. Some of these calls are\n")
  cat("  very close to their threshold -- within one Monte Carlo SE at 1,000\n")
  cat("  replicates:\n")
  for (i in seq_len(nrow(margin_A))) if (margin_A$in_se[i] < 1)
    cat(sprintf("    %s / %s : success %.3f vs %.2f target (%.1f SE)\n",
        margin_A$design[i], margin_A$method[i], margin_A$min_success[i],
        success_target, margin_A$in_se[i]))
  for (i in seq_len(nrow(margin_B))) if (margin_B$in_se[i] < 1)
    cat(sprintf("    %s / %s : claim %.3f vs %.2f target (%.1f SE)\n",
        margin_B$design[i], margin_B$method[i], margin_B$claim_rate[i],
        claim_target, margin_B$in_se[i]))
  cat("\n  TODAY we treat these estimates as exact, so the pass/fail table reads\n")
  cat("  cleanly. In real work you would raise the replicate count until the\n")
  cat("  Monte Carlo error was small relative to the margin you care about --\n")
  cat("  and you would report the estimate WITH its uncertainty either way.\n")
}
