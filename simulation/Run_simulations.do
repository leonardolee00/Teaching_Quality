/*
Simulations

Purpose: Run the simulation experiments of the EC428 essay (Section 4) with the
exact household solver.
1. Households: the saved simulated households, or new draws made in Stata.
2. Theory checks: seven properties of the model (essay Table 1).
3. Baseline: additive health shocks tau = 0, .05, ..., .40 at the baseline
   calibration (essay Tables 3 and 5; Figures 1, 2, 3 and 5).
4. Parameter regions: every admissible parameter vector of essay Table 8 with
   each of the 24 shocks (essay Tables 2, 4 and 7; Figures 4, 6, 7, 9 and 10).
5. Robustness: kappa, eta or rho varied one at a time (essay Table 6).

Input: data/simulated/baseline_households.csv and grid_households.csv
(not used when new households are drawn).
Requirements: Stata 17 or later.

Outputs, all in data/derived/:
- households_baseline.dta, households_grid.dta: the households used
- validation_checks.dta: theory checks
- baseline_results.dta, baseline_choices.dta: baseline experiment
- parameter_regions.dta: every parameter-shock run
- robustness.dta: robustness runs
- run_settings.dta: the settings of this run

Run from the project root via run_all.do or do simulation/Run_simulations.do.
Optional arguments: project root, quick test (0/1), new households (0/1), seed.
*/

version 17
clear all
set more off

args project_root quick_test new_households seed
if `"`project_root'"' == "" local project_root "`c(pwd)'"
if "`quick_test'" == "" local quick_test = 0
if "`new_households'" == "" local new_households = 0
if "`seed'" == "" local seed = 123

capture confirm file "`project_root'/run_all.do"
if _rc {
    display as error "Run from the project root: cd to the folder containing run_all.do."
    exit 601
}
local data "`project_root'/data/derived"
capture mkdir "`project_root'/data"
capture mkdir "`data'"
run "`project_root'/model/Household_model.do"

* Baseline calibration (essay Section 4), in the order A_A A_N beta gamma rho kappa eta.
local calibration 1 1.80 1 .55 .80 .25 1.25

capture program drop add_calibration
program define add_calibration
    * Add the baseline calibration to every observation as variables A_A-eta.
    args A_A A_N beta gamma rho kappa eta
    foreach p in A_A A_N beta gamma rho kappa eta {
        generate double `p' = ``p''
    }
end

capture program drop compare_with_no_shock
program define compare_with_no_shock
    * Compare each run with the no-shock run (shock_id 0) of the same parameter
    * vector, and classify it as in essay Section 4 and Table 2.
    sort parameter_id shock_id
    by parameter_id: assert shock_id[1] == 0 & shock_type[1] == 0
    foreach v in migration_rate ag_output nonag_output welfare lp_a lp_n apg {
        by parameter_id: generate double d_`v' = `v' - `v'[1]
    }
    * APG changes count only if both sectors are active before and after the shock.
    by parameter_id: generate byte apg_valid = ag_workers > 0 & nonag_workers > 0 & ///
        ag_workers[1] > 0 & nonag_workers[1] > 0 & !missing(d_apg)
    generate byte apg_direction = cond(d_apg > .01, 1, cond(d_apg < -.01, 3, 2)) if apg_valid
    * Core mechanism: migration and welfare rise, and migrants are healthier than
    * farm stayers (health before the shock). When no one is left on the farm the
    * health comparison is undefined; as in the essay's tables, the run counts.
    generate byte selected = initial_health_migrants > initial_health_stayers + 1e-10 ///
        if nonag_workers > 0 & ag_workers > 0
    generate byte core_mechanism = d_migration_rate > 1e-10 & d_welfare > 1e-10 & ///
        (selected == 1 | ag_workers == 0)
    generate byte ag_output_decline = d_ag_output < -1e-10
    drop selected
    label define direction 1 "Widening" 2 "About unchanged" 3 "Narrowing", replace
    label values apg_direction direction
    label variable apg_valid "Both sectors active before and after the shock"
    label variable apg_direction "Change in APG: above .01, within .01, below -.01"
    label variable core_mechanism "Migration and welfare rise; migrants positively selected"
    label variable ag_output_decline "Farm output falls"
end

capture program drop label_runs
program define label_runs
    label variable parameter_id "Parameter vector"
    label variable shock_id "Shock"
    label variable shock_type "Shock family"
    label variable tau "Health shock, tau"
    label variable lambda "Migration-cost multiplier, lambda"
    label variable tau_a "Farm health shock, tau_A"
    label variable tau_m "Market health shock, tau_M"
    label define shock_family 0 "No shock" 1 "Additive health" 2 "Multiplicative health" ///
        3 "Migration cost" 4 "Two health indices", replace
    label values shock_type shock_family
end


* 1. Households: one row per person (hh_id member_id health land).
foreach sample in baseline grid {
    if `new_households' {
        * Draws as in essay Section 3.1: size uniform on 3-6; land log-normal with
        * log mean 0 and log SD .30; health = .10 + .90 * logistic(xi + e), where
        * xi ~ N(0, .60^2) is shared within the household and e ~ N(0, .70^2).
        local households = cond("`sample'" == "baseline", 10000, 1000)
        clear
        set seed `seed'
        quietly set obs `households'
        generate long hh_id = _n
        generate byte hh_size = 3 + floor(4 * runiform())
        generate double land = exp(.30 * rnormal())
        generate double xi = .60 * rnormal()
        quietly expand hh_size
        bysort hh_id: generate byte member_id = _n
        generate double health = .10 + .90 * invlogit(xi + .70 * rnormal())
        keep hh_id member_id health land
    }
    else {
        import delimited using "`project_root'/data/simulated/`sample'_households.csv", ///
            clear varnames(1) asdouble
    }
    if `quick_test' {
        quietly keep if hh_id <= cond("`sample'" == "baseline", 500, 250)
    }

    sort hh_id member_id
    isid hh_id member_id
    assert !missing(health, land)
    assert health > 0 & health <= 1 & land > 0
    by hh_id: assert member_id == _n
    by hh_id: assert land == land[1]
    by hh_id: assert _N <= 6
    label variable hh_id "Household"
    label variable member_id "Member"
    label variable health "Health before any shock"
    label variable land "Household land"
    quietly count if member_id == 1
    display as text "`sample' households: " r(N) " households, " _N " members."
    save "`data'/households_`sample'.dta", replace
}


* 2. Theory checks (essay Table 1), on the grid households.
use "`data'/households_grid.dta", clear
ec_load_households
clear
quietly set obs 7
mata: st_store(., st_addvar("double", ("diagnostic", "passed")), ec_theory_checks("`calibration'"))
generate byte check_id = _n
label define check ///
    1 "Additive tau = 0 reproduces the baseline" ///
    2 "Multiplicative tau = 0 reproduces the baseline" ///
    3 "Migration-cost lambda = 1 reproduces the baseline" ///
    4 "High kappa reduces migration" ///
    5 "Low kappa and high A_N/A_A increase migration" ///
    6 "rho = 1 gives additive farm labor" ///
    7 "Lower rho makes losing a healthy member more costly", replace
label values check_id check
order check_id
list, noobs clean
assert passed == 1
save "`data'/validation_checks.dta", replace


* 3. Baseline experiment: additive health shocks at the baseline calibration.
use "`data'/households_baseline.dta", clear
ec_load_households

* Each member's choice with no shock and with tau = .40 (essay Figure 1).
mata: ec_store_choices("`calibration'", "0 0 1 0 0", "before")
mata: ec_store_choices("`calibration'", "1 .40 1 0 0", "after")
quietly reshape long health before after, i(hh_id) j(member_id)
quietly drop if missing(health)
rename (before after) (migrate_before migrate_after)
keep hh_id member_id health land migrate_before migrate_after
label variable member_id "Member"
label variable health "Health before the shock"
label variable migrate_before "Migrates, no shock"
label variable migrate_after "Migrates, additive shock tau = .40"
save "`data'/baseline_choices.dta", replace

* Runs: shock 0 is no shock; shocks 1-8 are tau = .05, .10, ..., .40.
clear
quietly set obs 9
generate long parameter_id = 1
generate byte shock_id = _n - 1
generate byte shock_type = cond(shock_id == 0, 0, 1)
generate double tau = shock_id / 20
generate double lambda = 1
generate double tau_a = 0
generate double tau_m = 0
add_calibration `calibration'
mata: ec_solve_runs()
ec_measures
compare_with_no_shock
label_runs
save "`data'/baseline_results.dta", replace


* 4. Parameter regions (essay Table 8): every admissible parameter vector, with
*    no shock and with each of the 24 shocks, on the grid households.
if `quick_test' {
    local A_N_values   1.40 2.40
    local gamma_values .45 .65
    local rho_values   .80 1
    local eta_values   .75 1.75
    local kappa_values .15 .40
}
else {
    local A_N_values   1.40 1.80 2.40 3.00
    local gamma_values .45 .55 .65 .75
    local rho_values   .70 .80 .90 1
    local eta_values   .75 1.25 1.75 2.25
    local kappa_values .15 .25 .40 .60
}

tempfile parameters shocks
tempname grid
postfile `grid' long parameter_id double(A_N gamma rho eta kappa) using "`parameters'"
local id = 0
foreach A_N of local A_N_values {
    foreach gamma of local gamma_values {
        foreach rho of local rho_values {
            * The essay requires 0 < gamma < rho <= 1.
            if `gamma' >= `rho' continue
            foreach eta of local eta_values {
                foreach kappa of local kappa_values {
                    local ++id
                    post `grid' (`id') (`A_N') (`gamma') (`rho') (`eta') (`kappa')
                }
            }
        }
    }
}
postclose `grid'

* Shock intensity: tau for health shocks, 1 - lambda for the cost shock and
* tau_M for the two-index shock.
postfile `grid' byte(shock_id shock_type) double(tau lambda tau_a tau_m intensity) ///
    using "`shocks'"
post `grid' (0) (0) (0) (1) (0) (0) (0)
local id = 0
foreach type in 1 2 {
    foreach tau in .10 .20 .30 .40 {
        local ++id
        post `grid' (`id') (`type') (`tau') (1) (0) (0) (`tau')
    }
}
foreach lambda in 1 .90 .80 .70 .60 {
    local ++id
    post `grid' (`id') (3) (0) (`lambda') (0) (0) (1 - `lambda')
}
foreach tau_a in 0 .10 .20 {
    foreach tau_m in .10 .20 .30 .40 {
        if `tau_m' < `tau_a' continue
        local ++id
        post `grid' (`id') (4) (0) (1) (`tau_a') (`tau_m') (`tau_m')
    }
}
postclose `grid'

use "`data'/households_grid.dta", clear
ec_load_households
use "`parameters'", clear
quietly cross using "`shocks'"
generate double A_A = 1
generate double beta = 1
assert _N == cond(`quick_test', 32, 960) * 25
sort parameter_id shock_id
display as text "Parameter regions: solving " _N " runs..."
mata: ec_solve_runs()
ec_measures
compare_with_no_shock
label_runs
label variable intensity "Shock intensity"
save "`data'/parameter_regions.dta", replace


* 5. Robustness: vary one parameter at a time, additive shock tau = .25, on the
*    baseline households (essay Table 6).
use "`data'/households_baseline.dta", clear
ec_load_households
clear
input long parameter_id str5 varied double value
 1 kappa  .10
 2 kappa  .25
 3 kappa  .50
 4 kappa 1
 5 eta    .75
 6 eta   1.25
 7 eta   1.75
 8 rho    .60
 9 rho    .80
10 rho   1
end
add_calibration `calibration'
foreach p in kappa eta rho {
    quietly replace `p' = value if varied == "`p'"
}
quietly expand 2
bysort parameter_id: generate byte shock_id = _n - 1
generate byte shock_type = shock_id
generate double tau = .25 * shock_id
generate double lambda = 1
generate double tau_a = 0
generate double tau_m = 0
mata: ec_solve_runs()
ec_measures
compare_with_no_shock
label_runs
label variable varied "Parameter varied"
label variable value "Value of the varied parameter"
save "`data'/robustness.dta", replace


* 6. Settings of this run, used by the tables and figures.
clear
quietly set obs 1
generate byte quick_test = `quick_test'
generate byte new_households = `new_households'
generate long seed = `seed'
foreach sample in baseline grid {
    preserve
    use "`data'/households_`sample'.dta", clear
    quietly count if member_id == 1
    local `sample'_households = r(N)
    restore
    generate long `sample'_households = ``sample'_households'
}
generate str20 date = "`c(current_date)'"
save "`data'/run_settings.dta", replace

display as result "Done: simulation datasets saved in data/derived/."
