# Replication

Reproduces main Tables 2–6, Appendix Tables 1–5 and the four score-distribution figures of
Loyalka et al. (2019). The script adapts the authors' analysis code (Prashant Loyalka and
Sean Sylvia), with additional exhibits by Leo (Guanlin) Li. The bundled Romano–Wolf routine,
[kfwebs.ado](kfwebs.ado), keeps its author's credit (Soledad Giardili).

## Run

Set up the data and packages as in the [project setup](../README.md#quick-start), including
`distplot` and `svmat2`. From the repository root, run:

```stata
do replication/Pay_by_design_JOLE_edited.do
```

It reads `data/raw/Pay_by_Design_JOLE.dta`, does not depend on the other stages, and takes
about 7 hours, almost all of it bootstrap replications.

## Outputs

Tables and figures go to `output/replication/`; the log, including the Romano–Wolf results,
goes to `output/logs/replication.log`.

| Exhibit | Files |
| --- | --- |
| Main tables | `Table2.csv`, `Table3.tex`, `Table4.csv`, `Table5.csv`, `Table6.tex`, `Table6_controls.tex` |
| Appendix tables | `AppTable1.csv`, `AppTable2.csv`, `AppTable3.csv`, `AppTable4.csv`, `AppTable5.tex`, `AppTable5_even.tex` |
| Figure 1 (adjusted scores) | `Figure1_all.pdf`, `Figure1_small.pdf`, `Figure1_large.pdf` |
| Appendix Figure 1 (unadjusted scores) | `FigureA1.pdf` |

## Reading the outputs

- `AppTable5.tex` and `AppTable5_even.tex` are the odd and even columns of Appendix Table 5;
  the even columns add the student, family, class and teacher controls (`$other_covs`).
  `Table6_controls.tex` repeats Table 6 with those controls, which the paper's Table 6 omits.
- `Table6.tex` is transposed relative to the paper: columns are the three tercile variables
  (the paper's panels); rows are each incentive's middle-vs-bottom, top-vs-bottom and
  top-vs-middle differences (the paper's columns).
- In `AppTable4.csv` the teacher-level effort regression is the last column; in the paper it
  is column 11.
- Stars in `Table2.csv`, `Table4.csv`, `AppTable3.csv` and `AppTable4.csv` use conventional
  p-values; the paper's are Romano–Wolf adjusted. The adjusted results for Tables 2 and A3
  are in `replication.log`; the code does not compute them for Tables 4 and A4.