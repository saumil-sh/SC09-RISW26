# Trial Simulations in R

Slides for the RISW 2026 short course **SC09: Trial Simulations in R — A
Framework for Informing Modern Clinical Development** (Mitch Thomann & Saumil
Shah, September 16, 2026).

Live deck: <https://saumil-sh.github.io/SC09-RISW26/>

## For participants

Clone this repo (or download the
[project ZIP](https://github.com/saumil-sh/SC09-RISW26/archive/refs/heads/main.zip)),
open `SC09-RISW26.Rproj` in RStudio, then in the Console:

```r
install.packages("renv")
renv::restore()
```

The full walkthrough (including a no-install Posit Cloud fallback) is the
**Setup** section of the slides.

- `R/part-2/` — the answer-key scripts for the Part 2 build-along; your own
  work-in-progress copies are `R/work-1-one-arm.R` … `R/work-5-parallel.R`
- `R/part-3/` — the Part 3 example study; `7-exercise.R` is the hands-on
  prompt, `8-exercise-solution.R` the solution
- `data/p3-results.rds` — pre-run Part 3 results, so nothing heavy has to run
  in the room

## For maintainers

One revealjs deck: `index.qmd` holds the YAML header and `{{< include >}}`s
`_setup.qmd`, `_part1-overview.qmd`, `_part2-programming.qmd`,
`_part3-example.qmd`. `README.md` is not rendered — `_quarto.yml` renders only
`index.qmd`.

```bash
quarto render   # builds _site/index.html (executes all R chunks)
```

### Publishing

Publishing is **manual and local only** — there is no CI deploy. From the repo
root:

```bash
quarto publish gh-pages
```

This renders the deck, pushes `_site/` to the `gh-pages` branch (target
recorded in `_publish.yml`), and updates
<https://saumil-sh.github.io/SC09-RISW26/>. The first run may ask you to
confirm the GitHub remote and authorize `quarto`.

## License

[CC BY-SA 4.0](LICENSE)
