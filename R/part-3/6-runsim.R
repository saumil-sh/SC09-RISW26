# Part 3 — EXECUTE the simulation study
#
# Runs the full grid: 6 designs (3/4/5 active arms x equal/weighted
# allocation) x 5 truth scenarios = 30 cells. Dunnett and MCP-Mod are both
# computed on every replicate, so part 1's 12 x 5 grid is covered.
#
# This is the PRE-RUN script: it is executed before the course and its output
# is what the walkthrough displays. Nothing in part3-example.qmd re-simulates
# at render time.
#
# ALWAYS cap BLAS threads when running in parallel -- macOS Accelerate is
# multi-threaded by default and 6 worker processes thrash a 4-P-core machine:
#
#   OMP_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 OPENBLAS_NUM_THREADS=1 \
#     Rscript R/part-3/6-runsim.R      # 1,000 reps/cell, parallel via furrr
#
#   N_REP=100 Rscript R/part-3/6-runsim.R    # quick smoke test
#   PARALLEL=0 Rscript R/part-3/6-runsim.R   # force serial
#
# Measured on a 10-core laptop (4 performance cores), cost roughly LINEAR in
# sample size:
#   uncapped, N = 300 : 2.66 s per replicate of worker time -> 3.7 h for the grid
#   capped,   N = 240 : ~0.73 s                             -> 78 min for the grid
#
# Production work would use far more replicates on an HPC; 1,000 is for
# illustration.

suppressPackageStartupMessages({
  library(rxsim)
  library(dplyr)
  library(tidyr)
})

# Absolute, so parallel workers -- which do not reliably inherit the working
# directory -- can still find the component files.
PROJ <- normalizePath(getwd())
comp <- function(f) file.path(PROJ, "R", "part-3", f)

source(comp("1-scenarios.R"))
source(comp("2-datagen.R"))
source(comp("3-design.R"))
source(comp("4-evaluate.R"))

N_REP    <- as.integer(Sys.getenv("N_REP", "1000"))
PARALLEL <- Sys.getenv("PARALLEL", "1") == "1" &&
              requireNamespace("furrr", quietly = TRUE)
OUT_DIR  <- Sys.getenv("OUT_DIR", "data")

dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

# ---- One grid cell = one design x one truth, n_rep replicates -------------
# run_one() lives in R/part-3/5-run-one.R, same shape as Part 2's simulate_scenario().

source(comp("5-run-one.R"))

# ---- Run the grid ---------------------------------------------------------

grid <- scenarios |> dplyr::mutate(cell = dplyr::row_number(), seed = 2026 + cell)

cat(sprintf("Running %d cells x %d replicates (%s)...\n",
            nrow(grid), N_REP, if (PARALLEL) "parallel" else "serial"))

args_for <- function(i) {
  g <- grid[i, ]
  list(doses = g$doses[[1]], eMax = g$eMax, ed50 = g$ed50, h = g$h,
       allocation_scheme = g$allocation, n_rep = N_REP,
       sample_size = g$sample_size, seed = g$seed, proj = PROJ)
}

t_start <- Sys.time()

if (PARALLEL) {
  library(furrr)
  n_workers <- min(6L, parallel::detectCores())
  future::plan(future::multisession, workers = n_workers)
  cat(sprintf("  %d workers\n", n_workers))
  reps <- furrr::future_map(seq_len(nrow(grid)),
                            \(i) do.call(run_one, args_for(i)),
                            .options = furrr::furrr_options(seed = TRUE))
  future::plan(future::sequential)
} else {
  reps <- lapply(seq_len(nrow(grid)), function(i) {
    cat(sprintf("  cell %2d/%d\n", i, nrow(grid)))
    do.call(run_one, args_for(i))
  })
}

cat(sprintf("Elapsed: %.1f min\n",
            as.numeric(difftime(Sys.time(), t_start, units = "mins"))))

# ---- Replicate-level results ----------------------------------------------
# Keep every replicate, not just the averages: the aggregate is the answer,
# the replicates are the explanation.

replicates <- dplyr::bind_rows(Map(function(i, r) {
  g <- grid[i, ]
  cbind(
    data.frame(cell = g$cell, design = g$design, n_active = g$n_active,
               allocation = g$allocation, sample_size = g$sample_size,
               truth = g$truth, kind = g$kind,
               eMax = g$eMax, ed50 = g$ed50, h = g$h),
    # Everything the analysis returned, including the per-dose obs_d*/mod_d*
    # estimates. Designs study different dose sets, so bind_rows() NA-fills the
    # columns a given design does not have.
    r
  )
}, seq_len(nrow(grid)), reps))

# ---- Operating characteristics -------------------------------------------

oc <- dplyr::bind_rows(Map(function(i, r) {
  g <- grid[i, ]
  doses <- g$doses[[1]]
  cbind(
    data.frame(cell = g$cell, design = g$design, n_active = g$n_active,
               allocation = g$allocation, sample_size = g$sample_size,
               truth = g$truth, kind = g$kind,
               true_med = true_med_for(doses, g$eMax, g$ed50, g$h)),
    summarise_replicates(r, g$truth, true_med_for(doses, g$eMax, g$ed50, g$h))
  )
}, seq_len(nrow(grid)), reps))

objectives <- check_objectives(oc)

saveRDS(list(replicates = replicates, oc = oc, objectives = objectives,
             n_rep = N_REP, run_at = Sys.time()),
        file.path(OUT_DIR, "p3-results.rds"))

cat(sprintf("\nSaved -> %s  (%d cells x %d replicates)\n",
            file.path(OUT_DIR, "p3-results.rds"), nrow(grid), N_REP))
