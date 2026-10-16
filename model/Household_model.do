/*
Household model

Purpose: Define the household migration model of the EC428 essay and solve it
exactly. Each household compares every possible split of its members between
farming and non-farm work (essay equation 7) and keeps the split with the highest
income net of migration costs. No greedy rule is used.

Input: None. This file only defines programs and functions. The other do-files
load it with: run model/Household_model.do
Requirements: Stata 17 or later. Mata is part of Stata.

Defines:
- ec_load_households (Stata): passes the households in memory to the solver.
- ec_solve_runs() (Mata): solves every run in the dataset in memory. One run is
  one parameter vector and one shock; the totals are added as new variables.
- ec_measures (Stata): turns the totals into the outcomes reported in the essay.

Conventions used throughout the project:
- Parameters, in this order: A_A A_N beta gamma rho kappa eta (essay Section 3).
- A shock is (shock_type tau lambda tau_a tau_m). Shock types: 0 none,
  1 additive health, 2 multiplicative health, 3 lower migration cost,
  4 separate farm and market health (essay Section 4).
*/

version 17
* Drop any earlier copy of the functions so that this file can be loaded again.
clear mata


* ---------------------------------------------------------------------------
* Stata programs
* ---------------------------------------------------------------------------

capture program drop ec_load_households
program define ec_load_households
    * The data in memory have one row per person: hh_id member_id health land.
    * Reshape to one row per household and store the households for the solver.
    keep hh_id member_id health land
    quietly reshape wide health, i(hh_id) j(member_id)
    forvalues i = 1/6 {
        capture confirm variable health`i'
        if _rc quietly generate double health`i' = .
    }
    egen byte hh_size = rownonmiss(health1 health2 health3 health4 health5 health6)
    sort hh_id
    mata: ec_store_households()
end

capture program drop ec_measures
program define ec_measures
    * Outcomes reported in the essay, computed from the solver's totals. A ratio is
    * missing when its denominator is zero, for example APG when a sector is empty.
    quietly {
        generate double migration_rate = nonag_workers / workers
        generate double lp_a = ag_output / ag_workers
        generate double lp_n = nonag_output / nonag_workers
        generate double apg = lp_n / lp_a
        generate double initial_health_migrants = h0_sum_migrants / nonag_workers
        generate double initial_health_stayers = h0_sum_stayers / ag_workers
        generate double current_health_migrants = h_sum_migrants / nonag_workers
        generate double current_health_stayers = h_sum_stayers / ag_workers
        drop h0_sum_migrants h0_sum_stayers h_sum_migrants h_sum_stayers
    }
    label variable households "Households"
    label variable workers "Household members"
    label variable ag_workers "Farm workers"
    label variable nonag_workers "Migrants (non-farm workers)"
    label variable ag_output "Farm output, V_AA"
    label variable nonag_output "Non-farm output, V_AN"
    label variable migration_costs "Migration costs"
    label variable welfare "Household welfare (output net of migration costs)"
    label variable migration_rate "Migration rate"
    label variable lp_a "Farm output per worker, LP_A"
    label variable lp_n "Non-farm output per worker, LP_N"
    label variable apg "Agricultural productivity gap, LP_N/LP_A"
    label variable initial_health_migrants "Mean health of migrants, before the shock"
    label variable initial_health_stayers "Mean health of farm stayers, before the shock"
    label variable current_health_migrants "Mean health of migrants, after the shock"
    label variable current_health_stayers "Mean health of farm stayers, after the shock"
end


* ---------------------------------------------------------------------------
* Mata functions
* ---------------------------------------------------------------------------

mata:

// 1. Every possible allocation of n members, one per row: 1 = migrate, 0 = stay.
//    Rows are ordered by the number of migrants, so that a household keeps the
//    allocation with fewer migrants when two allocations are equally good.
real matrix ec_allocations(real scalar n)
{
    real matrix allocation
    real colvector code
    real scalar i

    code = (0::(2^n - 1))
    allocation = J(2^n, n, 0)
    for (i = 1; i <= n; i++) {
        allocation[., i] = mod(floor(code / 2^(i - 1)), 2)
    }
    return(allocation[order((rowsum(allocation), code), (1, 2)), .])
}

// 2. Health after a shock. Farm health enters farm output. Market health enters
//    non-farm output and the migration cost. Lambda scales the migration cost.
real matrix ec_farm_health(real matrix h, real rowvector shock)
{
    real matrix scaled

    if (shock[1] == 1) return(h :+ shock[2] :* (1 :- h))
    if (shock[1] == 2) {
        scaled = (1 + shock[2]) :* h
        return(scaled :* (scaled :< 1) :+ (scaled :>= 1))
    }
    if (shock[1] == 4) return(h :+ shock[4] :* (1 :- h))
    return(h)
}

real matrix ec_market_health(real matrix h, real rowvector shock)
{
    if (shock[1] == 4) return(h :+ shock[5] :* (1 :- h))
    return(ec_farm_health(h, shock))
}

real scalar ec_cost_factor(real rowvector shock)
{
    if (shock[1] == 3) return(shock[3])
    return(1)
}

// 3. Farm output of one household with stayers' health h (essay equation 3).
real scalar ec_farm_output(real matrix h, real scalar land, real rowvector par)
{
    if (cols(h) == 0) return(0)
    return(par[1] * land^(1 - par[4]) * sum(h :^ par[5])^(par[4] / par[5]))
}

// 4. Exact solver for one parameter vector and one shock.
//    H is households x 6 (missing after the last member); size and land are
//    household size and land. Households of the same size are solved together:
//    value[j, k] is household j's net income under allocation k.
//    Returns the totals named in ec_total_names() and puts each household's
//    chosen allocation (1 = migrate) into choice, a households x 6 matrix.
string rowvector ec_total_names()
{
    return(("households", "workers", "ag_workers", "nonag_workers",
        "ag_output", "nonag_output", "migration_costs", "welfare",
        "h0_sum_migrants", "h0_sum_stayers", "h_sum_migrants", "h_sum_stayers"))
}

real rowvector ec_solve(real matrix H, real colvector size, real colvector land,
    real rowvector par, real rowvector shock, real matrix choice)
{
    real matrix h, h_farm, h_market, M, farm, market, cost, value, chosen, take
    real matrix idx, better
    real colvector best, pick
    real rowvector totals
    real scalar n, k, lambda

    lambda = ec_cost_factor(shock)
    totals = J(1, 11, 0)
    choice = J(rows(H), 6, .)
    for (n = 1; n <= 6; n++) {
        idx = selectindex(size :== n)
        if (length(idx) == 0) continue
        h = H[idx, 1..n]
        h_farm = ec_farm_health(h, shock)
        h_market = ec_market_health(h, shock)
        M = ec_allocations(n)

        // Farm output, non-farm output and migration cost of every allocation.
        farm = (h_farm :^ par[5] * (1 :- M)') :^ (par[4] / par[5])
        farm = (par[1] :* land[idx] :^ (1 - par[4])) :* farm
        market = par[2] :* (h_market :^ par[3] * M')
        cost = (lambda * par[6]) :* (h_market :^ (-par[7]) * M')
        value = farm + market - cost

        // Keep the first allocation unless a later one is better by more than 1e-10.
        best = value[., 1]
        pick = J(length(idx), 1, 1)
        for (k = 2; k <= rows(M); k++) {
            better = selectindex(value[., k] :> best :+ 1e-10)
            if (length(better)) {
                best[better] = value[better, k]
                pick[better] = J(length(better), 1, k)
            }
        }
        chosen = M[pick, .]
        choice[idx, 1..n] = chosen

        // Add up over households; take marks each household's chosen allocation.
        // Order: workers, farm workers, migrants, farm output, non-farm output,
        // migration costs, welfare, then sums of health before the shock
        // (migrants, stayers) and after it (migrants, stayers).
        take = (J(length(idx), 1, (1..rows(M))) :== pick)
        totals = totals + (n * length(idx), sum(1 :- chosen), sum(chosen),
            sum(farm :* take), sum(market :* take), sum(cost :* take), sum(best),
            sum(h :* chosen), sum(h :* (1 :- chosen)),
            sum(h_market :* chosen), sum(h_farm :* (1 :- chosen)))
    }
    return((rows(H), totals))
}

real scalar ec_migration_rate(real rowvector totals)
{
    return(totals[4] / totals[2])
}

// 5. Links between the solver and the Stata data in memory.

// Store the households (one row per household) for the solver.
void ec_store_households()
{
    external real matrix ec_H
    external real colvector ec_id, ec_size, ec_land

    ec_id = st_data(., "hh_id")
    ec_size = st_data(., "hh_size")
    ec_land = st_data(., "land")
    ec_H = st_data(., "health1 health2 health3 health4 health5 health6")
}

// Solve every run in memory. Each observation holds a parameter vector
// (A_A A_N beta gamma rho kappa eta) and a shock (shock_type tau lambda tau_a tau_m).
// The totals are added as new variables.
void ec_solve_runs()
{
    external real matrix ec_H
    external real colvector ec_size, ec_land
    real matrix par, shock, totals, choice
    real scalar r

    par = st_data(., "A_A A_N beta gamma rho kappa eta")
    shock = st_data(., "shock_type tau lambda tau_a tau_m")
    totals = J(rows(par), 12, .)
    choice = J(0, 0, .)
    for (r = 1; r <= rows(par); r++) {
        totals[r, .] = ec_solve(ec_H, ec_size, ec_land, par[r, .], shock[r, .], choice)
        if (mod(r, 2000) == 0) {
            printf("{txt}  %g of %g runs solved\n", r, rows(par))
            displayflush()
        }
    }
    st_store(., st_addvar("double", ec_total_names()), totals)
}

// Add each member's choice (1 = migrate) as variables <stub>1-<stub>6 of the
// household data in memory. parameters and shock are lists of numbers.
void ec_store_choices(string scalar parameters, string scalar shock, string scalar stub)
{
    external real matrix ec_H
    external real colvector ec_id, ec_size, ec_land
    real matrix choice

    if (st_data(., "hh_id") != ec_id) {
        _error(3498, "the household data in memory are not the stored households")
    }
    choice = J(0, 0, .)
    (void) ec_solve(ec_H, ec_size, ec_land, strtoreal(tokens(parameters)),
        strtoreal(tokens(shock)), choice)
    st_store(., st_addvar("byte", stub :+ strofreal(1..6)), choice)
}

// 6. Seven checks of the model's theoretical properties (essay Table 1), on the
//    stored households. Returns one row per check: (diagnostic, passed).

// Farm output lost when the healthiest of three members leaves, minus the loss
// when the least healthy one leaves (h is ordered from most to least healthy).
real scalar ec_loss_gap(real rowvector h, real rowvector par, real scalar rho)
{
    real rowvector p
    real scalar full

    p = par
    p[5] = rho
    full = ec_farm_output(h, 1, p)
    return((full - ec_farm_output(h[(2, 3)], 1, p)) - (full - ec_farm_output(h[(1, 2)], 1, p)))
}

real matrix ec_theory_checks(string scalar parameters)
{
    external real matrix ec_H
    external real colvector ec_size, ec_land
    real matrix checks, choice0, choice
    real rowvector par, p, base, post, h
    real scalar k, diff

    par = strtoreal(tokens(parameters))
    checks = J(7, 2, .)
    choice0 = J(0, 0, .)
    choice = J(0, 0, .)
    base = ec_solve(ec_H, ec_size, ec_land, par, (0, 0, 1, 0, 0), choice0)

    // 1-3. Additive tau = 0, multiplicative tau = 0 and lambda = 1 change nothing.
    for (k = 1; k <= 3; k++) {
        post = ec_solve(ec_H, ec_size, ec_land, par, (k, 0, 1, 0, 0), choice)
        diff = max(abs(post - base))
        checks[k, .] = (diff, diff == 0 & choice == choice0)
    }

    // 4. A very high migration cost (kappa = 100) reduces migration.
    p = par
    p[6] = 100
    post = ec_solve(ec_H, ec_size, ec_land, p, (0, 0, 1, 0, 0), choice)
    checks[4, .] = (ec_migration_rate(post), ec_migration_rate(post) < ec_migration_rate(base))

    // 5. A very low migration cost and a high non-farm premium increase migration.
    p = par
    p[6] = 1e-4
    p[2] = 5
    post = ec_solve(ec_H, ec_size, ec_land, p, (0, 0, 1, 0, 0), choice)
    diff = ec_migration_rate(post) - ec_migration_rate(base)
    checks[5, .] = (diff, diff > 0)

    // 6. With rho = 1, farm labor is additive: output = A_A * (sum of health)^gamma
    //    when land = 1.
    h = (.9, .5, .2)
    p = par
    p[5] = 1
    diff = abs(ec_farm_output(h, 1, p) - p[1] * sum(h)^p[4])
    checks[6, .] = (diff, diff < 1e-10)

    // 7. Stronger complementarity (lower rho) makes losing the healthiest member
    //    more costly, relative to losing the least healthy one.
    diff = ec_loss_gap(h, par, .6) - ec_loss_gap(h, par, 1)
    checks[7, .] = (diff, diff > 0)
    return(checks)
}

end
