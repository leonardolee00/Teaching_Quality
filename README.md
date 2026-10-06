# Teacher Incentives and Teaching Quality

This project comes from my work as a research assistant for Professor Juan Pantano at the
University of Hong Kong. 

It builds on [Loyalka et al. (2019), "Pay by Design"](https://www.journals.uchicago.edu/doi/10.1086/702625),
a randomized trial of teacher performance pay in western China. The replication adapts the
authors' analysis code (Prashant Loyalka and Sean Sylvia) and adds exhibits of my own; the
reconstruction of incentive measures, the descriptive analysis and the structural model of
teacher effort are my own work.

| Part | What it does |
| --- | --- |
| [Descriptive analysis](description/readme.md) | Reconstructs each school's performance measure and bonus, then summarizes students, teachers and schools. |
| [Replication](replication/readme.md) | Reproduces the paper's main and appendix tables and its score-distribution figures. |
| [Teacher effort model](model/readme.md) | Computes effort choices in a two-teacher tournament in MATLAB, with optional estimation on control-group data. |

## Requirements

- Stata 15 or later with `estout`.
- For the replication: `distplot`, and `svmat2`, which the included `kfwebs.ado` calls.
- For the model: MATLAB R2021a or later with the Optimization Toolbox.

## Quick start

1. Download `Pay_by_Design_JOLE.dta` from the paper's
   [supplementary materials](https://www.journals.uchicago.edu/doi/10.1086/702625#supplementary-materials)
   and save it in a new folder, `data/raw/` (the data are not included here).
2. Install the Stata packages:

```stata
   ssc install estout
   * Replication only:
   ssc install distplot
   net install dm79, from(http://www.stata.com/stb/stb56)
```

3. Choose the stages at the top of [run_all.do](run_all.do). `1` runs a stage and `0` skips
   it; data construction and the descriptive analysis always run.

```stata
   local run_replication = 0
   local run_model = 1
   local matlab_exe "matlab"
```

4. In Stata, move to the repository root and run the pipeline:

```stata
   cd "path/to/repository"
   do run_all.do
```

## What runs, and how long

- Defaults (`run_replication = 0`, `run_model = 1`): data construction, the descriptive
  analysis and the MATLAB model, in about a minute.
- `run_replication = 1` adds the full replication: about 7 hours, almost all of it bootstrap
  replications.
- `run_model = 0` skips MATLAB, for a Stata-only run.

Times are from the last full run: Stata 18 and MATLAB R2024b on Windows 11. 

On Windows, the
model runs in a blank Command Prompt window that closes by itself when it finishes; leave it
open until then.

## Where files go

Paths are relative to the repository root; output folders are created automatically.

| Folder | Contents |
| --- | --- |
| `data/raw/` | The original dataset, supplied by you |
| `data/derived/` | Reconstructed incentive datasets, including the CSV used by the model |
| `output/descriptive/` | Summary tables, school counts and the coverage–score figure |
| `output/replication/` | Replicated tables and figures |
| `output/model/` | Model solutions and response-curve figures |
| `output/logs/` | Run logs and model diagnostics |

Rerunning a stage overwrites its outputs; a skipped stage keeps its earlier ones. The
`output/descriptive/` and `output/model/` files in this repository come from the last full run.

## If something fails

- A wrong working directory, missing data or a missing package stops the run before any
  stage starts, with a message saying what to do.
- Otherwise the runner stops at the first failing stage and names it. The full log is
  `output/logs/run_all.log`.
- If the MATLAB stage fails, the runner prints `output/logs/model_launch.log`. If MATLAB was
  not found, set `matlab_exe` in `run_all.do` to its full path, which this returns in MATLAB:

```matlab
  fullfile(matlabroot, 'bin', 'matlab.exe')   % Windows
  fullfile(matlabroot, 'bin', 'matlab')       % macOS
```
