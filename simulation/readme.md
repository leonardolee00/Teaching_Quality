# Simulations

Runs the essay's simulation experiments (Section 4) with the exact household solver, and
saves the results as Stata datasets.

## Run

From the project folder:

```stata
do simulation/Run_simulations.do
```

This uses the default settings. To use the quick test or new households, run it through
[run_all.do](../run_all.do).

## Experiments

| Step | What it does | Essay |
| --- | --- | --- |
| 1. Households | Loads the saved households, or draws new ones in Stata | Section 3.1 |
| 2. Theory checks | Seven properties the model must satisfy, on the grid households | Table 1 |
| 3. Baseline | Additive health shocks τ = 0, 0.05, …, 0.40 at the baseline calibration, 10,000 households | Tables 3 and 5; Figures 1, 2, 3 and 5 |
| 4. Parameter regions | Every admissible parameter vector below, with no shock and with each of 24 shocks, 1,000 households | Tables 2, 4 and 7; Figures 4, 6, 7, 9 and 10 |
| 5. Robustness | κ, η or ρ varied one at a time, additive shock τ = 0.25, 10,000 households | Table 6 |

The parameter grid follows essay Table 8. Pairs with γ ≥ ρ are dropped, which leaves 960
parameter vectors:

| Parameter | Values |
| --- | --- |
| κ | 0.15, 0.25, 0.40, 0.60 |
| η | 0.75, 1.25, 1.75, 2.25 |
| ρ | 0.70, 0.80, 0.90, 1.00 |
| γ | 0.45, 0.55, 0.65, 0.75 |
| A_N / A_A | 1.40, 1.80, 2.40, 3.00 |

The 24 shocks are four additive and four multiplicative health shocks (τ = 0.10 to 0.40),
five migration-cost shocks (λ = 1.00 to 0.60) and eleven two-index shocks (τ_A = 0, 0.10,
0.20 with τ_M = 0.10 to 0.40 and τ_M ≥ τ_A). The quick test uses two values of each
parameter: 32 vectors with the same 24 shocks.

## How runs are compared

Every run is compared with the no-shock run of the same parameter vector.

- **Output and welfare.** Farm and non-farm output are gross output. Household welfare is
  output minus migration costs.
- **APG** is non-farm output per worker divided by farm output per worker. A change in APG
  counts only if both sectors have workers before and after the shock; otherwise it is left
  missing. It is *widening* above 0.01, *narrowing* below −0.01 and *about unchanged* in
  between.
- **Core mechanism.** Migration rises, welfare rises, and migrants are healthier than farm
  stayers, with health measured before the shock. If everyone migrates there are no stayers
  to compare; as in the essay's tables, such runs count toward the core mechanism.
- **Farm output decline.** Farm output falls.

## Households

By default the households come from `data/simulated/`: 10,000 households for the baseline
and robustness experiments and 1,000 for the grid. They were drawn once with the R version
of this project, so every run, on any machine, uses the same households.

With `new_households = 1` in run_all.do, Stata draws them instead, as in essay Section 3.1:
household size is uniform on 3 to 6; land is log-normal with log mean 0 and log standard
deviation 0.30; health is 0.10 + 0.90 × logistic(ξ + ε), where ξ ~ N(0, 0.60²) is shared
within the household and ε ~ N(0, 0.70²) is individual.

## Outputs

All in `data/derived/`:

| File | Contents |
| --- | --- |
| `households_baseline.dta`, `households_grid.dta` | The households used, one row per person |
| `validation_checks.dta` | The seven theory checks |
| `baseline_results.dta` | One row per baseline shock |
| `baseline_choices.dta` | Each person's choice with no shock and with τ = 0.40 |
| `parameter_regions.dta` | One row per parameter vector and shock |
| `robustness.dta` | One row per varied parameter and shock |
| `run_settings.dta` | The settings of this run |
