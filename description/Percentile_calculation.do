/*
Performance measures and implied bonuses

Purpose: Reconstruct school-level performance measures, tournament rankings, 
and bonuses under the original incentive design, then merge them into student-level data.

Input: data/raw/Pay_by_Design_JOLE.dta from the original replication package.

Outputs:
- Performance measures and teacher bonuses by group: *_teacher_bonus.dta
- Combined performance and bonus data: combined_teacher_data.dta
- Student records with incentive measures: teacher_with_incentive.dta
  and teacher_with_incentive.csv
- School counts by prefecture and treatment, excluding missing bonuses:
  Treat_dist_byschid_rea.xlsx

Datasets are saved in data/derived/; the Excel table in output/descriptive/.
Run from the repository root via run_all.do, or run this script before
description/Describe_data.do. An optional first argument supplies the project root.

Construction choices: Prefecture is inferred from the first digit of schid.
Gains use the supplied standardized scores. P4P comparison sets are exact
zmathbase2 matches pooled across prefectures and reward sizes. Student ties
receive average ranks; singleton sets retain the convention of percentile 50.
School ties retain track ranks (one plus the number of strictly lower measures).
These are reconstructed measures, not verified payment records.
*/


args project_root
if `"`project_root'"' == "" local project_root "`c(pwd)'"

capture confirm file "`project_root'/run_all.do"
if _rc {
    display as error "Run from the repository root: cd to the folder containing run_all.do."
    exit 601
}

local raw_dir "`project_root'/data/raw"
local data_dir "`project_root'/data/derived"
local outdir "`project_root'/output/descriptive"
foreach folder in data data/derived output output/descriptive {
    capture mkdir "`project_root'/`folder'"
}
set more off

use "`raw_dir'/Pay_by_Design_JOLE.dta",clear

*Levels group
preserve

* Step 0: Keep only level incentive teachers
keep if levels == 1
drop if missing(z_final_score)

* Step 1: Create prefecture
gen sch_group = .
replace sch_group = 1 if real(substr(string(schid),1,1)) == 1
replace sch_group = 2 if real(substr(string(schid),1,1)) == 2
assert inlist(sch_group, 1, 2)

* Step 2: Create tournament ID: (2 incentive sizes × 2 prefectures = 4 tournaments)
gen tournament_id = .
replace tournament_id = 1 if big == 1 & sch_group == 1
replace tournament_id = 2 if big == 1 & sch_group == 2
replace tournament_id = 3 if small == 1 & sch_group == 1
replace tournament_id = 4 if small == 1 & sch_group == 2
assert inlist(tournament_id, 1, 2, 3, 4)

* Step 3: Calculate teacher average final score
* One measure per school: where a school had several sixth-grade math teachers, they were ranked together (paper, fn. 10).

collapse (mean) final_measurement = z_final_score, by (schid sch_group tournament_id big small levels gains p4p) 

* Step 4: Rank teachers within each tournament
egen rank = rank(final_measurement), by(tournament_id) track
bysort tournament_id: gen N = _N
assert N > 1

* Step 5: Compute percentile rank (top = 99, bottom = 0)
gen percentile = 99 - 99 * (N - rank) / (N - 1)

* Reward = R_top - (99 - percentile) * b; R_top = 7000, b = 70 (large) and 3500, 35 (small).
* Step 6: Compute bonus by incentive size
gen bonus = .
replace bonus = 7000 - (99 - percentile) * 70 if big == 1
replace bonus = 3500 - (99 - percentile) * 35 if small == 1

* Step 7: Save result
save "`data_dir'/levels_teacher_bonus.dta", replace
restore






*Gains Group
preserve
* Step 0: Keep only gains incentive teachers
keep if gains == 1

* Step 1: cleansing variable
drop if missing(zmathbase2) | missing(z_final_score)

* Step 2: Compute student gain
gen gain = z_final_score - zmathbase2

* Step 3: Create prefecture
gen sch_group = .
replace sch_group = 1 if real(substr(string(schid),1,1)) == 1
replace sch_group = 2 if real(substr(string(schid),1,1)) == 2
assert inlist(sch_group, 1, 2)

* Step 4: Create tournament ID (4 groups)
gen tournament_id = .
replace tournament_id = 1 if big == 1 & sch_group == 1
replace tournament_id = 2 if big == 1 & sch_group == 2
replace tournament_id = 3 if small == 1 & sch_group == 1
replace tournament_id = 4 if small == 1 & sch_group == 2
assert inlist(tournament_id, 1, 2, 3, 4)


* Step 5: Collapse to teacher-level average gain
collapse (mean) final_measurement = gain, by(schid sch_group tournament_id big small levels gains p4p)

* Step 6: Rank teachers within each tournament
egen rank = rank(final_measurement), by(tournament_id) track
bysort tournament_id: gen N = _N
assert N > 1

* Step 7: Compute percentile rank (top = 99, bottom = 0)
gen percentile = 99 - 99 * (N - rank) / (N - 1)

* Step 8: Compute bonus
gen bonus = .
replace bonus = 7000 - (99 - percentile) * 70 if big == 1
replace bonus = 3500 - (99 - percentile) * 35 if small == 1

* Step 9: Save result
save "`data_dir'/gains_teacher_bonus.dta", replace
restore





*P4P Group
preserve

* Step 0: Keep only P4P incentive teachers
keep if p4p == 1

* Step 1: cleansing variable
drop if missing(zmathbase2) | missing(z_final_score)

* Step 2: Compute gain
gen gain = z_final_score - zmathbase2

* Step 3: Group students by baseline and rank gain within each group
* Give tied gains the same average rank, independent of input order.
egen double student_rank = rank(gain), by(zmathbase2)
bysort zmathbase2: gen group_size = _N

tab group_size

* Step 4: Compute student percentile
gen student_percentile = 99 - 99 * (group_size - student_rank) / (group_size - 1)

* Handle small group edge case (group_size = 1 → undefined percentile)
replace student_percentile = 50 if group_size == 1

* Step 5: Create tournament ID
gen sch_group = .
replace sch_group = 1 if real(substr(string(schid),1,1)) == 1
replace sch_group = 2 if real(substr(string(schid),1,1)) == 2
assert inlist(sch_group, 1, 2)

gen tournament_id = .
replace tournament_id = 1 if big == 1 & sch_group == 1
replace tournament_id = 2 if big == 1 & sch_group == 2
replace tournament_id = 3 if small == 1 & sch_group == 1
replace tournament_id = 4 if small == 1 & sch_group == 2
assert inlist(tournament_id, 1, 2, 3, 4)

* Step 6: Collapse to teacher-level performance index
collapse (mean) final_measurement = student_percentile, by(schid sch_group tournament_id big small levels gains p4p)

* Step 7: Rank teachers by p4p_index within tournament
egen rank = rank(final_measurement), by(tournament_id) track
bysort tournament_id: gen N = _N
assert N > 1

* Step 8: Compute percentile
gen percentile = 99 - 99 * (N - rank) / (N - 1)

* Step 9: Compute bonus
gen bonus = .
replace bonus = 7000 - (99 - percentile) * 70 if big == 1
replace bonus = 3500 - (99 - percentile) * 35 if small == 1

* Step 10: Save result
save "`data_dir'/p4p_teacher_bonus.dta", replace
restore



*Control group: no bonus
preserve

keep if any_incentive == 0
drop if missing(zmathbase2) | missing(z_final_score)

gen sch_group = .
replace sch_group = 1 if real(substr(string(schid),1,1)) == 1
replace sch_group = 2 if real(substr(string(schid),1,1)) == 2
assert inlist(sch_group, 1, 2)

collapse (mean) final_measurement = z_final_score, by(schid sch_group big small levels gains p4p)
gen bonus = 0

save "`data_dir'/control_teacher_bonus.dta", replace

restore

*generate pure Incentive-info dataset
use "`data_dir'/levels_teacher_bonus.dta", clear
append using "`data_dir'/gains_teacher_bonus.dta"
append using "`data_dir'/p4p_teacher_bonus.dta"
append using "`data_dir'/control_teacher_bonus.dta"
save "`data_dir'/combined_teacher_data.dta", replace

*To merge the dataset
use "`raw_dir'/Pay_by_Design_JOLE.dta",clear
merge m:1 schid using "`data_dir'/combined_teacher_data.dta", assert(master match)

tab _merge
drop _merge
save "`data_dir'/teacher_with_incentive.dta",replace
export delimited using "`data_dir'/teacher_with_incentive.csv", replace nolabel

*No. of schools re-check
use "`data_dir'/teacher_with_incentive.dta", clear
duplicates drop schid, force

replace sch_group = 1 if real(substr(string(schid),1,1)) == 1
replace sch_group = 2 if real(substr(string(schid),1,1)) == 2
assert inlist(sch_group, 1, 2)

gen treatment_category = ""
replace treatment_category = "control" if any_incentive == 0
replace treatment_category = "level_small" if levels == 1 & small == 1
replace treatment_category = "level_big" if levels == 1 & big == 1
replace treatment_category = "gain_small" if gains == 1 & small == 1
replace treatment_category = "gain_big" if gains == 1 & big == 1
replace treatment_category = "p4p_small" if p4p == 1 & small == 1
replace treatment_category = "p4p_big" if p4p == 1 & big == 1
drop if missing(bonus)


* Count occurrences for each prefecture and treatment
collapse (count) schid, by(sch_group treatment_category)

* Reshape to wide format
reshape wide schid, i(treatment_category) j(sch_group)

* Rename columns for clarity
rename schid1 sch1
rename schid2 sch2

* Export to Excel
export excel using "`outdir'/Treat_dist_byschid_rea.xlsx", firstrow(var) replace


