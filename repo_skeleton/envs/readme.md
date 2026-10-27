# Environments

One exported conda environment per module or tool group: `conda env export --no-builds -n <env> > envs/<module>.yml`. `tools/new_run.sh` also exports the active environment into every run directory.
