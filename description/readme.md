# Descriptive Analysis

Reconstructs each school's performance measure and bonus under the experiment's
incentive schemes, then summarizes students, teachers and schools by treatment arm.

## Run

Set up the data and Stata packages as in the [project setup](../README.md#quick-start).
From the repository root, run the two scripts in order:

```stata
do description/Percentile_calculation.do
do description/Describe_data.do
```

`Percentile_calculation.do` reads `data/raw/Pay_by_Design_JOLE.dta`.
`Describe_data.do` reads `data/derived/teacher_with_incentive.dta`, which the first
script writes.

## Outputs

| Folder | Files |
| --- | --- |
| `data/derived/` | `levels_teacher_bonus.dta`, `gains_teacher_bonus.dta`, `p4p_teacher_bonus.dta`, `control_teacher_bonus.dta`, `combined_teacher_data.dta`, `teacher_with_incentive.dta`, `teacher_with_incentive.csv` |
| `output/descriptive/` | `summary_student.tex`, `summary_teacher.tex`, `coverage_and_scores.pdf`, `Treat_dist_byschid_rea.xlsx` (school counts by prefecture and treatment cell) |

## Notes

- Bonuses are reconstructed from the paper's reward rule, not taken from payment records.
- Construction and sample rules are documented in the headers of
  [Percentile_calculation.do](Percentile_calculation.do) and
  [Describe_data.do](Describe_data.do).
- `teacher_with_incentive.csv` is the input for the model's optional control-group
  estimation.
- The coverage–score figure shows school-level associations, not treatment effects.