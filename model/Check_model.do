/*
Model checks

Purpose: Check that the solver in Household_model.do computes the model
correctly, before any simulation is run.
1. Benchmark: 100 runs on 40 test households, covering every shock family, must
   reproduce the results of the R version of this project.
2. Exhaustive check: in each of those runs, every household must choose the same
   allocation as a slow solver that values one allocation at a time.
3. Ties: a member who is exactly indifferent stays on the farm.

Input: data/benchmark/benchmark_households.csv (simulated test households) and
data/benchmark/benchmark_results.csv (run settings and the R results).
Requirements: Stata 17 or later.

Outputs: None. The results are printed to the log; any failure stops the run.
Run from the project root via run_all.do or do model/Check_model.do.
An optional first argument supplies the project root.
*/

version 17
clear all
set more off

args project_root
if `"`project_root'"' == "" local project_root "`c(pwd)'"

capture confirm file "`project_root'/run_all.do"
if _rc {
    display as error "Run from the project root: cd to the folder containing run_all.do."
    exit 601
}
local benchmark "`project_root'/data/benchmark"
run "`project_root'/model/Household_model.do"

mata:
// Slow solver for one household: value each allocation separately and keep the
// first one unless a later one is better by more than 1e-10.
real rowvector ec_slow_choice(real rowvector h, real scalar land,
    real rowvector par, real rowvector shock)
{
    real matrix M, h_farm, h_market
    real rowvector best_m
    real scalar k, farm, market, cost, value, best, lambda

    h_farm = ec_farm_health(h, shock)
    h_market = ec_market_health(h, shock)
    lambda = ec_cost_factor(shock)
    M = ec_allocations(cols(h))
    best = .
    best_m = J(1, cols(h), .)
    for (k = 1; k <= rows(M); k++) {
        farm = ec_farm_output(select(h_farm, M[k, .] :== 0), land, par)
        market = par[2] * sum(M[k, .] :* h_market :^ par[3])
        cost = lambda * par[6] * sum(M[k, .] :* h_market :^ (-par[7]))
        value = farm + market - cost
        if (k == 1 | value > best + 1e-10) {
            best = value
            best_m = M[k, .]
        }
    }
    return(best_m)
}

// Compare the batched solver with the slow solver for every run in memory and
// every stored household.
void ec_check_exhaustive()
{
    external real matrix ec_H
    external real colvector ec_size, ec_land
    real matrix par, shock, choice
    real scalar r, j, n, checked

    par = st_data(., "A_A A_N beta gamma rho kappa eta")
    shock = st_data(., "shock_type tau lambda tau_a tau_m")
    choice = J(0, 0, .)
    checked = 0
    for (r = 1; r <= rows(par); r++) {
        (void) ec_solve(ec_H, ec_size, ec_land, par[r, .], shock[r, .], choice)
        for (j = 1; j <= rows(ec_H); j++) {
            n = ec_size[j]
            if (ec_slow_choice(ec_H[j, 1..n], ec_land[j], par[r, .], shock[r, .]) != choice[j, 1..n]) {
                _error(3498, sprintf("run %g, household %g: the two solvers disagree", r, j))
            }
            checked++
        }
    }
    printf("{res}Exhaustive check: all %g household choices match the slow solver.\n", checked)
}

// With health 1, land 1, A_A = 1, A_N = 2 and kappa = 1, staying and migrating
// both give income 1. The member should stay.
void ec_check_tie()
{
    real matrix choice

    choice = J(0, 0, .)
    (void) ec_solve((1, ., ., ., ., .), 1, 1, (1, 2, 1, .55, .80, 1, 1.25),
        (0, 0, 1, 0, 0), choice)
    if (choice[1, 1] != 0) _error(3498, "an indifferent member should stay on the farm")
    printf("{res}Tie check: an indifferent member stays on the farm.\n")
}
end

* 1. Benchmark: solve the 100 runs and compare every outcome with the R results.
import delimited using "`benchmark'/benchmark_households.csv", clear varnames(1) asdouble
ec_load_households

import delimited using "`benchmark'/benchmark_results.csv", clear varnames(1) asdouble
assert _N == 100
rename (aa an) (A_A A_N)
local outcomes households workers ag_workers nonag_workers ag_output nonag_output ///
    migration_costs welfare migration_rate lp_a lp_n apg initial_health_migrants ///
    initial_health_stayers current_health_migrants current_health_stayers
foreach v of local outcomes {
    rename `v' r_`v'
}
mata: ec_solve_runs()
ec_measures
foreach v of local outcomes {
    assert missing(`v') == missing(r_`v')
    assert reldif(`v', r_`v') < 1e-9 if !missing(r_`v')
}
display as result "Benchmark: all 100 runs match the R results (relative difference below 1e-9)."

* 2. Exhaustive check on the same 100 runs and 40 households.
mata: ec_check_exhaustive()

* 3. Ties.
mata: ec_check_tie()

display as result "Done: all model checks passed."
