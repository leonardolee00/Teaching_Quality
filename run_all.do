/*
Project runner

Purpose: Check the household model, run the simulations, and make the tables
and figures of the EC428 essay from one do-file.

Input: Simulated households in data/simulated/ and test cases in data/benchmark/
(both included).
Requirements: Stata 17 or later. No user-written packages.

Outputs: Simulation datasets in data/derived/; tables, figures and the log in output/.
Run: Set Stata's working directory to the project root, edit the switches
below, and run: do run_all.do
*/

version 17
clear all
set more off

* Configuration: 1 = yes, 0 = no. Model checks, tables and figures always run.
local run_simulation = 1
local quick_test = 0
local new_households = 0
local seed = 123
* run_simulation = 0 remakes tables and figures from the saved data/derived files.
* quick_test = 1 uses 500 and 250 households and a 32-vector grid, for a fast trial run.
* new_households = 1 draws new households in Stata (with seed) instead of the saved ones.

foreach switch in run_simulation quick_test new_households {
    if !inlist(``switch'', 0, 1) {
        display as error "`switch' must be 0 or 1."
        exit 198
    }
}
local project_root "`c(pwd)'"

capture confirm file "`project_root'/model/Household_model.do"
if _rc {
    display as error "Set the working directory to the project root, then run do run_all.do."
    exit 601
}
foreach sample in baseline grid {
    capture confirm file "`project_root'/data/simulated/`sample'_households.csv"
    if _rc & !`new_households' {
        display as error "data/simulated/`sample'_households.csv is missing. Restore it, or set new_households = 1."
        exit 601
    }
}

foreach folder in data data/derived output output/tables output/figures output/logs {
    capture mkdir "`project_root'/`folder'"
}
capture log close pipeline
log using "`project_root'/output/logs/run_all.log", text replace name(pipeline)
display as text "Stata version: " c(stata_version) "; started " c(current_date) " " c(current_time)
display as text "Simulation: `run_simulation'; quick test: `quick_test'; new households: `new_households'."
local start = clock("`c(current_date)' `c(current_time)'", "DMYhms")

local stages model/Check_model.do
if `run_simulation' {
    local stages `stages' simulation/Run_simulations.do
}
else {
    display as text "Simulation skipped. Tables and figures use the existing data/derived files."
}
local stages `stages' analysis/Make_tables.do analysis/Make_figures.do

foreach stage of local stages {
    display as result _n "Running `stage'..."
    capture noisily do "`project_root'/`stage'" "`project_root'" ///
        `quick_test' `new_households' `seed'
    local stage_rc = _rc
    if `stage_rc' {
        display as error "Stopped in `stage' (return code `stage_rc'). See output/logs/run_all.log."
        log close pipeline
        exit `stage_rc'
    }
}

local minutes = (clock("`c(current_date)' `c(current_time)'", "DMYhms") - `start') / 60000
display as result _n "Done in " %4.1f `minutes' " minutes."
display as result "Datasets: data/derived/. Tables, figures and log: output/."
log close pipeline
