/*
Replication

Purpose: Replicate the empirical analyses of teacher incentives and student
achievement in Loyalka et al. (2019), "Pay by Design," Journal of Labor Economics.

Input from the authors' replication package: data/raw/Pay_by_Design_JOLE.dta.
Multiple-testing routine: replication/kfwebs.ado (included in this repository).

Required packages: estout, distplot, and svmat2 (dm79, used by kfwebs.ado).

Outputs:
- Main Tables 2-6 and Appendix Tables 1-5: CSV and LaTeX files
- Test-score distributions: four PDF figures
- Additional hypothesis tests and runtime details: replication.log

Tables and figures are saved in output/replication/; the log in output/logs/.

Run from the repository root via run_all.do, or run
do replication/Pay_by_design_JOLE_edited.do. An optional first argument
supplies the project root.

Original analysis code: Prashant Loyalka and Sean Sylvia.
Additional exhibits and path revisions: Leo (Guanlin) Li, 2025.
*/


args project_root
if `"`project_root'"' == "" local project_root "`c(pwd)'"

capture confirm file "`project_root'/run_all.do"
if _rc {
    display as error "Run from the repository root: cd to the folder containing run_all.do."
    exit 601
}

local raw_dir "`project_root'/data/raw"
local outdir "`project_root'/output/replication"
local logdir "`project_root'/output/logs"
foreach folder in output output/replication output/logs {
    capture mkdir "`project_root'/`folder'"
}
adopath ++ "`project_root'/replication"

set more off
capture log close replication
log using "`logdir'/replication.log", text replace name(replication)
display "Stata version: " c(stata_version)

***Import Data
use "`raw_dir'/Pay_by_Design_JOLE.dta", clear

***Variable Lists

*Treatments
global inc_design levels gains p4p
global inc_size small big

*Controls
global base_covs zmathbase1 zmathbase2
global other_covs female stuage dad_jhs_yn mom_jhs_yn ses class_size teacher_experience teacher_basepay 

*Secondary Outcomes
global item_difficulty t_taught_any t_taught_easy t_taught_med t_taught_hard easyscore mediumscore hardscore
global secondary_stu math_self_concept math_anxiety math_intrin_mtv math_instr_mtv stu_time_math stu_percept_t_practice t_cares t_can_manage ///
 t_communicates parents_help_hmwk teacher_tutor_times substitute_time

/***************/
/****TABLES****/
/***************/


/*---------------------------------------------------------------------------------*/
/*Table 2: Impact of Incentives on Test Scores*/

eststo clear
/* reg of incentives */
eststo: xi: reg z_final_score any_incentive $base_covs i.countyid, vce(cluster schid)
			su z_final_score if e(sample)==1 & control==1
			estadd scalar mean =  round(`r(mean)',0.001)
			
/* reg of incentives2*/
eststo: xi: reg z_final_score any_incentive $base_covs $other_covs i.countyid, vce(cluster schid)
			su z_final_score if e(sample)==1 & control==1
			estadd scalar mean =  round(`r(mean)',0.001)

/* reg of reward size */			
eststo: xi: reg z_final_score $inc_size $base_covs i.countyid, vce(cluster schid)
			lincom big - small
			estadd scalar big_small = round(`r(estimate)',0.001)
			local t = `r(estimate)'/`r(se)'
			estadd scalar big_small_p = round(2*ttail(e(df_r),abs(`t')),0.001)
			
			su z_final_score if e(sample)==1 & control==1
			estadd scalar mean =  round(`r(mean)',0.001)

/* reg of reward size2*/			
eststo: xi: reg z_final_score $inc_size $base_covs $other_covs i.countyid, vce(cluster schid)
			lincom big - small
			estadd scalar big_small = round(`r(estimate)',0.001)
			local t = `r(estimate)'/`r(se)'
			estadd scalar big_small_p = round(2*ttail(e(df_r),abs(`t')),0.001)
			
			su z_final_score if e(sample)==1 & control==1
			estadd scalar mean =  round(`r(mean)',0.001)	

/*reg of comparison*/			
eststo: xi: reg z_final_score $inc_design $base_covs i.countyid, vce(cluster schid)
			lincom gains - levels
			estadd scalar gains_levels = round(`r(estimate)',0.001)
			local t = `r(estimate)'/`r(se)'
			estadd scalar gains_levels_p = round(2*ttail(e(df_r),abs(`t')),0.001)
			
			lincom p4p - levels
			estadd scalar p4p_levels = round(`r(estimate)',0.001)
			local t = `r(estimate)'/`r(se)'
			estadd scalar p4p_levels_p = round(2*ttail(e(df_r),abs(`t')),0.001)
			
			lincom p4p - gains
			estadd scalar p4p_gains = round(`r(estimate)',0.001)
			local t = `r(estimate)'/`r(se)'
			estadd scalar p4p_gains_p = round(2*ttail(e(df_r),abs(`t')),0.001)
			
			su z_final_score if e(sample)==1 & control==1
			estadd scalar mean =  round(`r(mean)',0.001)
			/*F test*/
			testparm levels gains p4p, equal			
			estadd scalar testequal_p = round(`r(p)',0.001)

/*reg of comparison*/
eststo: xi: reg z_final_score $inc_design $base_covs $other_covs i.countyid, vce(cluster schid)
			lincom gains - levels
			estadd scalar gains_levels = round(`r(estimate)',0.001)
			local t = `r(estimate)'/`r(se)'
			estadd scalar gains_levels_p = round(2*ttail(e(df_r),abs(`t')),0.001)
			
			lincom p4p - levels
			estadd scalar p4p_levels = round(`r(estimate)',0.001)
			local t = `r(estimate)'/`r(se)'
			estadd scalar p4p_levels_p = round(2*ttail(e(df_r),abs(`t')),0.001)
			
			lincom p4p - gains
			estadd scalar p4p_gains = round(`r(estimate)',0.001)
			local t = `r(estimate)'/`r(se)'
			estadd scalar p4p_gains_p = round(2*ttail(e(df_r),abs(`t')),0.001)
			
			su z_final_score if e(sample)==1 & control==1
			estadd scalar mean =  round(`r(mean)',0.001)	
			
			testparm levels gains p4p, equal			
			estadd scalar testequal_p = round(`r(p)',0.001)
			
/*reg of comparison, small size*/
eststo: xi: reg z_final_score $inc_design $base_covs i.countyid if small==1 | control==1, vce(cluster schid)
			lincom gains - levels
			estadd scalar gains_levels = round(`r(estimate)',0.001)
			local t = `r(estimate)'/`r(se)'
			estadd scalar gains_levels_p = round(2*ttail(e(df_r),abs(`t')),0.001)
			
			lincom p4p - levels
			estadd scalar p4p_levels = round(`r(estimate)',0.001)
			local t = `r(estimate)'/`r(se)'
			estadd scalar p4p_levels_p = round(2*ttail(e(df_r),abs(`t')),0.001)
			
			lincom p4p - gains
			estadd scalar p4p_gains = round(`r(estimate)',0.001)
			local t = `r(estimate)'/`r(se)'
			estadd scalar p4p_gains_p = round(2*ttail(e(df_r),abs(`t')),0.001)
			su z_final_score if e(sample)==1 & control==1
			estadd scalar mean =  round(`r(mean)',0.001)
			
			testparm levels gains p4p, equal			
			estadd scalar testequal_p = round(`r(p)',0.001)
			
eststo: xi: reg z_final_score $inc_design $base_covs $other_covs i.countyid if small==1 | control==1, vce(cluster schid)
			lincom gains - levels
			estadd scalar gains_levels = round(`r(estimate)',0.001)
			local t = `r(estimate)'/`r(se)'
			estadd scalar gains_levels_p = round(2*ttail(e(df_r),abs(`t')),0.001)
			
			lincom p4p - levels
			estadd scalar p4p_levels = round(`r(estimate)',0.001)
			local t = `r(estimate)'/`r(se)'
			estadd scalar p4p_levels_p = round(2*ttail(e(df_r),abs(`t')),0.001)
			
			lincom p4p - gains
			estadd scalar p4p_gains = round(`r(estimate)',0.001)
			local t = `r(estimate)'/`r(se)'
			estadd scalar p4p_gains_p = round(2*ttail(e(df_r),abs(`t')),0.001)
			su z_final_score if e(sample)==1 & control==1
			estadd scalar mean =  round(`r(mean)',0.001)
			
			testparm levels gains p4p, equal			
			estadd scalar testequal_p = round(`r(p)',0.001)		

/*reg of comparison, big size*/
eststo: xi: reg z_final_score $inc_design $base_covs i.countyid if big==1 | control==1, vce(cluster schid)
			lincom gains - levels
			estadd scalar gains_levels = round(`r(estimate)',0.001)
			local t = `r(estimate)'/`r(se)'
			estadd scalar gains_levels_p = round(2*ttail(e(df_r),abs(`t')),0.001)
			
			lincom p4p - levels
			estadd scalar p4p_levels = round(`r(estimate)',0.001)
			local t = `r(estimate)'/`r(se)'
			estadd scalar p4p_levels_p = round(2*ttail(e(df_r),abs(`t')),0.001)
			
			lincom p4p - gains
			estadd scalar p4p_gains = round(`r(estimate)',0.001)
			local t = `r(estimate)'/`r(se)'
			estadd scalar p4p_gains_p = round(2*ttail(e(df_r),abs(`t')),0.001)
			su z_final_score if e(sample)==1 & control==1
			estadd scalar mean =  round(`r(mean)',0.001)
			
			testparm levels gains p4p, equal			
			estadd scalar testequal_p = round(`r(p)',0.001)
			
eststo: xi: reg z_final_score $inc_design $base_covs $other_covs i.countyid if big==1 | control==1, vce(cluster schid)
			lincom gains - levels
			estadd scalar gains_levels = round(`r(estimate)',0.001)
			local t = `r(estimate)'/`r(se)'
			estadd scalar gains_levels_p = round(2*ttail(e(df_r),abs(`t')),0.001)
			
			lincom p4p - levels
			estadd scalar p4p_levels = round(`r(estimate)',0.001)
			local t = `r(estimate)'/`r(se)'
			estadd scalar p4p_levels_p = round(2*ttail(e(df_r),abs(`t')),0.001)
			
			lincom p4p - gains
			estadd scalar p4p_gains = round(`r(estimate)',0.001)
			local t = `r(estimate)'/`r(se)'
			estadd scalar p4p_gains_p = round(2*ttail(e(df_r),abs(`t')),0.001)
			su z_final_score if e(sample)==1 & control==1
			estadd scalar mean =  round(`r(mean)',0.001)
			
			testparm levels gains p4p, equal 
			/*ADDED F-TEST OF EQUALITY OF ALL COEFFICIENTS*/
			estadd scalar testequal_p = round(`r(p)',0.001)
			
esttab using "`outdir'/Table2.csv", nolabel b(3) se(3) obslast star(* 0.10 ** 0.05 *** 0.01) ///
	drop(_I* $base_covs $other_covs _cons) replace ///
	scalar("big_small Large - Small" "big_small_p P-value: Large - Small" ///
	"gains_levels Gains - Levels" "gains_levels_p P-value: Gains - Levels" ///
	"p4p_levels P4P - Levels" "p4p_levels_p P-value: P4P - Levels" ///
	"p4p_gains P4P - Gains" "p4p_gains_p P-value: P4P - Gains" "mean Mean in Control Group" ///
	"testequal_p P-value: Coeffs Equal") 
	
	/* Romano-Wolf Multiple Hyp Tests */
	
/* correct on treatments */
	kfwebs (z_final_score levels gains p4p $base_covs i.countyid), ///
			testvar(levels gains p4p) kvalue(1) alphas(.05 .1) reps(1000) ///
			seed(1001) strata(countyid) cluster(schid) ///
			hypadd(gains-levels;p4p-levels;p4p-gains) 
			
	kfwebs (z_final_score levels gains p4p $base_covs $other_covs i.countyid), ///
			testvar(levels gains p4p) kvalue(1) alphas(.05 .1) reps(1000) ///
			seed(1001) strata(countyid) cluster(schid) ///
			hypadd(gains-levels;p4p-levels;p4p-gains) 
			
/* correct on size */
	kfwebs (z_final_score small big $base_covs i.countyid), ///
			testvar(small big) kvalue(1) alphas(.05 .1) reps(1000) ///
			seed(1001) strata(countyid) cluster(schid) ///
			hypadd(small-big) 		
			
	kfwebs (z_final_score small big $base_covs $other_covs i.countyid), ///
			testvar(small big) kvalue(1) alphas(.05 .1) reps(1000) ///
			seed(1001) strata(countyid) cluster(schid) ///
			hypadd(small-big) 	

/* correct on treatments, small */			
	kfwebs (z_final_score levels gains p4p $base_covs i.countyid) if small==1|control==1, ///
			testvar(levels gains p4p) kvalue(1) alphas(.05 .1) reps(1000) ///
			seed(1001) strata(countyid) cluster(schid) ///
			hypadd(gains-levels;p4p-levels;p4p-gains)
			
	kfwebs (z_final_score levels gains p4p $base_covs $other_covs i.countyid) if small==1|control==1, ///
			testvar(levels gains p4p) kvalue(1) alphas(.05 .1) reps(1000) ///
			seed(1001) strata(countyid) cluster(schid) ///
			hypadd(gains-levels;p4p-levels;p4p-gains)				

/* correct on treatments, big */
	kfwebs (z_final_score levels gains p4p $base_covs i.countyid) if big==1|control==1, ///
			testvar(levels gains p4p) kvalue(1) alphas(.05 .1) reps(1000) ///
			seed(1001) strata(countyid) cluster(schid) ///
			hypadd(gains-levels;p4p-levels;p4p-gains)
			
	kfwebs (z_final_score levels gains p4p $base_covs $other_covs i.countyid) if big==1|control==1, ///
			testvar(levels gains p4p) kvalue(1) alphas(.05 .1) reps(1000) ///
			seed(1001) strata(countyid) cluster(schid) ///
			hypadd(gains-levels;p4p-levels;p4p-gains)	
	
	
	
/*---------------------------------------------------------------------------------*/


* Reload the source data before distributional tests and subsequent exhibits.
use "`raw_dir'/Pay_by_Design_JOLE.dta", clear

set seed 42
/*---------------------------------------------------------------------------------*/
/*TABLE 3: Tests for Distributional Treatment Effects, aka cdf maximum*/
qui reg z_final_score zmathbase2 zmathbase1 i.countyid
predict e, residual  /*the ex-ante effect is removed*/

/*exact for small sample size*/

eststo clear  // Clear any previous stored models

/* ===================== PFP vs. Levels ===================== */

/* 1. Two-Sided KS Test */
bootstrap r(D), cluster(schid) reps(1000): ksmirnov e if treatment4groups == 2 | treatment4groups == 4, by(treatment4groups) exact
matrix results = r(table)
local D_stat = results[1,1]
local p_value = results[4,1]

eststo model1
estadd local test "Equality of distributions"
estadd scalar test_stat = `D_stat'
estadd scalar p_value = `p_value'

/* 2. Unidirectional KS Test */
bootstrap r(D_1), cluster(schid) reps(1000): ksmirnov e if treatment4groups == 2 | treatment4groups == 4, by(treatment4groups) exact
matrix results = r(table)
local D1_stat = results[1,1]
local p1_value = results[4,1]

eststo model2
estadd local test "F_PFP - F_Levels"
estadd scalar test_stat = `D1_stat'
estadd scalar p_value = `p1_value'

/* 3. Unidirectional KS Test */
bootstrap (-r(D_2)), cluster(schid) reps(1000): ksmirnov e if treatment4groups == 2 | treatment4groups == 4, by(treatment4groups) exact
matrix results = r(table)
local D2_stat = results[1,1]
local p2_value = results[4,1]

eststo model3
estadd local test "F_Levels - F_PFP"
estadd scalar test_stat = `D2_stat'
estadd scalar p_value = `p2_value'

	/*pfp vs. control*/	
bootstrap r(D), cluster(schid) reps(1000): ksmirnov e if (treatment4groups == 1) | (treatment4groups == 4), by(treatment4groups) exact
matrix results = r(table)
local D_stat = results[1,1]
local p_value = results[4,1]

eststo model4 
estadd local test "Equality of distributions"
estadd scalar test_stat = `D_stat'
estadd scalar p_value = `p_value'

bootstrap r(D_1), cluster(schid) reps(1000): ksmirnov e if (treatment4groups == 1) | (treatment4groups == 4), by(treatment4groups) exact
matrix results = r(table)
local D1_stat = results[1,1]
local p1_value = results[4,1]

eststo model5  
estadd local test "F_PFP - F_Control"
estadd scalar test_stat = `D1_stat'
estadd scalar p_value = `p1_value'


bootstrap (-r(D_2)), cluster(schid) reps(1000): ksmirnov e if (treatment4groups == 1) | (treatment4groups == 4), by(treatment4groups) exact
matrix results = r(table)
local D2_stat = results[1,1]
local p2_value = results[4,1]

eststo model6 
estadd local test "F_Control - F_PFP"
estadd scalar test_stat = `D2_stat'
estadd scalar p_value = `p2_value'


	/*pfp vs. gains*/
	
bootstrap r(D), cluster(schid) reps(1000): ksmirnov e if (treatment4groups == 3) | (treatment4groups == 4), by(treatment4groups) exact
matrix results = r(table)
local D_stat = results[1,1]
local p_value = results[4,1]

eststo model7
estadd local test "Equality of distributions"
estadd scalar test_stat = `D_stat'
estadd scalar p_value = `p_value'

bootstrap r(D_1), cluster(schid) reps(1000): ksmirnov e if (treatment4groups == 3) | (treatment4groups == 4), by(treatment4groups) exact
matrix results = r(table)
local D1_stat = results[1,1]
local p1_value = results[4,1]

eststo model8 
estadd local test "F_PFP - F_Gains"
estadd scalar test_stat = `D1_stat'
estadd scalar p_value = `p1_value'


bootstrap (-r(D_2)), cluster(schid) reps(1000): ksmirnov e if (treatment4groups == 3) | (treatment4groups == 4), by(treatment4groups) exact
matrix results = r(table)
local D2_stat = results[1,1]
local p2_value = results[4,1]

eststo model9
estadd local test "F_Gains - F_PFP"
estadd scalar test_stat = `D2_stat'
estadd scalar p_value = `p2_value'
	
	/*gains vs. levels*/
	
bootstrap r(D), cluster(schid) reps(1000): ksmirnov e if (treatment4groups == 2) | (treatment4groups == 3), by(treatment4groups) exact
matrix results = r(table)
local D_stat = results[1,1]
local p_value = results[4,1]

eststo model10  
estadd local test "Equality of distributions"
estadd scalar test_stat = `D_stat'
estadd scalar p_value = `p_value'

bootstrap r(D_1), cluster(schid) reps(1000): ksmirnov e if (treatment4groups == 2) | (treatment4groups == 3), by(treatment4groups) exact
matrix results = r(table)
local D1_stat = results[1,1]
local p1_value = results[4,1]

eststo model11
estadd local test "F_Gains - F_Levels"
estadd scalar test_stat = `D1_stat'
estadd scalar p_value = `p1_value'

bootstrap (-r(D_2)), cluster(schid) reps(1000): ksmirnov e if (treatment4groups == 2) | (treatment4groups == 3), by(treatment4groups) exact
matrix results = r(table)
local D2_stat = results[1,1]
local p2_value = results[4,1]

eststo model12
estadd local test "F_Levels - F_Gains"
estadd scalar test_stat = `D2_stat'
estadd scalar p_value = `p2_value'



	/*gains vs. control*/
bootstrap r(D), cluster(schid) reps(1000): ksmirnov e if (treatment4groups == 1) | (treatment4groups == 3), by(treatment4groups) exact
matrix results = r(table)
local D_stat = results[1,1]
local p_value = results[4,1]

eststo model13
estadd local test "Equality of distributions"
estadd scalar test_stat = `D_stat'
estadd scalar p_value = `p_value'

bootstrap r(D_1), cluster(schid) reps(1000): ksmirnov e if (treatment4groups == 1) | (treatment4groups == 3), by(treatment4groups) exact
matrix results = r(table)
local D1_stat = results[1,1]
local p1_value = results[4,1]

eststo model14
estadd local test "F_Gains - F_Control"
estadd scalar test_stat = `D1_stat'
estadd scalar p_value = `p1_value'

bootstrap (-r(D_2)), cluster(schid) reps(1000): ksmirnov e if (treatment4groups == 1) | (treatment4groups == 3), by(treatment4groups) exact
matrix results = r(table)
local D2_stat = results[1,1]
local p2_value = results[4,1]

eststo model15
estadd local test "F_Control - F_Gains"
estadd scalar test_stat = `D2_stat'
estadd scalar p_value = `p2_value'

	
	/*levels vs. control*/
bootstrap r(D), cluster(schid) reps(1000): ksmirnov e if (treatment4groups == 1) | (treatment4groups == 2), by(treatment4groups) exact
matrix results = r(table)
local D_stat = results[1,1]
local p_value = results[4,1]

eststo model16  
estadd local test "Equality of distributions"
estadd scalar test_stat = `D_stat'
estadd scalar p_value = `p_value'

bootstrap r(D_1), cluster(schid) reps(1000): ksmirnov e if (treatment4groups == 1) | (treatment4groups == 2), by(treatment4groups) exact
matrix results = r(table)
local D1_stat = results[1,1]
local p1_value = results[4,1]

eststo model17 
estadd local test "F_Levels - F_Control"
estadd scalar test_stat = `D1_stat'
estadd scalar p_value = `p1_value'

bootstrap (-r(D_2)), cluster(schid) reps(1000): ksmirnov e if (treatment4groups == 1) | (treatment4groups == 2), by(treatment4groups) exact
matrix results = r(table)
local D2_stat = results[1,1]
local p2_value = results[4,1]

eststo model18
estadd local test "F_Control - F_Levels"
estadd scalar test_stat = `D2_stat'
estadd scalar p_value = `p2_value'


/* ===================== Export to LaTeX / CSV Correctly ===================== */
esttab model1 model2 model3 model4 model5 model6 model7 model8 model9 model10 model11 model12 model13 model14 model15 model16 model17 model18 using "`outdir'/Table3.tex", tex replace nolabel b(3) se(3) obslast star(* 0.10 ** 0.05 *** 0.01) ///
    scalar("test Test" "test_stat Test Statistic" "p_value P-Value")

drop e
/*---------------------------------------------------------------------------------*/

/*---------------------------------------------------------------------------------*/
/*TABLE 4: Impacts on question difficulty subscores and curricular coverage*/

eststo clear
foreach var of varlist $item_difficulty {
	eststo: xi: reg `var' $inc_design $base_covs $other_covs i.countyid, vce(cluster schid)

	lincom gains - levels
	estadd scalar gains_levels = round(`r(estimate)',0.001)
	local t = `r(estimate)'/`r(se)'
	estadd scalar gains_levels_p = round(2*ttail(e(df_r),abs(`t')),0.001)
	
	lincom p4p - levels
	estadd scalar p4p_levels = round(`r(estimate)',0.001)
	local t = `r(estimate)'/`r(se)'
	estadd scalar p4p_levels_p = round(2*ttail(e(df_r),abs(`t')),0.001)
	
	lincom p4p - gains
	estadd scalar p4p_gains = round(`r(estimate)',0.001)
	local t = `r(estimate)'/`r(se)'
	estadd scalar p4p_gains_p = round(2*ttail(e(df_r),abs(`t')),0.001)
	
	su z_final_score if e(sample)==1 & control==1
	estadd scalar mean =  round(`r(mean)',0.001)
	
	testparm levels gains p4p, equal
												
	estadd scalar testequal_p = round(`r(p)',0.001)
}

esttab using "`outdir'/Table4.csv", nolabel b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) ///
	keep($inc_design) nonote replace
/*---------------------------------------------------------------------------------*/

/**********************************************************************************/
/*TABLE 5: Correlation between Teacher Perception of Own Value-added and Student Characteristics*/
eststo clear

	eststo: areg va_tutor_norm  pctrank , absorb(teachid) vce(cluster teachid)
	eststo: areg va_tutor_norm  pctrank female stuage dad_jhs_yn mom_jhs_yn ses , absorb(teachid) vce(cluster teachid)
	
	eststo: areg va_tutor_norm  i.pctrank_3bins , absorb(teachid) vce(cluster teachid)
	eststo: areg va_tutor_norm  i.pctrank_3bins female stuage dad_jhs_yn mom_jhs_yn ses , absorb(teachid) vce(cluster teachid)

	eststo: areg va_tutor_norm  avgzmath5_pctrank, absorb(teachid) vce(cluster teachid)
	eststo: areg va_tutor_norm  avgzmath5_pctrank female stuage dad_jhs_yn mom_jhs_yn ses , absorb(teachid) vce(cluster teachid)
	
	eststo: areg va_tutor_norm  i.avg_pctrank_3bins , absorb(teachid) vce(cluster teachid)
	eststo: areg va_tutor_norm  i.avg_pctrank_3bins female stuage dad_jhs_yn mom_jhs_yn ses , absorb(teachid) vce(cluster teachid)

esttab using "`outdir'/Table5.csv", nolabel b(3) se(3)  star(* 0.10 ** 0.05 *** 0.01) drop (1.*) replace nonote	order(*pctrank* avg*)		

/*---------------------------------------------------------------------------------*/
/*TABLE 6: Within Class Distributional Effects (Triage) AND Appendix Table 5: Within-class Distributional Effects (Full Regressions)*/

* Table 6 cols (1)-(2): with the bottom tercile as base, the arm x tercile
* interactions are the middle-vs-bottom and top-vs-bottom differences.
capture program drop t6_contrasts
program define t6_contrasts
    args tercile
    local a 2
    foreach arm in levels gains pfp {
        estadd scalar `arm'_mb    = round(_b[`a'.treatment4groups#2.`tercile'], 0.001)
        estadd scalar `arm'_mb_se = round(_se[`a'.treatment4groups#2.`tercile'], 0.001)
        estadd scalar `arm'_tb    = round(_b[`a'.treatment4groups#3.`tercile'], 0.001)
        estadd scalar `arm'_tb_se = round(_se[`a'.treatment4groups#3.`tercile'], 0.001)
        local ++a
    }
end

eststo clear

*Panel A: Teacher Perception of Own Value-Added for Student
eststo: reg z_final_score  i.treatment4groups##i.va_tutor_norm_terc zmathbase2 zmathbase1  i.countyid ,vce(cluster schid)
t6_contrasts va_tutor_norm_terc
		lincom  2.treatment4groups#3.va_tutor_norm_terc - 2.treatment4groups#2.va_tutor_norm_terc
		estadd scalar levels_tm = round(`r(estimate)',0.001)
		estadd scalar levels_tm_se = round(`r(se)',0.001)
		local t = `r(estimate)'/`r(se)'
		estadd scalar levels_tm_p = round(2*ttail(e(df_r),abs(`t')),0.001)
														
		lincom  3.treatment4groups#3.va_tutor_norm_terc - 3.treatment4groups#2.va_tutor_norm_terc
		estadd scalar gains_tm = round(`r(estimate)',0.001)
		estadd scalar gains_tm_se = round(`r(se)',0.001)
			local t = `r(estimate)'/`r(se)'
			estadd scalar gains_tm_p = round(2*ttail(e(df_r),abs(`t')),0.001)
														
		lincom  4.treatment4groups#3.va_tutor_norm_terc - 4.treatment4groups#2.va_tutor_norm_terc
		estadd scalar pfp_tm = round(`r(estimate)',0.001)
		estadd scalar pfp_tm_se = round(`r(se)',0.001)
			local t = `r(estimate)'/`r(se)'
			estadd scalar pfp_tm_p = round(2*ttail(e(df_r),abs(`t')),0.001)

												
*Panel B: Teacher Ranking of Students at Baseline												
eststo: reg z_final_score  i.treatment4groups##i.pctrank_3bins zmathbase2 zmathbase1 i.countyid ,vce(cluster schid)
t6_contrasts pctrank_3bins														
		lincom  2.treatment4groups#3.pctrank_3bins - 2.treatment4groups#2.pctrank_3bins
		estadd scalar levels_tm = round(`r(estimate)',0.001)
		estadd scalar levels_tm_se = round(`r(se)',0.001)
			local t = `r(estimate)'/`r(se)'
			estadd scalar levels_tm_p = round(2*ttail(e(df_r),abs(`t')),0.001)
														
		lincom  3.treatment4groups#3.pctrank_3bins - 3.treatment4groups#2.pctrank_3bins
		estadd scalar gains_tm = round(`r(estimate)',0.001)
		estadd scalar gains_tm_se = round(`r(se)',0.001)
			local t = `r(estimate)'/`r(se)'
			estadd scalar gains_tm_p = round(2*ttail(e(df_r),abs(`t')),0.001)
														
		lincom  4.treatment4groups#3.pctrank_3bins - 4.treatment4groups#2.pctrank_3bins
		estadd scalar pfp_tm = round(`r(estimate)',0.001)
		estadd scalar pfp_tm_se = round(`r(se)',0.001)
			local t = `r(estimate)'/`r(se)'
			estadd scalar pfp_tm_p = round(2*ttail(e(df_r),abs(`t')),0.001)

	
*Panel C: Ranking of Students by Baseline Exam Score												
eststo: reg z_final_score  i.treatment4groups##i.avg_pctrank_3bins zmathbase2 zmathbase1 i.countyid ,vce(cluster schid)
t6_contrasts avg_pctrank_3bins														
		lincom  2.treatment4groups#3.avg_pctrank_3bins - 2.treatment4groups#2.avg_pctrank_3bins
		estadd scalar levels_tm = round(`r(estimate)',0.001)
		estadd scalar levels_tm_se = round(`r(se)',0.001)
			local t = `r(estimate)'/`r(se)'
			estadd scalar levels_tm_p = round(2*ttail(e(df_r),abs(`t')),0.001)
														
		lincom  3.treatment4groups#3.avg_pctrank_3bins - 3.treatment4groups#2.avg_pctrank_3bins
		estadd scalar gains_tm = round(`r(estimate)',0.001)
		estadd scalar gains_tm_se = round(`r(se)',0.001)
			local t = `r(estimate)'/`r(se)'
			estadd scalar gains_tm_p = round(2*ttail(e(df_r),abs(`t')),0.001)
														
		lincom  4.treatment4groups#3.avg_pctrank_3bins - 4.treatment4groups#2.avg_pctrank_3bins
		estadd scalar pfp_tm = round(`r(estimate)',0.001)
		estadd scalar pfp_tm_se = round(`r(se)',0.001)
			local t = `r(estimate)'/`r(se)'
			estadd scalar pfp_tm_p = round(2*ttail(e(df_r),abs(`t')),0.001)

esttab using "`outdir'/AppTable5.tex", replace ///
    b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) ///
    stats(N levels_tm gains_tm pfp_tm, labels("Observations" "Levels Incentive" "Gains Incentive" "Pay-for-Percentile")) ///
    drop(*countyid*) ///
    label booktabs ///
    title("Within-Class Distributional Effects (Full Regressions)") ///
    addnotes("Standard errors clustered at school level. * p<0.10, ** p<0.05, *** p<0.01.")

esttab using "`outdir'/Table6.tex", replace booktabs cells(none) nonumbers ///
       mtitles("Teacher VA perception" "Teacher ranking" "Baseline exam rank") ///
       stats(levels_mb levels_mb_se levels_tb levels_tb_se levels_tm levels_tm_se ///
             gains_mb gains_mb_se gains_tb gains_tb_se gains_tm gains_tm_se ///
             pfp_mb pfp_mb_se pfp_tb pfp_tb_se pfp_tm pfp_tm_se, fmt(3) ///
           labels("Levels: middle - bottom" "(s.e.)" "Levels: top - bottom" "(s.e.)" ///
                  "Levels: top - middle" "(s.e.)" ///
                  "Gains: middle - bottom" "(s.e.)" "Gains: top - bottom" "(s.e.)" ///
                  "Gains: top - middle" "(s.e.)" ///
                  "P4P: middle - bottom" "(s.e.)" "P4P: top - bottom" "(s.e.)" ///
                  "P4P: top - middle" "(s.e.)"))
			
* Second regression (Columns 2) - ADDITIONAL CONTROLS INCLUDED
eststo clear

*Panel A: Teacher Perception of Own Value-Added for Student

eststo: reg z_final_score i.treatment4groups##i.va_tutor_norm_terc $base_covs $other_covs i.countyid ,vce(cluster schid)
t6_contrasts va_tutor_norm_terc														
		lincom  2.treatment4groups#3.va_tutor_norm_terc - 2.treatment4groups#2.va_tutor_norm_terc
		estadd scalar levels_tm = round(`r(estimate)',0.001)
		estadd scalar levels_tm_se = round(`r(se)',0.001)
		local t = `r(estimate)'/`r(se)'
		estadd scalar levels_tm_p = round(2*ttail(e(df_r),abs(`t')),0.001)
														
		lincom  3.treatment4groups#3.va_tutor_norm_terc - 3.treatment4groups#2.va_tutor_norm_terc
		estadd scalar gains_tm = round(`r(estimate)',0.001)
		estadd scalar gains_tm_se = round(`r(se)',0.001)
			local t = `r(estimate)'/`r(se)'
			estadd scalar gains_tm_p = round(2*ttail(e(df_r),abs(`t')),0.001)
														
		lincom  4.treatment4groups#3.va_tutor_norm_terc - 4.treatment4groups#2.va_tutor_norm_terc
		estadd scalar pfp_tm = round(`r(estimate)',0.001)
		estadd scalar pfp_tm_se = round(`r(se)',0.001)
			local t = `r(estimate)'/`r(se)'
			estadd scalar pfp_tm_p = round(2*ttail(e(df_r),abs(`t')),0.001)
												
*Panel B: Teacher Ranking of Students at Baseline												
eststo: reg z_final_score  i.treatment4groups##i.pctrank_3bins $base_covs $other_covs i.countyid ,vce(cluster schid)
t6_contrasts pctrank_3bins														
		lincom  2.treatment4groups#3.pctrank_3bins - 2.treatment4groups#2.pctrank_3bins
		estadd scalar levels_tm = round(`r(estimate)',0.001)
		estadd scalar levels_tm_se = round(`r(se)',0.001)
			local t = `r(estimate)'/`r(se)'
			estadd scalar levels_tm_p = round(2*ttail(e(df_r),abs(`t')),0.001)
														
		lincom  3.treatment4groups#3.pctrank_3bins - 3.treatment4groups#2.pctrank_3bins
		estadd scalar gains_tm = round(`r(estimate)',0.001)
		estadd scalar gains_tm_se = round(`r(se)',0.001)
			local t = `r(estimate)'/`r(se)'
			estadd scalar gains_tm_p = round(2*ttail(e(df_r),abs(`t')),0.001)
														
		lincom  4.treatment4groups#3.pctrank_3bins - 4.treatment4groups#2.pctrank_3bins
		estadd scalar pfp_tm = round(`r(estimate)',0.001)
		estadd scalar pfp_tm_se = round(`r(se)',0.001)
			local t = `r(estimate)'/`r(se)'
			estadd scalar pfp_tm_p = round(2*ttail(e(df_r),abs(`t')),0.001)
	
*Panel C: Ranking of Students by Baseline Exam Score												
eststo: reg z_final_score  i.treatment4groups##i.avg_pctrank_3bins $base_covs $other_covs i.countyid ,vce(cluster schid)
t6_contrasts avg_pctrank_3bins														
		lincom  2.treatment4groups#3.avg_pctrank_3bins - 2.treatment4groups#2.avg_pctrank_3bins
		estadd scalar levels_tm = round(`r(estimate)',0.001)
		estadd scalar levels_tm_se = round(`r(se)',0.001)
			local t = `r(estimate)'/`r(se)'
			estadd scalar levels_tm_p = round(2*ttail(e(df_r),abs(`t')),0.001)
														
		lincom  3.treatment4groups#3.avg_pctrank_3bins - 3.treatment4groups#2.avg_pctrank_3bins
		estadd scalar gains_tm = round(`r(estimate)',0.001)
		estadd scalar gains_tm_se = round(`r(se)',0.001)
			local t = `r(estimate)'/`r(se)'
			estadd scalar gains_tm_p = round(2*ttail(e(df_r),abs(`t')),0.001)
														
		lincom  4.treatment4groups#3.avg_pctrank_3bins - 4.treatment4groups#2.avg_pctrank_3bins
		estadd scalar pfp_tm = round(`r(estimate)',0.001)
		estadd scalar pfp_tm_se = round(`r(se)',0.001)
			local t = `r(estimate)'/`r(se)'
			estadd scalar pfp_tm_p = round(2*ttail(e(df_r),abs(`t')),0.001)

esttab using "`outdir'/AppTable5_even.tex", replace ///
    b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) ///
    stats(N levels_tm gains_tm pfp_tm, labels("Observations" "Levels Incentive" "Gains Incentive" "Pay-for-Percentile")) ///
    drop(*countyid*) ///
    label booktabs ///
    title("Within-Class Distributional Effects (Full Regressions)") ///
    addnotes("Standard errors clustered at school level. * p<0.10, ** p<0.05, *** p<0.01.")


esttab using "`outdir'/Table6_controls.tex", replace booktabs cells(none) nonumbers ///
       mtitles("Teacher VA perception" "Teacher ranking" "Baseline exam rank") ///
       stats(levels_mb levels_mb_se levels_tb levels_tb_se levels_tm levels_tm_se ///
             gains_mb gains_mb_se gains_tb gains_tb_se gains_tm gains_tm_se ///
             pfp_mb pfp_mb_se pfp_tb pfp_tb_se pfp_tm pfp_tm_se, fmt(3) ///
           labels("Levels: middle - bottom" "(s.e.)" "Levels: top - bottom" "(s.e.)" ///
                  "Levels: top - middle" "(s.e.)" ///
                  "Gains: middle - bottom" "(s.e.)" "Gains: top - bottom" "(s.e.)" ///
                  "Gains: top - middle" "(s.e.)" ///
                  "P4P: middle - bottom" "(s.e.)" "P4P: top - bottom" "(s.e.)" ///
                  "P4P: top - middle" "(s.e.)"))



/*---------------------------------------------------------------------------------*/

/*---------------------------------------------------------------------------------*/
/*APPENDIX TABLE 1: Descriptive Statistics and Balance Check*/
eststo clear

	foreach var of varlist $base_covs female stuage dad_jhs_yn mom_jhs_yn ses {
	eststo: reg `var' $inc_design i.countyid, vce(cluster schid)
		su `var' if e(sample)==1 & control==1
			estadd scalar mean = `r(mean)'
		testparm $inc_design
		estadd scalar eqtest = `r(p)'
	}

	
	foreach var of varlist t_age t_female t_han teacher_experience teacher_basepay{
	eststo:  reg `var' $inc_design i.countyid if tone==1, vce(cluster schid)
		su `var' if e(sample)==1 & control==1 & tone==1
			estadd scalar mean = `r(mean)'
		testparm $inc_design 
		estadd scalar eqtest = `r(p)'
	}
	
	foreach var of varlist grade_size sch_num_students sch_num_teachers sch_num_daike {
		eststo:  reg `var' $inc_design i.countyid if schone==1, robust
		su `var' if e(sample)==1 & control==1 & schone==1
			estadd scalar mean = `r(mean)'
		testparm $inc_design 
		estadd scalar eqtest = `r(p)'
	}
	
esttab using "`outdir'/AppTable1.csv", label b(3) se(3)  star(* 0.10 ** 0.05 *** 0.01) keep($inc_design) ///
				nogap wide replace nonote nolabel ///
				scalar("mean Mean in Control" "eqtest Joint Test P-value") 

eststo clear
	foreach var of varlist $base_covs female stuage dad_jhs_yn mom_jhs_yn ses {
	eststo: reg `var' $inc_size i.countyid, vce(cluster schid)
		testparm $inc_size
		estadd scalar eqtest = `r(p)'
	}

	foreach var of varlist t_age t_female t_han teacher_experience teacher_basepay{
	eststo:  reg `var' $inc_size i.countyid if tone==1, vce(cluster schid)
		testparm $inc_size 
		estadd scalar eqtest = `r(p)'
	}
	
	foreach var of varlist grade_size sch_num_students sch_num_teachers sch_num_daike{
		eststo:  reg `var' $inc_size i.countyid if schone==1, robust
		testparm $inc_size 
		estadd scalar eqtest = `r(p)'
	}
	
esttab using "`outdir'/AppTable1.csv", label b(3) se(3)  star(* 0.10 ** 0.05 *** 0.01) keep($inc_size) ///
				nogap wide append nonote nolabel ///
				scalar("eqtest Joint Test P-value") 
/*---------------------------------------------------------------------------------*/
						
/*---------------------------------------------------------------------------------*/
/*APPENDIX TABLE 2: Attrition*/

eststo clear
	*Student Attrition
	eststo: xi:  reg scoremissing levels gains p4p i.countyid, vce(cluster schid)
			su scoremissing if e(sample)==1 & control==1
			estadd scalar mean =  round(`r(mean)',0.001)
			su scoremissing if e(sample)==1 
			estadd scalar attrit =  round(`r(mean)',0.001)
			
	eststo: xi:  reg scoremissing small big i.countyid, vce(cluster schid)
			su scoremissing if e(sample)==1 & control==1
			estadd scalar mean =  round(`r(mean)',0.001)
			
	eststo: xi:  reg scoremissing levels gains p4p  i.countyid if small==1 | control==1, vce(cluster schid)
			su scoremissing if e(sample)==1 & control==1
			estadd scalar mean =  round(`r(mean)',0.001)		
			
	eststo: xi:  reg scoremissing levels gains p4p  i.countyid if big==1 | control==1, vce(cluster schid)
			su scoremissing if e(sample)==1 & control==1
			estadd scalar mean =  round(`r(mean)',0.001)			
	
esttab using "`outdir'/AppTable2.csv", nolabel r2 b(3) se(3)  star(* 0.10 ** 0.05 *** 0.01) ///
	drop(_I*) replace scalar("mean Mean in Control Group" "attrit Overall Attrition Rate")
/*---------------------------------------------------------------------------------*/
	
/*---------------------------------------------------------------------------------*/
/*APPENDIX TABLE 3: Impact of Incentives on Test Scores (School-Level Regressions)*/			

preserve
	xi: reg z_final_score any_incentive $base_covs $other_covs i.countyid
	keep if e(sample)
	
	collapse z_final_score any_incentive $inc_size $inc_design $base_covs $other_covs control countyid, by(schid)

	eststo clear
	eststo: xi: reg z_final_score any_incentive $base_covs i.countyid
				su z_final_score if e(sample)==1 & control==1
				estadd scalar mean =  round(`r(mean)',0.001)
	eststo: xi: reg z_final_score any_incentive $base_covs $other_covs i.countyid
				su z_final_score if e(sample)==1 & control==1
				estadd scalar mean =  round(`r(mean)',0.001)
				
	eststo: xi: reg z_final_score $inc_size $base_covs i.countyid
				lincom big - small
				estadd scalar big_small = round(`r(estimate)',0.001)
				local t = `r(estimate)'/`r(se)'
				estadd scalar big_small_p = round(2*ttail(e(df_r),abs(`t')),0.001)
				
				su z_final_score if e(sample)==1 & control==1
				estadd scalar mean =  round(`r(mean)',0.001)
				
				
	eststo: xi: reg z_final_score $inc_size $base_covs $other_covs i.countyid
				lincom big - small
				estadd scalar big_small = round(`r(estimate)',0.001)
				local t = `r(estimate)'/`r(se)'
				estadd scalar big_small_p = round(2*ttail(e(df_r),abs(`t')),0.001)
				
				su z_final_score if e(sample)==1 & control==1
				estadd scalar mean =  round(`r(mean)',0.001)	
				
	eststo: xi: reg z_final_score $inc_design $base_covs i.countyid
				lincom gains - levels
				estadd scalar gains_levels = round(`r(estimate)',0.001)
				local t = `r(estimate)'/`r(se)'
				estadd scalar gains_levels_p = round(2*ttail(e(df_r),abs(`t')),0.001)
				
				lincom p4p - levels
				estadd scalar p4p_levels = round(`r(estimate)',0.001)
				local t = `r(estimate)'/`r(se)'
				estadd scalar p4p_levels_p = round(2*ttail(e(df_r),abs(`t')),0.001)
				
				lincom p4p - gains
				estadd scalar p4p_gains = round(`r(estimate)',0.001)
				local t = `r(estimate)'/`r(se)'
				estadd scalar p4p_gains_p = round(2*ttail(e(df_r),abs(`t')),0.001)
				
				su z_final_score if e(sample)==1 & control==1
				estadd scalar mean =  round(`r(mean)',0.001)
				
				testparm levels gains p4p, equal			
				estadd scalar testequal_p = round(`r(p)',0.001)
				
				
	eststo: xi: reg z_final_score $inc_design $base_covs $other_covs i.countyid
				lincom gains - levels
				estadd scalar gains_levels = round(`r(estimate)',0.001)
				local t = `r(estimate)'/`r(se)'
				estadd scalar gains_levels_p = round(2*ttail(e(df_r),abs(`t')),0.001)
				
				lincom p4p - levels
				estadd scalar p4p_levels = round(`r(estimate)',0.001)
				local t = `r(estimate)'/`r(se)'
				estadd scalar p4p_levels_p = round(2*ttail(e(df_r),abs(`t')),0.001)
				
				lincom p4p - gains
				estadd scalar p4p_gains = round(`r(estimate)',0.001)
				local t = `r(estimate)'/`r(se)'
				estadd scalar p4p_gains_p = round(2*ttail(e(df_r),abs(`t')),0.001)
				
				su z_final_score if e(sample)==1 & control==1
				estadd scalar mean =  round(`r(mean)',0.001)	
				
				testparm levels gains p4p, equal			
				estadd scalar testequal_p = round(`r(p)',0.001)
							
	eststo: xi: reg z_final_score $inc_design $base_covs i.countyid if small==1 | control==1
				lincom gains - levels
				estadd scalar gains_levels = round(`r(estimate)',0.001)
				local t = `r(estimate)'/`r(se)'
				estadd scalar gains_levels_p = round(2*ttail(e(df_r),abs(`t')),0.001)
				
				lincom p4p - levels
				estadd scalar p4p_levels = round(`r(estimate)',0.001)
				local t = `r(estimate)'/`r(se)'
				estadd scalar p4p_levels_p = round(2*ttail(e(df_r),abs(`t')),0.001)
				
				lincom p4p - gains
				estadd scalar p4p_gains = round(`r(estimate)',0.001)
				local t = `r(estimate)'/`r(se)'
				estadd scalar p4p_gains_p = round(2*ttail(e(df_r),abs(`t')),0.001)
				su z_final_score if e(sample)==1 & control==1
				estadd scalar mean =  round(`r(mean)',0.001)
				
				testparm levels gains p4p, equal			
				estadd scalar testequal_p = round(`r(p)',0.001)
				
	eststo: xi: reg z_final_score $inc_design $base_covs $other_covs i.countyid if small==1 | control==1
				lincom gains - levels
				estadd scalar gains_levels = round(`r(estimate)',0.001)
				local t = `r(estimate)'/`r(se)'
				estadd scalar gains_levels_p = round(2*ttail(e(df_r),abs(`t')),0.001)
				
				lincom p4p - levels
				estadd scalar p4p_levels = round(`r(estimate)',0.001)
				local t = `r(estimate)'/`r(se)'
				estadd scalar p4p_levels_p = round(2*ttail(e(df_r),abs(`t')),0.001)
				
				lincom p4p - gains
				estadd scalar p4p_gains = round(`r(estimate)',0.001)
				local t = `r(estimate)'/`r(se)'
				estadd scalar p4p_gains_p = round(2*ttail(e(df_r),abs(`t')),0.001)
				su z_final_score if e(sample)==1 & control==1
				estadd scalar mean =  round(`r(mean)',0.001)
				
				testparm levels gains p4p, equal			
				estadd scalar testequal_p = round(`r(p)',0.001)		
				
	eststo: xi: reg z_final_score $inc_design $base_covs i.countyid if big==1 | control==1
				lincom gains - levels
				estadd scalar gains_levels = round(`r(estimate)',0.001)
				local t = `r(estimate)'/`r(se)'
				estadd scalar gains_levels_p = round(2*ttail(e(df_r),abs(`t')),0.001)
				
				lincom p4p - levels
				estadd scalar p4p_levels = round(`r(estimate)',0.001)
				local t = `r(estimate)'/`r(se)'
				estadd scalar p4p_levels_p = round(2*ttail(e(df_r),abs(`t')),0.001)
				
				lincom p4p - gains
				estadd scalar p4p_gains = round(`r(estimate)',0.001)
				local t = `r(estimate)'/`r(se)'
				estadd scalar p4p_gains_p = round(2*ttail(e(df_r),abs(`t')),0.001)
				su z_final_score if e(sample)==1 & control==1
				estadd scalar mean =  round(`r(mean)',0.001)
				
				testparm levels gains p4p, equal			
				estadd scalar testequal_p = round(`r(p)',0.001)
				
	eststo: xi: reg z_final_score $inc_design $base_covs $other_covs i.countyid if big==1 | control==1
				lincom gains - levels
				estadd scalar gains_levels = round(`r(estimate)',0.001)
				local t = `r(estimate)'/`r(se)'
				estadd scalar gains_levels_p = round(2*ttail(e(df_r),abs(`t')),0.001)
				
				lincom p4p - levels
				estadd scalar p4p_levels = round(`r(estimate)',0.001)
				local t = `r(estimate)'/`r(se)'
				estadd scalar p4p_levels_p = round(2*ttail(e(df_r),abs(`t')),0.001)
				
				lincom p4p - gains
				estadd scalar p4p_gains = round(`r(estimate)',0.001)
				local t = `r(estimate)'/`r(se)'
				estadd scalar p4p_gains_p = round(2*ttail(e(df_r),abs(`t')),0.001)
				su z_final_score if e(sample)==1 & control==1
				estadd scalar mean =  round(`r(mean)',0.001)
				
				testparm levels gains p4p, equal /*ADDED F-TEST OF EQUALITY OF ALL COEFFICIENTS*/
				estadd scalar testequal_p = round(`r(p)',0.001)
				
esttab using "`outdir'/AppTable3.csv", nolabel b(3) se(3) obslast star(* 0.10 ** 0.05 *** 0.01) ///
		drop(_I* $base_covs $other_covs _cons) replace ///
		scalar("big_small Large - Small" "big_small_p P-value: Large - Small" ///
		"gains_levels Gains - Levels" "gains_levels_p P-value: Gains - Levels" ///
		"p4p_levels P4P - Levels" "p4p_levels_p P-value: P4P - Levels" ///
		"p4p_gains P4P - Gains" "p4p_gains_p P-value: P4P - Gains" "mean Mean in Control Group" ///
		"testequal_p P-value: Coeffs Equal") 
	
	/* Romano-Wolf Multiple Hyp Tests*/
	kfwebs (z_final_score levels gains p4p $base_covs i.countyid), ///
			testvar(levels gains p4p) kvalue(1) alphas(.05 .1) reps(1000) ///
			seed(1001) strata(countyid) cluster(schid) ///
			hypadd(gains-levels;p4p-levels;p4p-gains) 
			
	kfwebs (z_final_score levels gains p4p $base_covs $other_covs i.countyid), ///
			testvar(levels gains p4p) kvalue(1) alphas(.05 .1) reps(1000) ///
			seed(1001) strata(countyid) cluster(schid) ///
			hypadd(gains-levels;p4p-levels;p4p-gains) 
			

	kfwebs (z_final_score small big $base_covs i.countyid), ///
			testvar(small big) kvalue(1) alphas(.05 .1) reps(1000) ///
			seed(1001) strata(countyid) cluster(schid) ///
			hypadd(small-big) 		
			
	kfwebs (z_final_score small big $base_covs $other_covs i.countyid), ///
			testvar(small big) kvalue(1) alphas(.05 .1) reps(1000) ///
			seed(1001) strata(countyid) cluster(schid) ///
			hypadd(small-big) 	
			
	kfwebs (z_final_score levels gains p4p $base_covs i.countyid) if small==1|control==1, ///
			testvar(levels gains p4p) kvalue(1) alphas(.05 .1) reps(1000) ///
			seed(1001) strata(countyid) cluster(schid) ///
			hypadd(gains-levels;p4p-levels;p4p-gains)
			
	kfwebs (z_final_score levels gains p4p $base_covs $other_covs i.countyid) if small==1|control==1, ///
			testvar(levels gains p4p) kvalue(1) alphas(.05 .1) reps(1000) ///
			seed(1001) strata(countyid) cluster(schid) ///
			hypadd(gains-levels;p4p-levels;p4p-gains)				
	
	kfwebs (z_final_score levels gains p4p $base_covs i.countyid) if big==1|control==1, ///
			testvar(levels gains p4p) kvalue(1) alphas(.05 .1) reps(1000) ///
			seed(1001) strata(countyid) cluster(schid) ///
			hypadd(gains-levels;p4p-levels;p4p-gains)
			
	kfwebs (z_final_score levels gains p4p $base_covs $other_covs i.countyid) if big==1|control==1, ///
			testvar(levels gains p4p) kvalue(1) alphas(.05 .1) reps(1000) ///
			seed(1001) strata(countyid) cluster(schid) ///
			hypadd(gains-levels;p4p-levels;p4p-gains)	
	
	
restore
	
/*---------------------------------------------------------------------------------*/

/*---------------------------------------------------------------------------------*/
/*APPENDIX TABLE 4: Impacts on Secondary Outcomes*/	

eststo clear
	foreach var of varlist $secondary_stu{
		eststo: xi: reg `var' $inc_design $base_covs $other_covs i.countyid, vce(cluster schid)
	}
	
	preserve
	collapse z_final_score t_makes_effort $inc_design $base_covs $other_covs control countyid schid, by(teachid)
	
		eststo: xi: reg t_makes_effort $inc_design $base_covs $other_covs, vce(cluster schid)	
	restore 
	
esttab using "`outdir'/AppTable4.csv", nolabel b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) keep($inc_design) replace


/*---------------------------------------------------------------------------------*/

/***************/
/****FIGURES****/
/***************/

/*---------------------------------------------------------------------------------*/
/*Figure 1: Distribution of Test Scores across Groups (Adjusted)*/


qui reg z_final_score $base_covs $other_covs i.countyid, vce(cluster schid)
predict e, resid
 
distplot line e, by(treatment4groups) midpoint ///
legend(label(1 Control) label(2 Levels) label(3 Gains) label(4 Pay-for-Pctile) cols(4)) ///
	ytitle("Cumulative share") xtitle("Residualized endline score") xlabel(-3(0.5)3) graphregion(color(white)) scheme(s2mono)
graph export "`outdir'/Figure1_all.pdf", replace
	
distplot line e if control == 1 | small == 1, by(treatment4groups) midpoint ///
legend(label(1 Control) label(2 Levels) label(3 Gains) label(4 Pay-for-Pctile) cols(4)) ///
	ytitle("Cumulative share") xtitle("Residualized endline score") xlabel(-3(0.5)3) graphregion(color(white)) scheme(s2mono)
graph export "`outdir'/Figure1_small.pdf", replace

distplot line e if control == 1 | big == 1, by(treatment4groups) midpoint ///
legend(label(1 Control) label(2 Levels) label(3 Gains) label(4 Pay-for-Pctile) cols(4)) ///
	ytitle("Cumulative share") xtitle("Residualized endline score") xlabel(-3(0.5)3) graphregion(color(white)) scheme(s2mono)
graph export "`outdir'/Figure1_large.pdf", replace
	
drop e	
/*---------------------------------------------------------------------------------*/

/*---------------------------------------------------------------------------------*/
/*Appendix Figure 1: Distribution of Test Scores across Groups (Unadjusted)*/
distplot line z_final_score, by(treatment4groups) midpoint ///
legend(label(1 Control) label(2 Levels) label(3 Gains) label(4 Pay-for-Pctile) cols(4)) ///
	ytitle("Cumulative share") xtitle("Normalized Endline Score") xlabel(-2.5(0.5)2.5) graphregion(color(white)) scheme(s2mono)
graph export "`outdir'/FigureA1.pdf", replace
/*---------------------------------------------------------------------------------*/

log close replication
