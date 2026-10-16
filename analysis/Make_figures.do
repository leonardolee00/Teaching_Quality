/*
Figures

Purpose: Make the simulation figures of the EC428 essay from the saved
simulation datasets.

Input: the datasets in data/derived/, made by simulation/Run_simulations.do.
Requirements: Stata 17 or later.

Outputs, as PDF files in output/figures/ (essay figure in parentheses):
- migration_by_health: migration rate by health, before and after the shock (Figure 1)
- health_by_allocation: mean health of migrants and farm stayers (Figure 2)
- output_and_welfare: farm output, non-farm output and welfare (Figure 3)
- apg_by_shock: mean change in APG by shock family (Figure 4)
- productivity_response: change in output per worker in each sector (Figure 5)
- migration_by_shock: mean change in migration by shock family (Figure 6)
- selection_by_shock: health gap between migrants and farm stayers (Figure 7)
- apg_heatmap_costs: mean change in APG by kappa and eta (Figure 9)
- apg_heatmap_labor: mean change in APG by rho and gamma (Figure 10)

Run from the project root via run_all.do or do analysis/Make_figures.do.
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
local outdir "`project_root'/output/figures"
capture mkdir "`project_root'/output"
capture mkdir "`outdir'"

foreach file in run_settings baseline_results baseline_choices parameter_regions {
    capture confirm file "`data'/`file'.dta"
    if _rc {
        display as error "data/derived/`file'.dta is missing. Run simulation/Run_simulations.do first, or do run_all.do."
        exit 601
    }
}
use "`data'/run_settings.dta", clear
local baseline_households : display %9.0fc baseline_households[1]
local baseline_households = strtrim("`baseline_households'")
set scheme s1color

capture program drop apg_heatmap
program define apg_heatmap
    * Heat map of the mean change in APG by two parameters. Each cell averages
    * over the APG-valid runs in memory: all other parameters and all shocks.
    syntax varlist(min=2 max=2), Title(string) XTitle(string) YTitle(string) ///
        Note(string) File(string)
    tokenize `varlist'
    local xvar `1'
    local yvar `2'
    collapse (mean) d_apg, by(`xvar' `yvar')
    egen int column = group(`xvar')
    egen int row = group(`yvar')

    * Axis labels show the parameter values.
    foreach axis in column row {
        local var = cond("`axis'" == "column", "`xvar'", "`yvar'")
        local labels_`axis'
        quietly levelsof `axis', local(levels)
        foreach l of local levels {
            quietly summarize `var' if `axis' == `l', meanonly
            local text = string(r(mean), "%4.2f")
            local labels_`axis' `"`labels_`axis'' `l' "`text'""'
        }
    }

    * Nine color classes centered at zero: blue = APG narrows, red = APG widens.
    quietly summarize d_apg, meanonly
    local scale = max(abs(r(min)), abs(r(max)), 1e-6)
    generate byte shade = min(9, 1 + floor(9 * (d_apg + `scale') / (2 * `scale')))
    generate double lower = row - .5
    generate double upper = row + .5
    generate str8 cell = string(d_apg, "%5.2f")
    local colors navy navy*.7 navy*.45 navy*.25 gs15 cranberry*.25 cranberry*.45 cranberry*.7 cranberry
    local plots
    forvalues s = 1/9 {
        quietly count if shade == `s'
        if r(N) > 0 {
            local color : word `s' of `colors'
            local plots `plots' (rbar lower upper column if shade == `s', ///
                barwidth(1) fcolor(`color') fintensity(100) lcolor(white) lwidth(medthick))
        }
    }
    * Labels: white on dark cells, black on light ones.
    quietly count if inlist(shade, 1, 2, 8, 9)
    if r(N) > 0 {
        local plots `plots' (scatter row column if inlist(shade, 1, 2, 8, 9), ///
            msymbol(none) mlabel(cell) mlabposition(0) mlabcolor(white))
    }
    quietly count if inrange(shade, 3, 7)
    if r(N) > 0 {
        local plots `plots' (scatter row column if inrange(shade, 3, 7), ///
            msymbol(none) mlabel(cell) mlabposition(0) mlabcolor(black))
    }
    quietly summarize column, meanonly
    local xmax = r(max) + .5
    quietly summarize row, meanonly
    local ymax = r(max) + .5
    twoway `plots', ///
        title("`title'") xtitle("`xtitle'") ytitle("`ytitle'") ///
        xlabel(`labels_column', noticks nogrid) ylabel(`labels_row', noticks nogrid angle(0)) ///
        xscale(range(.5 `xmax')) yscale(range(.5 `ymax')) legend(off) ///
        note("Mean change in APG over APG-valid runs. Blue: APG narrows; red: APG widens." ///
            "`note'")
    graph export "`file'", replace
end


* 1. Migration rate by health, before and after the shock (essay Figure 1).
use "`data'/baseline_choices.dta", clear
generate byte bin = min(floor(health * 10), 9)
collapse (mean) mean_health=health before=migrate_before after=migrate_after, by(bin)
sort mean_health
twoway (connected before mean_health, lcolor(navy) mcolor(navy) msymbol(O)) ///
    (connected after mean_health, lcolor(maroon) mcolor(maroon) msymbol(D)), ///
    title("Migration rate by health") ///
    xtitle("Mean health within bin, before the shock") ytitle("Migration rate") ///
    xlabel(.2(.2)1, format(%3.1f)) ///
    ylabel(0 "0%" .25 "25%" .5 "50%" .75 "75%" 1 "100%", angle(0)) ///
    legend(order(1 "No shock" 2 "Additive shock, {&tau} = 0.40") rows(1) position(6)) ///
    note("Health bins of width 0.1. Baseline calibration, `baseline_households' households.")
graph export "`outdir'/migration_by_health.pdf", replace


* 2. Mean health of migrants and farm stayers (essay Figure 2).
use "`data'/baseline_results.dta", clear
keep if inlist(shock_id, 0, 8)
generate byte after = shock_id == 8
keep after current_health_migrants current_health_stayers
rename (current_health_migrants current_health_stayers) (health1 health2)
quietly reshape long health, i(after) j(group)
label define group 1 "Migrants" 2 "Farm stayers"
label values group group
graph bar (asis) health, over(after) over(group) asyvars ///
    bar(1, color(navy)) bar(2, color(maroon)) ///
    title("Health of migrants and farm stayers") ///
    ytitle("Mean health") ylabel(0(.2)1, angle(0) format(%3.1f)) ///
    legend(order(1 "No shock" 2 "Additive shock, {&tau} = 0.40") rows(1) position(6)) ///
    note("Health after the shock. Households choose again who migrates after the shock.")
graph export "`outdir'/health_by_allocation.pdf", replace


* 3. Sectoral output and household welfare (essay Figure 3).
use "`data'/baseline_results.dta", clear
sort shock_id
foreach v in ag_output nonag_output welfare {
    generate double index_`v' = `v' / `v'[1]
}
twoway (connected index_ag_output tau, lcolor(navy) mcolor(navy) msymbol(O)) ///
    (connected index_nonag_output tau, lcolor(maroon) mcolor(maroon) msymbol(D)) ///
    (connected index_welfare tau, lcolor(forest_green) mcolor(forest_green) msymbol(S)), ///
    yline(1, lpattern(dash) lcolor(gs10)) ///
    title("Sectoral output and household welfare") ///
    xtitle("Additive health shock, {&tau}") ytitle("Index, no shock = 1") ///
    xlabel(0(.1).4, format(%3.1f)) ylabel(, angle(0) format(%3.1f)) ///
    legend(order(1 "Farm output" 2 "Non-farm output" 3 "Household welfare") ///
        rows(1) position(6) size(small)) ///
    note("Sectoral output is gross output; welfare also subtracts migration costs.")
graph export "`outdir'/output_and_welfare.pdf", replace


* 4. Output per worker in each sector (essay Figure 5, headline case).
twoway (connected d_lp_a tau, lcolor(navy) mcolor(navy) msymbol(O)) ///
    (connected d_lp_n tau, lcolor(maroon) mcolor(maroon) msymbol(D)), ///
    yline(0, lpattern(dash) lcolor(gs10)) ///
    title("Output per worker") ///
    xtitle("Additive health shock, {&tau}") ytitle("Change from no shock") ///
    xlabel(0(.1).4, format(%3.1f)) ylabel(, angle(0) format(%3.1f)) ///
    legend(order(1 "Farm, LP{sub:A}" 2 "Non-farm, LP{sub:N}") rows(1) position(6)) ///
    note("Farm output per worker can rise while total farm output falls.")
graph export "`outdir'/productivity_response.pdf", replace


* 5-7. Responses by shock family (essay Figures 4, 6 and 7).
foreach outcome in apg migration selection {
    use "`data'/parameter_regions.dta", clear
    keep if shock_id > 0
    if "`outcome'" == "apg" {
        keep if apg_valid
        generate double y = d_apg
        local title "Change in the productivity gap"
        local ytitle "Mean change in APG"
        local note "Means over runs with both sectors active before and after the shock."
        local file apg_by_shock
        local yformat %3.1f
    }
    else if "`outcome'" == "migration" {
        generate double y = d_migration_rate
        local title "Change in migration"
        local ytitle "Mean change in migration rate"
        local note "Means over all runs."
        local file migration_by_shock
        local yformat %3.1f
    }
    else {
        generate double y = initial_health_migrants - initial_health_stayers
        local title "Health selection of migrants"
        local ytitle "Mean health, migrants minus stayers"
        local note "Health before the shock. Runs with no migrants or no stayers are left out."
        local file selection_by_shock
        local yformat %5.3f
    }
    collapse (mean) y, by(shock_type intensity)
    sort shock_type intensity
    twoway (connected y intensity if shock_type == 1, lcolor(navy) mcolor(navy) msymbol(O)) ///
        (connected y intensity if shock_type == 2, lcolor(maroon) mcolor(maroon) msymbol(D)) ///
        (connected y intensity if shock_type == 3, lcolor(forest_green) mcolor(forest_green) msymbol(S)) ///
        (connected y intensity if shock_type == 4, lcolor(dkorange) mcolor(dkorange) msymbol(T)), ///
        yline(0, lpattern(dash) lcolor(gs10)) ///
        title("`title'") xtitle("Shock intensity") ytitle("`ytitle'") ///
        xlabel(0(.1).4, format(%3.1f)) ylabel(, angle(0) format(`yformat')) ///
        legend(order(1 "Additive health" 2 "Multiplicative health" 3 "Migration cost" ///
            4 "Two health indices") rows(2) position(6)) ///
        note("Intensity: {&tau} for health shocks, 1 - {&lambda} for the cost shock, {&tau}{sub:M} for two indices." ///
            "`note'")
    graph export "`outdir'/`file'.pdf", replace
}


* 8-9. Where does the productivity gap widen? (essay Figures 9 and 10)
use "`data'/parameter_regions.dta", clear
keep if shock_id > 0 & apg_valid
apg_heatmap kappa eta, title("Change in APG by migration-cost parameters") ///
    xtitle("Migration-cost level, {&kappa}") ytitle("Health elasticity of the cost, {&eta}") ///
    note("Each cell averages over the other parameters and all shocks.") ///
    file("`outdir'/apg_heatmap_costs.pdf")

use "`data'/parameter_regions.dta", clear
keep if shock_id > 0 & apg_valid
apg_heatmap rho gamma, title("Change in APG by farm-labor parameters") ///
    xtitle("Substitutability of farm labor, {&rho}") ytitle("Output elasticity of farm labor, {&gamma}") ///
    note("Each cell averages over the other parameters and all shocks. Blank cells: {&gamma} must be below {&rho}.") ///
    file("`outdir'/apg_heatmap_labor.pdf")

display as result "Done: nine figures saved in output/figures/."
