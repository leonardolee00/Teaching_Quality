# Tables and Figures

Makes the essay's simulation tables and figures from the datasets in `data/derived/`.

## Run

After the simulations, from the project folder:

```stata
do analysis/Make_tables.do
do analysis/Make_figures.do
```

## Tables

Each table is saved in `output/tables/` as a CSV file and as a LaTeX tabular (`.tex`) that
can be included in a document with `\input{}`.

| File | Contents | Essay |
| --- | --- | --- |
| `validation_checks` | Seven checks of the model's theoretical properties | Table 1 |
| `baseline` | Migration, health, output, welfare and APG under additive shocks | Tables 3 and 5 |
| `region_summary` | Share of runs with the core mechanism, falling farm output and each APG direction, by shock family | Tables 2 and 4 |
| `mean_changes` | Mean changes in APG, farm output, migration and welfare, by shock family | Table 7 |
| `robustness` | Baseline results with κ, η or ρ varied one at a time | Table 6 |
| `essay_comparison` | Headline results of this run next to the values in the essay | — |

APG directions and the mean change in APG use only runs where APG is defined before and
after the shock. All other shares and means use every run.

## Figures

Saved as PDF files in `output/figures/`.

| File | Contents | Essay |
| --- | --- | --- |
| `migration_by_health` | Migration rate by health, before and after the shock | Figure 1 |
| `health_by_allocation` | Mean health of migrants and farm stayers | Figure 2 |
| `output_and_welfare` | Farm output, non-farm output and welfare | Figure 3 |
| `apg_by_shock` | Mean change in APG, by shock family and intensity | Figure 4 |
| `productivity_response` | Change in output per worker in each sector | Figure 5 |
| `migration_by_shock` | Mean change in migration, by shock family and intensity | Figure 6 |
| `selection_by_shock` | Health gap between migrants and farm stayers | Figure 7 |
| `apg_heatmap_costs` | Mean change in APG by κ and η | Figure 9 |
| `apg_heatmap_labor` | Mean change in APG by ρ and γ | Figure 10 |

The first five use the baseline experiment; the others use the parameter-region grid.
Shock intensity is τ for the health shocks, 1 − λ for the migration-cost shock and τ_M for
the two-index shock. The essay's Figure 8 (migration by health across the grid) is not
reproduced.

## Comparing with the essay

The essay's original households were not saved, so this run uses new draws from the same
distributions, and small differences from the essay are expected. In the quick test the
grid is smaller, so its comparison with the essay is not meaningful.
