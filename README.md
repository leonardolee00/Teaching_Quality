# Health, Migration and Agricultural Underperformance: Simulation Code

This project comes from my extended essay for EC428 Development and Growth at the London
School of Economics ([essay](paper/essay.pdf)). It asks why agriculture can stay weak even
when rural health improves.

In the model, better health makes people more productive, both on the farm and off it, and
makes moving to non-farm work cheaper. Each household decides which of its members leave
the farm. A health improvement can therefore raise household income while the healthiest
workers leave, so that total farm output falls. The code solves every household's choice
exactly, then repeats the experiment for four kinds of health or mobility improvements over
960 parameter vectors.

| Part | What it does |
| --- | --- |
| [Household model](model/readme.md) | Solves each household's migration choice exactly, and checks the solver before anything else runs. |
| [Simulations](simulation/readme.md) | Runs the essay's experiments: a baseline health shock, the parameter-region grid and robustness checks. |
| [Tables and figures](analysis/readme.md) | Makes the essay's simulation tables and figures. |

## Requirements

Stata 17 or later. No user-written packages and no data downloads: the households are
simulated, and the draws used by default are included.

## Quick start

1. Choose the settings at the top of [run_all.do](run_all.do). `1` means yes and `0` means no.

```stata
   local run_simulation = 1
   local quick_test = 0
   local new_households = 0
```

2. In Stata, move to the project folder and run the pipeline:

```stata
   cd "path/to/project"
   do run_all.do
```

For a first try, set `quick_test = 1`: the same pipeline runs on a smaller sample.

## What runs

| Setting | Households (baseline / grid) | Parameter-shock runs |
| --- | ---: | ---: |
| Default | 10,000 / 1,000 | 23,040 (960 parameter vectors × 24 shocks) |
| `quick_test = 1` | 500 / 250 | 768 (32 × 24) |

- The model checks always run first. If the solver fails a check, nothing else runs.
- `run_simulation = 0` skips the simulations and remakes the tables and figures from the
  datasets already in `data/derived/`.
- `new_households = 1` draws a new set of households in Stata, using `seed`. By default the
  code uses the saved draws in `data/simulated/`, so every machine gets the same results.

The full run takes about 2 minutes and the quick test a few seconds (StataMP 17 on a
Windows laptop). The run time is printed at the end of `output/logs/run_all.log`.

## Where files go

Paths are relative to the project folder; output folders are created automatically.

| Folder | Contents |
| --- | --- |
| `data/simulated/` | The simulated households used by default |
| `data/benchmark/` | Test households and known results for the model checks |
| `data/derived/` | Simulation datasets created by the run |
| `output/tables/` | Six tables, each as CSV and as LaTeX |
| `output/figures/` | Nine figures (PDF) |
| `output/logs/` | The run log |

Rerunning a stage overwrites its outputs.

## Results and the essay

The households in the essay's original simulations were not saved, so the households here
are new draws from the same distributions. The results are therefore close to, but not
identical with, the numbers in the essay. Before the shock, for example, 50.7% of household
members migrate (essay: 50.8%), and the core mechanism holds in 95.4% of the 23,040
parameter-shock runs (essay: 95.1%). `output/tables/essay_comparison.csv` lists the headline
results next to the essay's, and the [simulation notes](simulation/readme.md#how-runs-are-compared)
define every outcome.

## If something fails

- A wrong working directory or a missing input file stops the run before any stage starts,
  with a message saying what to do.
- Otherwise the runner stops at the first failing stage and names it. The full log is
  `output/logs/run_all.log`.

## Credits

Research, model and essay by Leo (Guanlin) Li. As the essay discloses, AI assistants
supported the coding; this Stata version was also written with AI coding assistance.
