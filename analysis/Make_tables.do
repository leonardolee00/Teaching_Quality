/*
Tables

Purpose: Make the simulation tables of the EC428 essay from the saved
simulation datasets, and compare headline results with the essay.

Input: the datasets in data/derived/, made by simulation/Run_simulations.do.
Requirements: Stata 17 or later.

Outputs, each as .csv and as a LaTeX tabular (.tex), in output/tables/:
- validation_checks: theory checks (essay Table 1)
- baseline: additive health shocks at the baseline calibration (essay Tables 3 and 5)
- region_summary: parameter regions by shock family (essay Tables 2 and 4)
- mean_changes: mean changes by shock family (essay Table 7)
- robustness: one parameter varied at a time (essay Table 6)
- essay_comparison: headline results next to the values reported in the essay

Run from the project root via run_all.do or do analysis/Make_tables.do.
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
local data "`project_root'/data/derived"
local outdir "`project_root'/output/tables"
capture mkdir "`project_root'/output"
capture mkdir "`outdir'"

foreach file in run_settings validation_checks baseline_results parameter_regions robustness {
    capture confirm file "`data'/`file'.dta"
    if _rc {
        display as error "data/derived/`file'.dta is missing. Run simulation/Run_simulations.do first, or do run_all.do."
        exit 601
    }
}
use "`data'/run_settings.dta", clear
local quick_test = quick_test[1]

capture program drop write_table
program define write_table
    * Save the listed variables as a CSV file and as a LaTeX tabular. Column
    * headings are the variable labels; numbers use each variable's display format.
    syntax varlist using/
    quietly export delimited `varlist' using "`using'.csv", replace datafmt
    tempname tex
    file open `tex' using "`using'.tex", write text replace
    local align "l"
    local columns : word count `varlist'
    forvalues i = 2/`columns' {
        local align "`align'r"
    }
    file write `tex' "\begin{tabular}{`align'}" _n "\hline" _n
    local line
    foreach v of local varlist {
        local label : variable label `v'
        if `"`label'"' == "" local label `v'
        local label = subinstr(`"`label'"', "_", "\_", .)
        if `"`line'"' != "" local line `"`line' & "'
        local line `"`line'`label'"'
    }
    file write `tex' `"`line' "' _char(92) _char(92) _n "\hline" _n
    forvalues i = 1/`=_N' {
        local line
        foreach v of local varlist {
            capture confirm string variable `v'
            if !_rc {
                local cell = `v'[`i']
            }
            else if missing(`v'[`i']) {
                local cell "--"
            }
            else {
                local fmt : format `v'
                local cell : display `fmt' `v'[`i']
            }
            local cell = strtrim(`"`cell'"')
            local cell = subinstr(`"`cell'"', "_", "\_", .)
            if `"`line'"' != "" local line `"`line' & "'
            local line `"`line'`cell'"'
        }
        file write `tex' `"`line' "' _char(92) _char(92) _n
    }
    file write `tex' "\hline" _n "\end{tabular}" _n
    file close `tex'
end


* 1. Theory checks (essay Table 1).
use "`data'/validation_checks.dta", clear
decode check_id, generate(check)
generate str3 result = cond(passed == 1, "Yes", "No")
format diagnostic %9.3f
label variable check "Check"
label variable diagnostic "Diagnostic"
label variable result "Passed"
write_table check diagnostic result using "`outdir'/validation_checks"


* 2. Baseline additive health shocks (essay Tables 3 and 5).
use "`data'/baseline_results.dta", clear
sort shock_id
format tau %4.2f
format migration_rate current_health_migrants current_health_stayers lp_a lp_n apg d_apg %6.3f
format ag_output nonag_output welfare %10.1f
label variable tau "tau"
label variable migration_rate "Migration rate"
label variable current_health_migrants "Mean health, migrants"
label variable current_health_stayers "Mean health, stayers"
label variable ag_output "Farm output"
label variable nonag_output "Non-farm output"
label variable welfare "Welfare"
label variable lp_a "LP_A"
label variable lp_n "LP_N"
label variable apg "APG"
label variable d_apg "Change in APG"
write_table tau migration_rate current_health_migrants current_health_stayers ///
    ag_output nonag_output welfare lp_a lp_n apg d_apg using "`outdir'/baseline"

* Values for the comparison with the essay: no shock, tau = .20 and tau = .40.
foreach s in 0 4 8 {
    summarize migration_rate if shock_id == `s', meanonly
    local migration`s' = r(mean)
    summarize apg if shock_id == `s', meanonly
    local apg`s' = r(mean)
}


* 3. Parameter regions by shock family (essay Tables 2, 4 and 7).
*    APG directions and the mean APG change use APG-valid runs only; all other
*    shares and means use every run.
use "`data'/parameter_regions.dta", clear
keep if shock_id > 0
generate byte widening = apg_direction == 1 if apg_valid
generate byte unchanged = apg_direction == 2 if apg_valid
generate byte narrowing = apg_direction == 3 if apg_valid
generate double valid_d_apg = d_apg if apg_valid
local stats (count) runs=shock_id (mean) core=core_mechanism ag_down=ag_output_decline ///
    (sum) valid=apg_valid (mean) widening unchanged narrowing mean_d_apg=valid_d_apg ///
    mean_d_ag_output=d_ag_output mean_d_migration=d_migration_rate mean_d_welfare=d_welfare
tempfile overall
preserve
collapse `stats'
generate byte shock_type = 0
save "`overall'"
restore
collapse `stats', by(shock_type)
append using "`overall'"
label define shock_family 0 "All shocks" 1 "Additive health" 2 "Multiplicative health" ///
    3 "Migration cost" 4 "Two health indices", replace
label values shock_type shock_family
sort shock_type
decode shock_type, generate(family)
generate long undefined = runs - valid

foreach s in 0 1 2 3 4 {
    summarize core if shock_type == `s', meanonly
    local core`s' = r(mean)
}
foreach v in runs ag_down valid widening {
    summarize `v' if shock_type == 0, meanonly
    local all_`v' = r(mean)
}

format runs valid undefined %9.0f
format core ag_down widening unchanged narrowing mean_d_apg mean_d_migration %6.3f
format mean_d_ag_output mean_d_welfare %9.1f
label variable family "Shock family"
label variable runs "Runs"
label variable core "Core"
label variable ag_down "Farm output down"
label variable valid "APG valid"
label variable widening "Widen"
label variable unchanged "Flat"
label variable narrowing "Narrow"
label variable undefined "Undefined"
label variable mean_d_apg "Mean change in APG"
label variable mean_d_ag_output "Mean change in farm output"
label variable mean_d_migration "Mean change in migration"
label variable mean_d_welfare "Mean change in welfare"
write_table family runs core ag_down valid widening unchanged narrowing undefined ///
    mean_d_apg using "`outdir'/region_summary"
write_table family mean_d_apg mean_d_ag_output mean_d_migration mean_d_welfare ///
    using "`outdir'/mean_changes"


* 4. Robustness: one parameter varied at a time, additive tau = .25 (essay Table 6).
use "`data'/robustness.dta", clear
keep if shock_id == 1
sort parameter_id
format value tau migration_rate d_migration_rate lp_a lp_n apg d_apg %6.3f
label variable varied "Parameter"
label variable value "Value"
label variable tau "tau"
label variable migration_rate "Migration rate"
label variable d_migration_rate "Change in migration"
label variable lp_a "LP_A"
label variable lp_n "LP_N"
label variable apg "APG"
label variable d_apg "Change in APG"
write_table varied value tau migration_rate d_migration_rate lp_a lp_n apg d_apg ///
    using "`outdir'/robustness"


* 5. Headline results next to the values reported in the essay (Tables 2-4).
*    The households are new draws, so small differences are expected.
tempfile comparison
tempname results
postfile `results' str40 statistic double(essay this_run) using "`comparison'"
post `results' ("Migration rate, no shock") (.508) (`migration0')
post `results' ("Migration rate, tau = .20") (.680) (`migration4')
post `results' ("Migration rate, tau = .40") (.845) (`migration8')
post `results' ("APG, no shock") (2.693) (`apg0')
post `results' ("APG, tau = .40") (1.756) (`apg8')
post `results' ("Parameter-shock runs") (23040) (`all_runs')
post `results' ("Core share, all shocks") (.951) (`core0')
post `results' ("Core share, additive health") (.993) (`core1')
post `results' ("Core share, multiplicative health") (1) (`core2')
post `results' ("Core share, migration cost") (.799) (`core3')
post `results' ("Core share, two health indices") (.992) (`core4')
post `results' ("Share with farm output down, all shocks") (.907) (`all_ag_down')
post `results' ("APG-valid runs") (21761) (`all_valid')
post `results' ("Share of APG widening, valid runs") (.173) (`all_widening')
postclose `results'
use "`comparison'", clear
generate double difference = this_run - essay
* Counts are shown as whole numbers, shares and levels with three decimals.
generate byte count = inlist(statistic, "Parameter-shock runs", "APG-valid runs")
foreach v in essay this_run difference {
    generate str12 `v'_text = strtrim(cond(count, string(`v', "%9.0f"), string(`v', "%9.3f")))
    drop `v'
    rename `v'_text `v'
}
label variable statistic "Statistic"
label variable essay "Essay"
label variable this_run "This run"
label variable difference "Difference"
write_table statistic essay this_run difference using "`outdir'/essay_comparison"
if `quick_test' {
    display as text "Quick test: the essay comparison uses a smaller grid and is not comparable."
}

display as result "Done: six tables saved in output/tables/."
