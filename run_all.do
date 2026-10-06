/*
Project runner

Purpose: Run data construction, descriptive analysis, and the selected optional
stages from one do-file.

Input: data/raw/Pay_by_Design_JOLE.dta.
Requirements: Stata 15+, estout; distplot and svmat2 (dm79) for replication; MATLAB R2021a+
with Optimization Toolbox when run_model = 1. kfwebs.ado is included.

Outputs: Generated datasets in data/derived/; tables, figures, and logs in output/.
Run: Set Stata's working directory to the repository root, edit the switches
below, and run: do run_all.do
*/

clear all
set more off

* Configuration: 1 = run, 0 = skip. Data construction and description always run.
local run_replication = 0
local run_model = 1
local matlab_exe "matlab"
* If MATLAB is not on PATH, set matlab_exe to the full path to its executable.

if !inlist(`run_replication', 0, 1) | !inlist(`run_model', 0, 1) {
    display as error "run_replication and run_model must each be 0 or 1."
    exit 198
}
local project_root "`c(pwd)'"

capture confirm file "`project_root'/description/Percentile_calculation.do"
if _rc {
    display as error "Set the working directory to the repository root, then run do run_all.do."
    exit 601
}
capture confirm file "`project_root'/data/raw/Pay_by_Design_JOLE.dta"
if _rc {
    display as error "Place Pay_by_Design_JOLE.dta in data/raw/ before running the pipeline."
    exit 601
}
foreach command in esttab estpost eststo estadd {
    capture which `command'
    if _rc {
        display as error "Missing estout components. Install with: ssc install estout"
        exit 499
    }
}
if `run_replication' {
    capture which distplot
    if _rc {
        display as error "Install distplot with: ssc install distplot"
        exit 499
    }
    
    capture which svmat2
       if _rc {
           display as error "Install svmat2 (used by kfwebs) with: net install dm79, from(http://www.stata.com/stb/stb56)"
           exit 499
       }
}

foreach folder in data data/derived output output/descriptive output/replication output/model output/logs {
    capture mkdir "`project_root'/`folder'"
}
capture log close pipeline
log using "`project_root'/output/logs/run_all.log", text replace name(pipeline)
display as text "Stata version: " c(stata_version)
display as text "Replication: `run_replication'; MATLAB: `run_model'."

local stages description/Percentile_calculation.do description/Describe_data.do
if `run_replication' {
    local stages `stages' replication/Pay_by_design_JOLE_edited.do
}
else {
    display as text "Replication skipped. Any existing replication outputs are from an earlier run."
}

foreach stage of local stages {
    display as result "Running `stage'..."
    capture noisily do "`project_root'/`stage'" "`project_root'"
    local stage_rc = _rc
    if `stage_rc' {
        display as error "Stopped in `stage' (return code `stage_rc'). See output/logs/run_all.log."
        capture log close replication
        log close pipeline
        exit `stage_rc'
    }
}

if `run_model' {
    * Remove a previous completion marker so a failed launch cannot look successful.
    capture confirm file "`project_root'/output/logs/model_complete.txt"
    if !_rc {
        erase "`project_root'/output/logs/model_complete.txt"
    }
    local launch_log "`project_root'/output/logs/model_launch.log"
    capture confirm file "`launch_log'"
    if !_rc {
        erase "`launch_log'"
    }
    display as result "Running MATLAB... Launch output: output/logs/model_launch.log"
    local wait_option ""
    if "`c(os)'" == "Windows" local wait_option "-wait"
    capture noisily shell "`matlab_exe'" `wait_option' -sd "`project_root'" -batch "run('model/paybydesign_stochastic.m')" > "`launch_log'" 2>&1
    capture confirm file "`project_root'/output/logs/model_complete.txt"
    if _rc {
        display as error "MATLAB did not complete. Launch output follows:"
        capture noisily type "`launch_log'"
        display as error "See output/logs/model_launch.log for this attempt's launch or MATLAB error."
        display as error "If MATLAB was not found, set matlab_exe to its full executable path."
        display as error "To test the model separately, run model/paybydesign_stochastic.m inside MATLAB."
        log close pipeline
        exit 499
    }
}
else {
    display as text "MATLAB skipped. Any existing model outputs are from an earlier run."
}

display as result "Done. Datasets: data/derived/. Results and logs: output/."
log close pipeline
