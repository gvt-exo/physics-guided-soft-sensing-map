# Manuscript figures

`paper/main.tex` is the single source of truth for the manuscript. The main text now uses only four figures.

## Figures used in the manuscript

1. `fig_extended_validation_timeline.pdf`
   - purpose: complete March–September process/laboratory coverage and maintenance gap;
   - before public release:
     - replace any internal signal tag such as `D420` with `Conductivity signal`;
     - use `Maintenance outage` / `Post-maintenance data begin` rather than internal plant wording;
     - verify the density axis is plotted and labeled in g cm^-3 with the physical scale shown directly (not a ×1000/secondary-axis mismatch);
     - use dark, publication-readable title/annotations.

2. `soft_sensor_architecture.pdf`
   - purpose: physics-guided soft-sensor architecture and calibration/validation workflow;
   - must be supplied by the authors before final compilation;
   - English labels only in the public manuscript;
   - no company, site, equipment, or internal tag identifiers.

3. `fig_extended_adaptation_comparison.pdf`
   - purpose: frozen-versus-adapted post-maintenance RMSE comparison;
   - before public release: increase title/annotation contrast if needed and keep the normalized tolerance labels readable at journal column width.

4. `fig_extended_transfer_timeseries.pdf`
   - purpose: post-maintenance frozen-versus-adapted physics-guided predictions and residuals;
   - before public release: increase title/annotation contrast if needed and verify all axis units remain readable after scaling.

## Legacy figures

The following files may remain in the repository for audit/history but are no longer referenced by `paper/main.tex`:

- `fig_predicted_vs_measured.*`
- `fig_holdout_timeseries.*`
- `fig_baseline_comparison.*`
- previous pre-repair data-regime/sparse-sampling plots.

Do not include legacy figures in the final arXiv upload unless they are moved to Supporting Information and regenerated from the final filtered dataset.

Prefer vector PDF for manuscript figures. PNG copies may be retained only as previews.
