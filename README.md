# Physics-Guided Soft Sensing under Sparse Laboratory Measurements and Temporal Regime Shifts in Industrial Monoammonium Phosphate Production

This repository accompanies a study of a physics-guided soft sensor for estimating molar ratio and solution density from sparse laboratory measurements and process telemetry. The code implements gap-aware preprocessing, material-balance features, chronological model selection, rolling-origin validation, and comparison with physics-only, Ridge, and gradient-boosting baselines.

## Data availability and confidentiality

The raw industrial historian exports and laboratory workbooks are confidential and are **not distributed**. No company, site, equipment, or internal signal identifiers are required by the public interface. The expected anonymized private inputs are documented in [`docs/DATA_REQUIREMENTS.md`](docs/DATA_REQUIREMENTS.md).

The repository does include de-identified derived validation tables and held-out predictions. These permit inspection of the reported evaluation but are not a substitute for the source data and cannot regenerate fitted models or figures by themselves.

## Repository structure

```text
run_publication_validation.m       March--June benchmark entry point
run_extended_validation.m          March--September external-validation entry point
src/                               preprocessing, alignment, and model code
scripts/publication/               publication validation workflow
results/publication/               canonical March--June derived results
results/publication_extended/      canonical extended derived results
paper/main.tex                     manuscript source
paper/arxiv/                       self-contained arXiv source package
paper/figures/                      four current vector manuscript figures
docs/DATA_REQUIREMENTS.md           private input contract
docs/REPRODUCIBILITY.md             frozen settings and audit notes
tests/test_public_release.py        data-free release and consistency checks
```

## Requirements

The analysis was validated with MATLAB R2025b. Exact reproduction requires:

- Signal Processing Toolbox for the implemented smoothing filter;
- Statistics and Machine Learning Toolbox for the LSBoost baseline;
- Parallel Computing Toolbox only for parallel acceleration (the workflow can fall back to serial execution);
- spreadsheet import support for the private `.xlsx` inputs.

The publication workflow requests a 24-worker process pool through a transient local-cluster configuration. Reduce `cfg.publication.parallel_workers` if the host cannot provide 24 workers; when Parallel Computing Toolbox is unavailable, configuration search runs serially.

## Reproducing the analyses

Place the four private workbooks under the ignored local directory `data/publication/` using the filenames and schema in [`docs/DATA_REQUIREMENTS.md`](docs/DATA_REQUIREMENTS.md). From the repository root, run:

```matlab
run_publication_validation
run_extended_validation
```

The first entry point rebuilds the March--June benchmark and its diagnostic vector PDFs under `results/publication/`. The second rebuilds the strict post-maintenance transfer test and post-maintenance rolling comparison under `results/publication_extended/` and exports the three analysis figures used by the manuscript to `paper/figures/`. PNG previews are intentionally not generated. If private inputs are absent, the entry points stop immediately with a message that points to the data contract.

With the confidential source files, the code can reproduce data counts, temporal splits, selected configurations, per-split and pooled metrics, held-out predictions, and analysis-generated figures. Without them, an external researcher can inspect all code, audit the committed derived CSV/Markdown outputs, run the data-free release checks, and compile the manuscript, but cannot refit the models or independently reconstruct the source measurements.

The canonical reports are:

- [`results/publication/VALIDATION.md`](results/publication/VALIDATION.md) for the March--June benchmark;
- [`results/publication_extended/VALIDATION_EXTENDED.md`](results/publication_extended/VALIDATION_EXTENDED.md) for the extended external validation.

The frozen seeds, search grids, validation domains, eligibility rules, training-domain guard, and leakage limitations are summarized in [`docs/REPRODUCIBILITY.md`](docs/REPRODUCIBILITY.md).

The corresponding directories contain `metrics_summary.csv`, `metrics_per_split.csv`, `heldout_predictions.csv`, split definitions, configuration-search results, selected configurations, and dataset counts. Generated files are written back to those same locations.

## Manuscript and citation

The manuscript source is [`paper/main.tex`](paper/main.tex), and `paper/arxiv/` contains the self-contained arXiv package. Citation metadata are provided in [`CITATION.cff`](CITATION.cff). Please cite the manuscript title above and the four listed authors; add a preprint or journal identifier only after one has been assigned.

Contact: [gkarnup@niime.ru](mailto:gkarnup@niime.ru)

## License status

No repository license has been selected. Until the authors add one, copyright law reserves reuse rights beyond those granted by the hosting service. The arXiv deposit license is a separate author decision and does not license this code repository.
