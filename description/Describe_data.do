/*
Descriptive analysis

Purpose: Summarize student and teacher characteristics by treatment group
and plot school-level teaching coverage against test scores.

Input: data/derived/teacher_with_incentive.dta from Percentile_calculation.do.

Requirements: Stata 15+ and estout (install: ssc install estout).

Outputs:
- Student summary statistics: summary_student.tex
- Teacher summary statistics: summary_teacher.tex
- Teaching coverage and test scores by item difficulty: coverage_and_scores.pdf

All outputs are saved in output/descriptive/.
Run from the repository root via run_all.do or do description/Describe_data.do.
An optional first argument supplies the project root.
*/

clear all
set more off

args project_root
if `"`project_root'"' == "" local project_root "`c(pwd)'"

capture confirm file "`project_root'/run_all.do"
if _rc {
    display as error "Run from the repository root: cd to the folder containing run_all.do."
    exit 601
}

local data_dir "`project_root'/data/derived"
local outdir "`project_root'/output/descriptive"
capture mkdir "`project_root'/output"
capture mkdir "`outdir'"

capture confirm file "`data_dir'/teacher_with_incentive.dta"
if _rc {
    display as error "Run description/Percentile_calculation.do first, or do run_all.do."
    exit 601
}

use "`data_dir'/teacher_with_incentive.dta", clear

* 1. Validate treatment assignment and define readable groups.
foreach v in control levels gains p4p {
    assert inlist(`v', 0, 1)
}
assert control + levels + gains + p4p == 1
* Retain students without teacher IDs; they have no observed endline score.
assert !missing(schid)
assert missing(z_final_score) if missing(teachid)
generate byte arm = control + 2*levels + 3*gains + 4*p4p
label define arm_label 1 "Control" 2 "Levels" 3 "Gains" 4 "P4P"
label values arm arm_label
bysort schid: assert arm == arm[1]

gen max_bonus = 7000*big + 3500*small

* 2. Summary tables: four treatment columns, separate observation units.
local student_vars z_final_score zmathbase2 zmathbase1 female stuage ses ///
    class_size teacher_basepay t_taught_any t_taught_easy t_taught_med ///
    t_taught_hard easyscore mediumscore hardscore
local teacher_vars sch_num_students sch_num_teachers max_bonus teacher_basepay ///
    final_measurement bonus

label variable z_final_score        "Final test score (standardized)"
label variable zmathbase2           "Baseline math score 2"
label variable zmathbase1           "Baseline math score 1"
label variable female               "Female student"
label variable stuage               "Student age"
label variable ses                  "Socioeconomic status index"
label variable class_size           "Class size"
label variable teacher_basepay      "Teacher base pay"
label variable t_taught_any         "Reported teaching coverage: any"
label variable t_taught_easy        "Reported teaching coverage: easy"
label variable t_taught_med         "Reported teaching coverage: medium"
label variable t_taught_hard        "Reported teaching coverage: hard"
label variable easyscore            "Test score: easy items"
label variable mediumscore          "Test score: medium items"
label variable hardscore            "Test score: hard items"
label variable sch_num_students     "Students in school"
label variable sch_num_teachers     "Teachers in school"
label variable max_bonus            "Maximum bonus"
label variable final_measurement    "Constructed performance measure"
label variable bonus                "Constructed bonus"

foreach unit in student teacher {
    preserve
    if "`unit'" == "teacher" {
        drop if missing(teachid)
        * Teacher variables should be constant within teacher; keep one row per teacher.
        foreach v in schid arm `teacher_vars' {
            bysort teachid: assert `v' == `v'[1]
        }
        bysort teachid: keep if _n == 1
        isid teachid
        local vars `teacher_vars'
        local note "One observation per teacher; school attributes describe teachers' schools."
    }
    else {
        local vars `student_vars'
        local note "Student-level observations; teacher and class attributes are student-weighted."
    }

    eststo clear
    forvalues g = 1/4 {
        quietly count if arm == `g'
        assert r(N) > 0
        quietly estpost summarize `vars' if arm == `g'
        eststo group`g'
    }
    esttab group1 group2 group3 group4 ///
        using "`outdir'/summary_`unit'.tex", replace ///
        cells("mean(fmt(2)) sd(par fmt(2)) count(fmt(0))") ///
        mtitles("Control" "Levels" "Gains" "P4P") ///
        collabels("Mean" "SD" "N") label nonumber noobs ///
        title("Summary statistics: `unit' level") ///
        addnotes("`note'" ///
        "N is the nonmissing count for each variable; SD is in parentheses." ///
        "Performance measures use scheme-specific definitions and scales.")
    restore
}
eststo clear

* 3. School-level teaching coverage and test scores, by treatment.
* Collapse to one row per school.
preserve
collapse (mean) breadth=t_taught_any score_easy=easyscore ///
    score_medium=mediumscore score_hard=hardscore, by(schid arm)
isid schid

local panels
foreach difficulty in easy medium hard {
    local title = proper("`difficulty'")
    * Show one legend for the figure, inside the first panel's empty top-left corner.
    local legend legend(off)
    if "`difficulty'" == "easy" {
        local legend legend(on order(1 "Control" 3 "Levels" 5 "Gains" 7 "P4P") ///
            ring(0) position(11) cols(1) size(small) region(lcolor(none)))
    }
    twoway ///
        (scatter score_`difficulty' breadth if arm == 1, ///
            mcolor(gs8%65) msymbol(O) msize(small)) ///
        (lfit score_`difficulty' breadth if arm == 1, lcolor(gs8)) ///
        (scatter score_`difficulty' breadth if arm == 2, ///
            mcolor(navy%65) msymbol(T) msize(small)) ///
        (lfit score_`difficulty' breadth if arm == 2, lcolor(navy)) ///
        (scatter score_`difficulty' breadth if arm == 3, ///
            mcolor(forest_green%65) msymbol(S) msize(small)) ///
        (lfit score_`difficulty' breadth if arm == 3, lcolor(forest_green)) ///
        (scatter score_`difficulty' breadth if arm == 4, ///
            mcolor(maroon%65) msymbol(D) msize(small)) ///
        (lfit score_`difficulty' breadth if arm == 4, lcolor(maroon)), ///
        title("`title' items") ///
        xtitle("Mean reported teaching coverage") ///
        ytitle("Mean test score") ///
        `legend' ///
        graphregion(color(white)) ///
        name(coverage_`difficulty', replace) nodraw
    local panels `panels' coverage_`difficulty'
}

graph combine `panels', cols(3) xcommon ycommon ///
    title("Teaching coverage and student test scores") ///
    note("Each point is one school; each line is that arm's linear fit.", size(small)) ///
    graphregion(color(white)) xsize(12) ysize(5) ///
    name(coverage_scores, replace)
graph export "`outdir'/coverage_and_scores.pdf", replace
restore

display as result "Done: two summary tables and one figure saved in `outdir'."
