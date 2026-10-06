# Teacher Effort Model

Computes teachers' effort choices in a two-teacher tournament from its first-order
conditions, with optional estimation on control-group data. Requires MATLAB R2021a
or later with the Optimization Toolbox.

## Run

In MATLAB, set the working directory to the repository root and run:

```matlab
run('model/paybydesign_stochastic.m')
```

- The default illustration uses preset parameters and needs no data.
- To add control-group estimation, first run
  [Percentile_calculation.do](../description/readme.md#run) to create
  `data/derived/teacher_with_incentive.csv`. Then set `run_control = true` near the
  top of [paybydesign_stochastic.m](paybydesign_stochastic.m) and run the command
  again. The illustration still uses its preset parameters.
- `run_all.do` runs the same script in batch mode and saves the same outputs. If that
  stage fails, see [If something fails](../README.md#if-something-fails).

## Outputs

Results go to `output/model/`. Printed results and solver diagnostics, including the
optional estimation, go to `output/logs/model.log`.

| Results | Files |
| --- | --- |
| Effort solutions | `effort_solutions.csv` |
| Response curves | `teacher1_response.csv`, `teacher2_response.csv`, `teacher1_response.pdf`, `joint_response.pdf` |
| Illustration arrays | `model_results.mat` |

## Notes

These are exploratory results. The script checks interior first-order conditions; it
does not establish global optimality or a Nash equilibrium.