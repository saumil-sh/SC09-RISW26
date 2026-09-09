# Plan — SC09-RISW26 as a Quarto revealjs presentation

## Problem

`SC09-RISW26` is an empty repo (no commits, no remote, just `.Rproj` and a 4-line
`.gitignore`). The course content lives in `../risw-2026` as four independent Quarto
documents. We want this repo to become the publishable deliverable: **one revealjs deck**
(`index.qmd`) that `{{< include >}}`s the parts, published to GitHub Pages, with a single
combined references slide at the end.

## Approach

A Quarto **project** (`project: type: default`) with a single rendered output, `index.qmd`:

- `index.qmd` holds the **only** YAML header (all revealjs format options, bibliography,
  nocite) plus part-divider slides, `{{< include >}}` lines, and the final References slide.
- The four content files are copied over, **stripped of their YAML headers**, and renamed
  with a leading underscore (`_setup.qmd`, `_part1-overview.qmd`, `_part2-programming.qmd`,
  `_part3-example.qmd`) so Quarto does not try to render them standalone.
- Code is executed on whichever machine runs `quarto render` / `quarto publish` — no
  `freeze`, no `_freeze/` to commit, no stale-artifact failure mode.
- **Publish path (final, post-implementation): local `quarto publish gh-pages` only.** A
  CI-executed `.github/workflows/publish.yml` was tried first and built successfully, but
  its first live run failed at the `gh-pages` push (needs "Read and write" workflow
  permissions, off by default, not fixable by the acting token/CLI — 403). Rather than
  chase that permissions fix, the user ran `quarto publish gh-pages` locally, which
  succeeded immediately. **The GitHub Actions workflow was deleted** — running both would
  race to push the same `gh-pages` branch from two places, which is a conflict, not
  redundancy. There is no CI and no auto-deploy on push: publishing is a manual, local
  `quarto publish gh-pages` run whenever the deck should go live.
- `_publish.yml` is written by hand (4 lines); `quarto publish gh-pages` reads/updates it.
- Publish target: `gh-pages` on `git@github.com:saumil-sh/SC09-RISW26.git`. The published
  deck lives at `https://saumil-sh.github.io/SC09-RISW26/` (confirmed live, HTTP 200). The
  repo **already exists** and is public (checked: HTTP 200) — no creation step.

`index.qmd` (not `slides.qmd`) so the published site has a real `index.html` at its root.

### Why includes still behave like a merge

`{{< include >}}` splices raw content before knitr runs, so the whole deck is **one R
session and one knitr document**. Every collision hazard of a physical merge still applies
— they are listed under Task 5 and are the substance of this work.

## Target layout

```
SC09-RISW26/
├── .gitignore                 # gitignore.io: linux,windows,macos,r,visualstudiocode (+ quarto, *_files/, *_cache/)
├── .renvignore
├── .Rprofile
├── _quarto.yml                # project: default, render: [index.qmd], output-dir: _site
├── _publish.yml               # gh-pages target + site-url, hand-written
├── LICENSE                    # CC BY-SA 4.0, official text
├── index.qmd                  # sole YAML header + dividers + includes + References
├── _setup.qmd
├── _part1-overview.qmd
├── _part2-programming.qmd
├── _part3-example.qmd
├── references.bib
├── assets/{theme.scss, css/custom.css}
├── R/part-2/{1-one-arm.R … 6-timing-comparison.R}
├── R/part-3/{1-scenarios.R … 8-exercise-solution.R}
├── data/p3-results.rds
├── renv.lock, renv/{activate.R, settings.json}
└── SC09-RISW26.Rproj
```

Not copied: `materials/`, `CLAUDE.md`, `TODO.md`, `outline.md`, `part2-programming.html`,
`part2-programming_files/`.

## Licensing requirement — CC BY-SA 4.0

- License the original course materials under **Creative Commons Attribution-ShareAlike
  4.0 International (CC BY-SA 4.0)**:
  https://creativecommons.org/licenses/by-sa/4.0/.
- During implementation, add a root `LICENSE` containing the official license text from
  https://creativecommons.org/licenses/by-sa/4.0/legalcode.txt, and a visible attribution
  and license link in the presentation. Retain the existing author credits for Mitch
  Thomann and Saumil Shah, with the published presentation URL as the source link.
- State that reuse requires attribution, a license link, and an indication of changes;
  adaptations must be shared under CC BY-SA 4.0 or a compatible license.
- Preserve any existing notices on third-party material. Citations do not grant permission
  to relicense third-party figures, excerpts, fonts, or software; identify exclusions
  rather than implying the course license covers them.
- Make the license notice accessible in both the GitHub repository and the published
  deck, without adding a slide after the final combined References slide. **Concrete
  placement (decided):** root `LICENSE` file, plus a one-line footer on the `index.qmd`
  title slide: `Slides © 2026 Mitch Thomann & Saumil Shah — CC BY-SA 4.0` linked to
  https://creativecommons.org/licenses/by-sa/4.0/.
- Do not add or change package/software licenses as part of this content migration.

---

## Todos

### 1. `ignore-files` — Ignore files
- `.gitignore` from the gitignore.io API (`linux,windows,macos,r,visualstudiocode`), then
  append a Quarto block: `/.quarto/`, `_site/`, `site_libs/`, `_extensions`, `_freeze/`,
  `*_files/`, `*_cache/`, `**/*.quarto_ipynb`, `rsconnect/`. `_freeze/` is ignored because
  freeze is not used — nothing render-derived belongs in git.
- `.renvignore`: `assets/`, `data/`, `*_files/`, `*_cache/`. renv already excludes its own
  `renv/` directory, and `.Rproj.user/` contains no R code to scan. Deliberately **not**
  ignoring `R/` or the `.qmd` files — those are what renv scans for dependencies.

### 2. `copy-assets` — Copy content from `../risw-2026`
- `assets/theme.scss`, `assets/css/custom.css`, `references.bib`, `data/p3-results.rds`.
- `renv.lock`, `renv/activate.R`, `renv/settings.json`, `.Rprofile`.
- The four `.qmd` files (renamed in Task 4).
- Copy as plain files — do not import `../risw-2026` git history.
- **`.Rprofile` must point at the public Posit Package Manager.** The source file pins
  `https://packagemanager.posit.co/cran/__linux__/noble/2026-08-27`. The `__linux__/noble`
  segment forces Ubuntu-24.04 binaries, so a Windows or macOS attendee gets no binaries and
  compiles everything from source. Drop that segment and keep the dated snapshot —
  `https://packagemanager.posit.co/cran/2026-08-27` — which is public, cross-platform, and
  still reproducible because the date is pinned.

### 3. `move-scripts` — Reorganize `R/` into per-part subfolders

| From | To |
|---|---|
| `R/p2-1-one-arm.R` | `R/part-2/1-one-arm.R` |
| `R/p2-2-two-arm.R` | `R/part-2/2-two-arm.R` |
| `R/p2-3-two-look.R` | `R/part-2/3-two-look.R` |
| `R/p2-4-grid.R` | `R/part-2/4-grid.R` |
| `R/p2-5-parallel.R` | `R/part-2/5-parallel.R` |
| `R/p2-timing-comparison.R` | `R/part-2/6-timing-comparison.R` |
| `R/p3-1-scenarios.R` | `R/part-3/1-scenarios.R` |
| `R/p3-2-datagen.R` | `R/part-3/2-datagen.R` |
| `R/p3-3-design.R` | `R/part-3/3-design.R` |
| `R/p3-4-evaluate.R` | `R/part-3/4-evaluate.R` |
| `R/p3-run-one.R` | `R/part-3/5-run-one.R` |
| `R/p3-runsim.R` | `R/part-3/6-runsim.R` |
| `R/p3-exercise.R` | `R/part-3/7-exercise.R` |
| `R/p3-exercise-solution.R` | `R/part-3/8-exercise-solution.R` |

Numeric prefixes preserve the teaching order **and** keep `list.files()` (alphabetical)
returning the right sequence for `knitr::read_chunk()`.

**Naming decision (recorded, do not reinterpret):** the answer keys are named
`1-one-arm.R`, not the `1-work-one-arm.R` from the original request example. In Part 2's
pedagogy `R/work-*.R` are files the *participants* create themselves; prefixing the
answer keys with `work-` would invert that meaning. If the literal `work-` names are
wanted anyway, that is a pre-implementation change, not an implementer's judgment call.

Then fix every path that refers to these files:

- **Inside the scripts:** `7-exercise.R` sources `1-scenarios.R` and `4-evaluate.R`;
  `8-exercise-solution.R` sources `7-exercise.R`; `5-run-one.R` sources scenarios/datagen/
  design via `file.path(proj, "R", ...)`; `6-runsim.R` sources five files via its
  `comp()` helper. The `file.path(proj, "R", ...)` forms matter most — they are what
  **parallel workers** use to re-source in a fresh session, so a stale path fails only
  under parallelism.
- **In the slides:** `_part2-programming.qmd`'s `read_chunk` glob (Task 5),
  `source("R/p2-timing-comparison.R")`, `_part3-example.qmd`'s `source("R/p3-1-scenarios.R")`
  and the two exercise `source()` calls.
- **In prose/tables shown to participants:** the `R/work-*.R` → `R/p2-*.R` mapping tables in
  Part 2 (5 tables), and the "it worked if `source(...)` prints one row" lines in Part 1 and
  setup. These are instructions attendees type — they must match the shipped tree.

`R/p2-timing-comparison.R` line 2 is a comment naming its own path; update it too.

**The renamed scripts must actually run, not just resolve on paper.** From the project
root, in fresh R sessions:
- Part 2: `Rscript R/part-2/1-one-arm.R` through `Rscript R/part-2/5-parallel.R` — each
  prints its expected result row(s).
- Part 3: `Rscript R/part-3/7-exercise.R` and `Rscript R/part-3/8-exercise-solution.R`
  run against the shipped `data/p3-results.rds` and print the study summary.
- Parallel worker paths: `N_REP=5 PARALLEL=1 OUT_DIR=$(mktemp -d) Rscript R/part-3/6-runsim.R`.
  **Local verification only — never as part of `quarto render`/`quarto publish`** (worker
  sizing on any machine that runs this is not something the deck should depend on; the
  render forces a sequential plan, see Task 5). This is the **only** check that exercises
  the `file.path(proj, "R", ...)` sourcing inside `5-run-one.R` under real `multisession`
  workers — a sequential smoke test passes with stale paths there. 30 cells × 5 reps
  finishes in about a minute and writes to a temp dir. Do **not** run `6-runsim.R` with
  defaults: that is the 78-minute pre-course run and it overwrites the shipped
  `data/p3-results.rds`.

### 4. `strip-headers` — Convert the four files into includable fragments
Rename to `_setup.qmd`, `_part1-overview.qmd`, `_part2-programming.qmd`, `_part3-example.qmd`
and delete each YAML header. Everything in those headers is either promoted to `index.qmd`
(bibliography, `link-citations`, `citations-hover`, `from: markdown+emoji`, the revealjs
format block, which is byte-identical across the three parts) or dropped (per-part
`title`/`subtitle`/`author`/`date`, setup's `toc`/`toc-location`/HTML format, the two partial
`nocite` blocks — superseded by Task 7).

### 5. `fix-collisions` — Resolve one-document / one-session collisions

This is the core risk. Verified hazards:

- **Duplicate chunk label `setup`** — present in Part 1, Part 2 *and* Part 3. Three chunks
  with the same label is a hard knitr error and will stop the render immediately. Rename to
  `setup-p1`, `setup-p2`, `setup-p3`. All other 45 labels are already unique across files.
- **Leave the three `knitr::opts_chunk$set()` calls alone.** They work today in exactly
  this order; merging them is speculative refactoring. Only the labels change. Part 2's
  22 explicit `#| echo: true` chunk options are what survive Part 1's `echo = FALSE` —
  do not remove them.
- **`read_chunk` glob** in Part 2: `list.files("R", pattern = "^p2-.*\\.R$")` →
  `list.files("R/part-2", pattern = "\\.R$", full.names = TRUE)`. Included-file relative
  paths resolve against `index.qmd` at the project root, so `R/part-2` is correct. This
  glob supplies chunks `params`, `generator`, `s2-*` … `s5-*` — if it matches nothing
  they render **empty, not erroring**, so verify by output, not exit status.
- **Execution behavior is preserved, not "fixed".** `s5-workers` and `s5-timing` are
  `eval: false`; Part 2's only executed parallel chunk is `s5-parallel`, which already
  runs on the default sequential plan. Nothing opens workers mid-render and there is no
  stuck-cluster hazard. Leave every `eval` flag alone.
- **No multisession on render, by construction.** Whoever runs `quarto render` /
  `quarto publish` (currently: local machine only, see Task 9/10), the render must never
  size or start a cluster. Two guarantees: `s5-workers` (the only chunk calling
  `future::plan(multisession)`) stays `eval: false`, **and** the `setup-p2` chunk gains
  one explicit line, `future::plan(future::sequential)`, so `future_lapply` in
  `s5-parallel` runs sequentially even if a plan is ever set earlier in the session. The
  render only ever runs `quarto render` — no R script is invoked directly — so
  `6-runsim.R`'s multisession path (and its `min(6L, detectCores())` worker count) cannot
  fire there.
- **Object collisions are handled by ordering, not renaming.** Chunk code lives in the
  `R/` files via `read_chunk`, so the real collision set includes `results` (Part 2's
  `s5-parallel` vs Part 3's `7-exercise.R`) alongside Part 1 vs Part 3's `curves`,
  `dose_grid`, `marks`, `target_label`. Each part assigns before it reads, and the
  deck order 1 → 2 → 3 makes last-write-wins correct by construction. The earlier claim
  that "no Part 2↔3 collisions exist" was wrong — it only looked at the `.qmd` bodies.
- **The acceptance check is one behavioral diff, not a collision audit:** render the
  three parts standalone in `../risw-2026`, render the merged deck, confirm figures and
  printed numbers match. That subsumes every collision and chunk-option question above.
- **Duplicate divider titles** "Welcome" (Parts 1, 2) and "Wrap-up" (Parts 2, 3): Quarto
  auto-suffixes duplicate slide IDs. Rename only if an internal anchor link needs a
  stable target; otherwise leave them.

### 6. `build-index` — Write `index.qmd`
- One YAML header: document metadata kept from the parts — `title: "Trial Simulations in R"`,
  `subtitle: "A Framework for Informing Modern Clinical Development"`, authors
  Mitch Thomann and Saumil Shah, `date: "September 16, 2026"` — plus the shared revealjs
  block (1280×720, `slide-level: 2`, `incremental: true`,
  `theme: [simple, assets/theme.scss]`, `css: assets/css/custom.css`, `html-math-method: mathml`,
  teal title-slide background, `from: markdown+emoji`), `bibliography`, `link-citations`,
  `citations-hover`, `nocite: "@*"`.
- Keep `html-math-method: mathml` deliberately: MathJax/KaTeX pull from a CDN, and this deck
  has to render in a conference room with no reliable internet.
- Body: a part-divider slide before each include.
  ```
  {{< include _setup.qmd >}}
  {{< include _part1-overview.qmd >}}
  {{< include _part2-programming.qmd >}}
  {{< include _part3-example.qmd >}}
  ```
- **Setup goes first**, as pre-work before Part 1. It is currently a long-form HTML page with
  seven `#` sections, so it needs restructuring into slides (`.smaller`/`.scrollable` where
  dense). Its `::: {.panel-tabset}` works as-is in revealjs. Easily moved to the end as an
  appendix instead if you prefer — say so and I will.
- Fix now-internal cross-document links: Part 1's `[setup.html](setup.html)`, Part 2's
  `Setup & troubleshooting: setup.html`, and setup's trailing
  `[← Back to the workshop](part2-programming.html)` become in-deck anchors or are removed.

### 7. `combine-refs` — One references slide at the end
- Delete the per-part References slides in `_part1-overview.qmd` (line ~1114) and
  `_part3-example.qmd` (line ~869). Part 2 has no bibliography.
- Add one final slide in `index.qmd`:
  ```
  ## References :books: {.smaller .scrollable}

  ::: {#refs}
  :::
  ```
- Use `nocite: "@*"` (a string — the block-scalar form `nocite: | @*` is invalid if copied
  literally) in the `index.qmd` header. This yields the union of everything cited
  anywhere **plus** the entries missed so far: Part 1 cites 11 keys, Part 3 cites 5
  (overlapping) for a union of 12, and `@*` additionally picks up `ema2014mcpmod` and
  `endpointspkg` — all 14 entries in `references.bib`. `@*` only covers entries present
  in the bib; do one citation-completeness read of the final deck for sources that were
  never added.
- Acceptance criterion: all 14 entries **readable at the deck's native 1280×720 without
  scrolling**. Keep `{.smaller .scrollable}` as the backstop and add a targeted rule to
  `assets/css/custom.css` (start with `.reveal .slides #refs { font-size: 0.55em; }`,
  tune from there). Verify visually in the rendered deck, not by counting lines.

### 8. `quarto-project` — `_quarto.yml`
```yaml
project:
  type: default
  output-dir: _site
  render:
    - index.qmd
```
`render: [index.qmd]` is load-bearing: without it a project render picks up every `.qmd`
**and `.md`** in the root — including `plan.md` — and publishes them. The underscore-
prefixed fragments are skipped either way.

### 9. `gh-workflow` — REMOVED; superseded by local `quarto publish gh-pages`
**Decision reversal (post-implementation):** a CI-executed `.github/workflows/publish.yml`
(checkout → quarto setup → setup-r → setup-renv → `quarto-actions/publish@v2`) was built
and pushed, but its first run failed at the publish step — pushing to `gh-pages` needs
"Read and write" default workflow permissions, off by default, and neither the acting
token nor the CLI could flip that setting (403, insufficient scope). Rather than chase
the permissions fix, **the user ran `quarto publish gh-pages` locally, which succeeded and
is now live.** Per explicit instruction, **local publish is the primary and only publish
path going forward**; the GitHub Actions workflow was deleted
(`.github/workflows/publish.yml` and the now-empty `.github/` directory) because a CI
workflow racing to push the same `gh-pages` branch as local publishes is a conflict, not
redundancy — whichever runs last silently wins and the other's push looks like it
"failed" for no visible reason. No workflow permissions fix, no Pages-source click
process is required by this path: `quarto publish gh-pages` creates/updates the
`gh-pages` branch directly from the local machine and GitHub Pages autodetects it.

### 10. `publish-setup` — Repo config and first publish (via local `quarto publish gh-pages`)
The repo `saumil-sh/SC09-RISW26` already exists and is public (verified: HTTP 200 on
both the API and web URL) — no creation step.
- `_publish.yml` is hand-written once and left as-is; `quarto publish gh-pages` reads/updates
  it:
  ```yaml
  - source: project
    gh-pages:
      site-url: https://saumil-sh.github.io/SC09-RISW26/
  ```
- `git remote add origin git@github.com:saumil-sh/SC09-RISW26.git`, commit everything,
  push `main`.
- Publish with `quarto publish gh-pages` run **locally** (requires local git push access
  to the repo — no GitHub Actions, no workflow-permissions setting, no manual Pages
  source config: the command creates/pushes the `gh-pages` branch itself and GitHub Pages
  autodetects it). Re-run this command locally after every content change that should go
  live; there is no auto-deploy on push to `main`.
- Confirmed live: `https://saumil-sh.github.io/SC09-RISW26/` returns HTTP 200 and serves
  the deck.

### 11. `resolve-placeholders` — Fill in the public URLs
Determined values, applied everywhere they appear (`<PUBLIC_REPO_URL>` ×5, `<PUBLIC_COURSE_ZIP_URL>`
×4, `risw2026.Rproj` ×3 across `_setup.qmd` and `_part1-overview.qmd`):
- `<PUBLIC_REPO_URL>` → `https://github.com/saumil-sh/SC09-RISW26`
- `<PUBLIC_COURSE_ZIP_URL>` →
  `https://github.com/saumil-sh/SC09-RISW26/archive/refs/heads/main.zip`
  (GitHub's codeload ZIP of `main`; stable, no release needed. **Caveat recorded:** the
  archive extracts to a top-level `SC09-RISW26-main/` folder, so setup instructions must
  say "open the extracted `SC09-RISW26-main` folder", not just "open the folder".)
- `risw2026.Rproj` → `SC09-RISW26.Rproj`
- Cross-document links become in-deck anchors: Part 1's `[setup.html](setup.html)` →
  `#setup`; Part 2's "Setup & troubleshooting: `setup.html`" → `#setup`; setup's trailing
  `[← Back to the workshop](part2-programming.html)` → `#part-2`. Give the corresponding
  part-divider slides in `index.qmd` explicit IDs (`## … {#setup}`,
  `## … {#part-2}`) so these targets are stable regardless of title edits.
- Delete setup's instructor-TODO trailer paragraph (`*Instructor TODOs before
  distribution: …*`) — the placeholders it tracks are resolved here.

### 12. `verify` — Verify
- **No CI exists to gate this — verification is local, done once, by the person publishing.**
  A full local `quarto render index.qmd` from a clean `renv::restore()` is the closest
  equivalent to "renders cleanly from a fresh session" available without CI.
- Behavioral diff against the standalone parts (per Task 5): render the three parts in
  `../risw-2026`, compare figures and printed numbers against the merged deck. Part 2's
  `read_chunk` blocks must be populated (not empty), Part 1's figures identical, math
  renders, References slide lists all 14 entries readably, no dead intra-deck links.
- `renv::status()` clean against the copied `renv.lock`.
- Confirm the live URL: `https://saumil-sh.github.io/SC09-RISW26/` serves the current
  deck after each `quarto publish gh-pages`.

---

## Notes and considerations

- **Publishing is manual and local, not CI-gated.** `quarto publish gh-pages` must be
  re-run by hand after every content change that should go live; nothing deploys
  automatically on push to `main`. This was a deliberate reversal after the CI publish
  workflow's first run failed on a permissions setting the acting session couldn't fix —
  local publish worked immediately, so it is now the only publish path, and the
  now-conflicting `.github/workflows/publish.yml` was deleted.
- **The build-time tradeoff** (rendering with real code execution, no freeze) is still
  accepted: whoever runs `quarto publish gh-pages` pays a full render with code execution
  each time. This buys a real render check and removes the freeze discipline entirely.
- **Content placeholders — resolved in Task 11** with determined values from the known
  remote.
- **`.Rprofile` repo pin.** Handled in Task 2. Precision note: PPM was already public —
  dropping the `__linux__/noble` segment is about **cross-platform binaries** (the Linux
  path serves no binaries to Windows/macOS attendees, forcing source builds), not
  publicity. It does not guarantee binaries for every package on every platform.
- **`data/p3-results.rds` is 1.7 MB.** Fine for git, worth knowing. Part 3 degrades
  gracefully via `file.exists()` if it is absent, so a missing file yields placeholder tables
  rather than an error — which means a broken data path fails quietly. Check the rendered
  output, not just the exit code.
- **Not copied:** `materials/` (proposal `.docx`, PDFs, planning notes), `CLAUDE.md`,
  `TODO.md`, `outline.md`. `TODO.md` has open items that will now live in `../risw-2026` only;
  worth deciding later whether this repo or that one is the source of truth for the content.

# Review & polish plan — do not execute yet

Scope: the five Quarto sources (`index.qmd`, `_setup.qmd`, `_part1-overview.qmd`,
`_part2-programming.qmd`, `_part3-example.qmd`) as one rendered deck.

## 1. Redundant slides: Setup recap in Part 1

- `_setup.qmd` §2 "Get the course project" (L36–68) covers clone / ZIP / `.Rproj` /
  `renv::restore()` / smoke test.
- `_part1-overview.qmd` L30–50 repeats exactly that (clone line, ZIP URL, `.Rproj`,
  `renv`, one-row check) as a "start this now" slide.
- Plan: cut the duplicated instructions from Part 1 down to one line
  ("Already set up? Skip ahead. Otherwise start the download now — steps in Setup."),
  linking to `#setup`. The ZIP/clone/renv detail lives in `_setup.qmd` only.
- Also audit for other repeated blocks: the agenda table appears at
  `_part1-overview.qmd` L118, `_part2-programming.qmd` L33, `_part3-example.qmd` L76
  (intentional "you are here" markers — keep, but verify only the marker column differs).

## 2. Coherency / flow / storytelling

- Read the deck front-to-back in rendered order; for each part note: opening hook,
  transitions between parts (`_part1-overview.qmd` L1068 "Where Saumil picks up",
  `_part3-example.qmd` L126), and whether each part ends with a takeaway.
- Flag any slide that assumes content not yet shown, and any divider (`#setup`,
  `#part-2`) with no narrative bridge.
- Deliverable: a short list of reorder/rewrite suggestions, one line each.

## 3. Link hygiene

- `_setup.qmd` L50, L68, L119, L134 and `_part1-overview.qmd` L43–44 show raw GitHub
  URLs. Replace the ZIP URLs with linked text: `[project ZIP](…/archive/refs/heads/main.zip)`;
  keep `git clone` URL as code (it is copied, not clicked); keep the Posit Cloud
  clone-paste URL as code for the same reason.
- Sweep for other bare URLs in all five files and apply the same rule:
  prose → linked text, copy-paste targets → code.

## 4. Exact IDE steps for getting the course files

Add a panel-tabset (or one short slide) under Setup §2 with click-by-click steps:

- **RStudio:** File → New Project → Version Control → Git → paste repo URL →
  choose folder → Create Project.
- **Positron:** Welcome/Command Palette → "Git: Clone" → paste URL → open folder
  (verify exact Positron command names before writing).
- **VS Code:** Command Palette → "Git: Clone" → paste URL → open folder; note the
  R extension requirement.
- Keep the ZIP path as the no-Git alternative.

## 5. Screenshots

- Grep found no "screenshot" mentions in the `.qmd` sources — verify once more at
  execution time (also check `assets/` alt text and HTML comments); if any appear, remove.

## 6. Completeness check

- Verify every `{{< include >}}` target exists; every anchor linked to (`#setup`,
  `#hosted-fallback`, `#get-the-course-project`) resolves in the rendered HTML.
- Confirm `source("R/part-2/1-one-arm.R")`, `packageVersion("rxsim")` expectations,
  and all referenced files under `R/` and `data/` actually exist.
- `quarto render` clean, no warnings; references slide non-empty.

## 7. Dangling code / comments / name references

- `_part1-overview.qmd` L830: HTML comment "Note for Saumil (from Mitch)…" — resolve
  or delete before publishing.
- Sweep for `TODO|FIXME|XXX|ponytail:` and HTML comments across all sources.
- Decide policy on first-name mentions in agenda tables (L33/L76/L118) and
  hand-off slides (L1068, `_part3-example.qmd` L126): fine for live delivery,
  confirm they should survive in the published deck.
- Check `assets/` and `data/` for files no slide references.

## 8. Polish list

- After 1–7: one pass for slide-dense text walls, inconsistent slide titles/casing,
  emoji usage consistency, fragment/incremental pacing on data-heavy slides, and
  `.smaller`/`.scrollable` overuse. Output: ranked polish list, not edits.

## 9. Visual verification with headless Chromium

- Serve `_site/` locally (`quarto preview` or a static server), drive headless
  Chromium (CLI `--headless --screenshot`, or Playwright if finer control is needed)
  to capture **every slide**, and for `incremental: true` slides **every fragment
  step** (advance with ArrowRight/Space between captures).
- Review each capture for: overflow/clipping, broken MathML math, unrendered
  mermaid, dead links styling, table overflow, unreadable contrast on the dark
  title slide.
- Save captures under the session artifacts dir (not the repo); produce a
  per-slide issue list feeding step 8.

## Order of execution

1 → 3 → 4 → 5 → 7 (content edits), then 2 and 8 (read-through passes), then 6 and 9
(render + visual verification last, on the final text).

## 10. Font-size classes: `.small` / `.medium`, with measured overflow checks

Current state: 71 `{.smaller}` usages across all five sources; `.smaller` is the
revealjs built-in (~0.7×). No custom classes in `assets/css/custom.css`.

- **CSS:** add two classes to `assets/css/custom.css`: `.small` (same scale as
  revealjs `.smaller`) and `.medium` (between default and `.small`, e.g. 0.85×) —
  exact scale decided by measurement, not guessing.
- **Rename:** `{.smaller}` → `{.small}` everywhere (71 sites; mechanical sed-style
  rename, review the diff).
- **Promote:** slides that fit comfortably at a bigger size get `.medium` instead
  of `.small`. Candidates decided per-slide from screenshots, not by eyeballing
  source.
- **Verify everything, per slide:** render → headless-Chromium screenshot (every
  slide, every fragment step, per step 9) → script-measure x/y overflow of slide
  content against the 1280×720 box (scrollWidth/scrollHeight vs. client box via
  Playwright/Chromium eval, not visual judgment) → adjust class/scale → re-render
  → repeat until zero overflow on every capture.
- Done criteria: no slide uses built-in `.smaller`; every dense slide carries an
  explicit `.small` or `.medium`; overflow report is empty.
