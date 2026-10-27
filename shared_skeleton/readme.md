# Shared resources

Databases, reference genomes and exported environments used by more than one investigation.

- `databases/<name>/<version>/`: each with `readme.md` (from `databases/readme_template.md`) and `md5sums.txt`.
- `references/<organism>/<accession>/`: reference sequences and annotation, with `md5sums.txt`.
- `envs/`: exported conda environment `.yml` files.

Make each version read-only once checked: `chmod -R a-w <dir>`.
