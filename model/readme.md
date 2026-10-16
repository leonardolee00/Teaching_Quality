# Household Model

Solves each household's migration choice exactly (essay Section 3, equation 7), and checks
the solver before any simulation is run.

## The model in brief

Each household has three to six members and a plot of land. Each member has a health level
between 0.1 and 1, and either farms or migrates to non-farm work. The household chooses the
split that gives the highest income net of migration costs:

| Part | Formula |
| --- | --- |
| Farm output | A_A × land^(1−γ) × (sum of stayers' health^ρ)^(γ/ρ) |
| Earnings of one migrant | A_N × health^β |
| Cost of migrating | λ × κ × health^(−η) |

A household of six has 64 possible splits, and the solver values every one of them; no
greedy rule is used. Households of the same size are solved together with Mata matrices.
When two splits are equally good (within 1e-10), the household keeps the one with fewer
migrants.

Baseline calibration (essay Section 4): A_A = 1, A_N = 1.80, β = 1, γ = 0.55, ρ = 0.80,
κ = 0.25, η = 1.25. The essay requires 0 < γ < ρ ≤ 1.

## Shocks

| Shock family | Farm health | Market health (non-farm earnings and migration cost) | Cost multiplier λ |
| --- | --- | --- | --- |
| Additive health | h + τ(1 − h) | h + τ(1 − h) | 1 |
| Multiplicative health | min((1 + τ)h, 1) | min((1 + τ)h, 1) | 1 |
| Migration cost | h | h | λ < 1 |
| Two health indices | h + τ_A(1 − h) | h + τ_M(1 − h), with τ_M ≥ τ_A | 1 |

## Run

[Household_model.do](Household_model.do) only defines the solver; the other do-files load
it. To check the solver on its own, run from the project folder:

```stata
do model/Check_model.do
```

[Check_model.do](Check_model.do) runs three checks and stops at the first failure:

1. **Benchmark.** 100 runs on 40 simulated test households, covering every shock family,
   must reproduce the results of the R version of this project to a relative difference
   below 1e-9.
2. **Exhaustive check.** In each of those runs, every household's choice must match a slow
   solver that values one split at a time.
3. **Ties.** A member who is exactly indifferent between farming and migrating stays.

The test households and the R results are in `data/benchmark/`. R is not needed.

## How the code is organized

| In Household_model.do | What it does |
| --- | --- |
| `ec_load_households` (Stata) | Passes the households in memory to the solver |
| `ec_solve_runs()` (Mata) | Solves every run in the dataset in memory; one row is one parameter vector and one shock |
| `ec_measures` (Stata) | Turns the solver's totals into the outcomes in the essay, such as the migration rate and APG |
| `ec_store_choices()` (Mata) | Records each member's choice, for the figure on migration by health |
| `ec_theory_checks()` (Mata) | The seven checks of essay Table 1, run in the simulation stage |

Parameters are always passed in the order A_A, A_N, β, γ, ρ, κ, η, and a shock as
(type, τ, λ, τ_A, τ_M).
