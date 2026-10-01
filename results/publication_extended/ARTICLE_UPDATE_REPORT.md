# Updated validation results for the manuscript

Date of verified rerun: 2026-10-02.

## 1. Status and changes relative to the publication-freeze calculation

The complete March--June and July--September workflows finished successfully. The rerun used an upper valid acid-flow limit of **12.0 m3/h** instead of 9.5 m3/h. All other process-mode thresholds, the maintenance-gap reset, temporal split dates, minimum-sample rules, laboratory targets, and reported tolerances were retained.

At prediction time, the conductivity input to each fitted physics-guided latent-property mapping is limited to the conductivity range observed in that model's training data. This is a training-only domain guard: it prevents unconstrained polynomial or PCHIP extrapolation and does not remove, alter, or use information from test targets.

The new calculation passed the following checks:

- both MATLAB entry points completed without errors;
- all 10 post-maintenance rolling windows satisfy the eligibility rule of at least 40 aligned training pairs and 10 common test pairs;
- `metrics_per_split.csv` contains the expected 74 rows;
- `heldout_predictions.csv` contains the expected 4,251 prediction rows;
- all reported numeric predictions and residuals are finite;
- the previous P09 spline failure is removed: the adapted physics-guided density predictions now range from 1.154 to 1.238 g/cm3 over the pooled rolling tests, with no nonphysical 10--150 g/cm3 predictions;
- the vector PDF and PNG versions of all three extended-validation figures were regenerated.

## 2. Dataset and validation counts to use in the manuscript

| Quantity | Updated value |
|---|---:|
| Process rows | 260,642 |
| Valid process rows after filtering | 225,114 |
| Complete laboratory pairs | 1,325 |
| Pre-maintenance laboratory pairs | 860 |
| Post-maintenance laboratory pairs | 465 |
| Strict external-test training pairs | 761 |
| Strict external-test test pairs | 438 |
| Eligible post-maintenance rolling windows | 10 of 10 |
| Pooled rolling test pairs | 357 |
| Temporal filter segments | 2 |

The maintenance gap remains `2026-06-06 -> 2026-07-07`, and all temporal filters reset across it.

### Exact post-maintenance rolling counts

| Split | Train interval | Test interval | Aligned train pairs | Common test pairs | Included |
|---|---|---|---:|---:|---|
| P01 | 07 Jul--21 Jul | 21 Jul--28 Jul | 68 | 42 | yes |
| P02 | 14 Jul--28 Jul | 28 Jul--04 Aug | 76 | 42 | yes |
| P03 | 21 Jul--04 Aug | 04 Aug--11 Aug | 84 | 34 | yes |
| P04 | 28 Jul--11 Aug | 11 Aug--18 Aug | 78 | 42 | yes |
| P05 | 04 Aug--18 Aug | 18 Aug--25 Aug | 78 | 25 | yes |
| P06 | 11 Aug--25 Aug | 25 Aug--01 Sep | 69 | 38 | yes |
| P07 | 18 Aug--01 Sep | 01 Sep--08 Sep | 68 | 39 | yes |
| P08 | 25 Aug--08 Sep | 08 Sep--15 Sep | 81 | 40 | yes |
| P09 | 01 Sep--15 Sep | 15 Sep--22 Sep | 81 | 28 | yes |
| P10 | 08 Sep--22 Sep | 22 Sep--29 Sep | 70 | 27 | yes |

The previous manuscript statement that only P01--P04 were eligible must be removed. P01--P10 now all contribute to the pooled metrics.

## 3. Selected physics-guided configurations

| Scenario | Lag | Averaging window | Mapping | Inner fit | Inner validation |
|---|---:|---:|---|---|---|
| March--June within-regime validation | 90 min | 60 min | PCHIP spline | 01 Mar--10 Mar | 10 Mar--15 Mar |
| March--June A-to-B transfer | 100 min | 30 min | quadratic | 07 May--16 May | 16 May--21 May |
| Extended pre-maintenance frozen model | 0 min | 60 min | quadratic | 23 May--01 Jun | 01 Jun--06 Jun |
| Extended post-maintenance adapted model | 140 min | 10 min | PCHIP spline | 07 Jul--16 Jul | 16 Jul--21 Jul |

## 4. Updated March--June benchmark

Fractions are on the 0--1 scale. Bias is prediction minus measurement.

| Scenario | Model | Splits | N test | RMSE MO | MAE MO | Bias MO | P95 MO | Within +/-0.03 | RMSE density | MAE density | Bias density | P95 density | Within +/-0.01 |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| A within | Physics-guided | 9 | 500 | 0.0340 | 0.0260 | -0.0078 | 0.0700 | 0.604 | 0.0112 | 0.0087 | +0.0021 | 0.0216 | 0.636 |
| A within | Ridge | 9 | 500 | 0.0155 | 0.0114 | -0.0016 | 0.0300 | 0.914 | 0.0085 | 0.0063 | +0.0003 | 0.0155 | 0.832 |
| A within | Physics-only | 9 | 500 | 0.1055 | 0.1005 | +0.1000 | 0.1500 | 0.020 | 0.0841 | 0.0837 | -0.0837 | 0.0957 | 0.000 |
| A within | Gradient boosting | 9 | 500 | 0.0171 | 0.0130 | -0.0075 | 0.0300 | 0.884 | 0.0111 | 0.0086 | -0.0065 | 0.0194 | 0.626 |
| A to B | Physics-guided | 1 | 56 | 0.0320 | 0.0263 | -0.0152 | 0.0500 | 0.500 | 0.0191 | 0.0166 | +0.0158 | 0.0319 | 0.304 |
| A to B | Ridge | 1 | 56 | 0.0170 | 0.0132 | +0.0093 | 0.0300 | 0.875 | 0.0130 | 0.0106 | +0.0082 | 0.0229 | 0.536 |
| A to B | Physics-only | 1 | 56 | 0.0966 | 0.0913 | +0.0913 | 0.1500 | 0.018 | 0.0877 | 0.0871 | -0.0871 | 0.1008 | 0.000 |
| A to B | Gradient boosting | 1 | 56 | 0.0174 | 0.0136 | +0.0039 | 0.0370 | 0.911 | 0.0134 | 0.0110 | -0.0040 | 0.0245 | 0.536 |

The training-range guard materially changes the physics-guided A-to-B result: RMSE decreases from 0.0966 to 0.0320 for molar ratio and from 0.0588 to 0.0191 g/cm3 for density. This result should be described together with the guard and not presented as an unchanged production model.

## 5. Updated strict external validation

The strict external experiment fits and selects all models using pre-maintenance data only, then tests on `2026-07-07 -> 2026-09-29`. No post-maintenance laboratory targets are used for fitting or hyperparameter selection.

| Model | N train | N test | RMSE MO | MAE MO | Bias MO | P95 MO | Within +/-0.03 | RMSE density | MAE density | Bias density | P95 density | Within +/-0.01 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Physics-guided frozen | 761 | 438 | 0.1795 | 0.1524 | -0.1472 | 0.3100 | 0.066 | 0.0456 | 0.0401 | +0.0400 | 0.0787 | 0.043 |
| Ridge frozen | 761 | 438 | 0.0286 | 0.0182 | -0.0096 | 0.0400 | 0.731 | 0.0141 | 0.0114 | +0.0103 | 0.0272 | 0.495 |
| Physics-only | 0 | 438 | 0.1254 | 0.0992 | -0.0519 | 0.2400 | 0.199 | 0.0587 | 0.0564 | -0.0563 | 0.0799 | 0.000 |
| Gradient boosting frozen | 761 | 438 | 0.0288 | 0.0186 | -0.0107 | 0.0400 | 0.724 | 0.0128 | 0.0094 | +0.0039 | 0.0255 | 0.653 |

The best strict-external molar-ratio RMSE is obtained by ridge regression (0.0286). The best strict-external density RMSE is obtained by gradient boosting (0.0128 g/cm3). The physics-guided frozen model shows substantial post-maintenance bias and does not outperform the statistical baselines in this experiment.

## 6. Updated pooled post-maintenance rolling comparison

The table pools the non-overlapping held-out test portions of P01--P10. Frozen and adapted models are evaluated on identical test pairs within each split.

| Model | Splits | N test | RMSE MO | MAE MO | Bias MO | P95 MO | Within +/-0.03 | RMSE density | MAE density | Bias density | P95 density | Within +/-0.01 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Physics-guided frozen | 10 | 357 | 0.1903 | 0.1678 | -0.1677 | 0.3165 | 0.028 | 0.0486 | 0.0442 | +0.0442 | 0.0795 | 0.008 |
| Ridge frozen | 10 | 357 | 0.0216 | 0.0170 | -0.0111 | 0.0400 | 0.739 | 0.0143 | 0.0119 | +0.0111 | 0.0277 | 0.462 |
| Physics-only | 10 | 357 | 0.1264 | 0.1016 | -0.0710 | 0.2400 | 0.182 | 0.0558 | 0.0536 | -0.0536 | 0.0738 | 0.000 |
| Gradient boosting frozen | 10 | 357 | 0.0219 | 0.0171 | -0.0112 | 0.0400 | 0.731 | 0.0126 | 0.0094 | +0.0045 | 0.0259 | 0.655 |
| Physics-guided adapted | 10 | 357 | 0.1549 | 0.1288 | +0.0090 | 0.2765 | 0.109 | 0.0222 | 0.0188 | +0.0011 | 0.0374 | 0.300 |
| Ridge adapted | 10 | 357 | 0.0197 | 0.0142 | -0.0007 | 0.0400 | 0.829 | 0.0134 | 0.0093 | +0.0051 | 0.0309 | 0.683 |
| Gradient boosting adapted | 10 | 357 | 0.0230 | 0.0177 | -0.0057 | 0.0500 | 0.745 | 0.0110 | 0.0088 | -0.0052 | 0.0221 | 0.650 |

Ridge adaptation gives the lowest pooled molar-ratio RMSE (0.0197) and the highest molar-ratio tolerance fraction (0.829). Gradient-boosting adaptation gives the lowest density RMSE (0.0110 g/cm3), while ridge adaptation gives the highest density tolerance fraction (0.683).

The physics-guided adapted model remains substantially less accurate for molar ratio than ridge and gradient boosting. The domain guard removes catastrophic extrapolation but does not make the physics-guided model the best-performing estimator.

## 7. Effect of the new domain guard

| Pooled adapted physics-guided metric | 12 m3/h, no guard | 12 m3/h, training-range guard |
|---|---:|---:|
| Test pairs | 357 | 357 |
| RMSE MO | 0.3528 | 0.1549 |
| RMSE density, g/cm3 | 11.1240 | 0.0222 |
| Maximum absolute MO error | greater than 1.0 in P09 | 0.40 |
| Maximum predicted density, g/cm3 | 152.24 | 1.238 |

The guard corrects a numerical extrapolation failure rather than removing difficult observations. P09 remains the weakest adapted physics-guided split (RMSE MO 0.2889; RMSE density 0.0297 g/cm3), and it remains included in the pooled result.

## 8. Required manuscript edits

1. Replace the acid-flow upper limit of 9.5 m3/h with **12.0 m3/h** in the preprocessing description.
2. Add the training-range domain guard to the physics-guided prediction method. State that the mapping input is saturated at the nearest training-domain boundary and that test targets are not used to determine the boundary.
3. Replace `760 training / 249 test pairs` in the strict external validation with **761 training / 438 test pairs**.
4. Replace `4 of 10 eligible windows, P01--P04` with **10 of 10 eligible windows, P01--P10**.
5. Replace `95 pooled test pairs` with **357 pooled test pairs**.
6. Replace the March--June benchmark and extended-validation metric tables with Sections 4--6 of this report.
7. Revise the results narrative: ridge and gradient boosting outperform the physics-guided model after maintenance; the physics-guided model demonstrates interpretability and the effect of domain control but not the lowest held-out error.
8. Replace the three extended-validation manuscript figures with the newly generated PDF or PNG versions.

## 9. Interpretation cautions

- Results for the 9.5 and 12.0 m3/h thresholds use different accepted test populations. Changes in pooled RMSE are therefore not paired estimates of improvement.
- The rolling training windows overlap, although their test intervals do not. Pooled metrics are descriptive and should not be described as independent-fold confidence estimates.
- The external test is the strongest evidence of deployment transfer because it uses no post-maintenance targets for fitting or hyperparameter selection.
- The training-range guard is a model change and must be disclosed explicitly in the methods section.
- The process historian ends on 29 September, while laboratory records continue into 1 October; the later laboratory observations cannot be evaluated.

## 10. Canonical files

- `results/publication/VALIDATION.md`: regenerated March--June validation.
- `results/publication/metrics_summary.csv`: March--June pooled metrics.
- `results/publication_extended/VALIDATION_EXTENDED.md`: regenerated external and rolling validation.
- `results/publication_extended/metrics_summary.csv`: extended pooled metrics.
- `results/publication_extended/metrics_per_split.csv`: all 74 per-split/model rows.
- `results/publication_extended/heldout_predictions.csv`: all 4,251 held-out predictions.
- `paper/figures/fig_extended_validation_timeline.pdf` and `.png`.
- `paper/figures/fig_extended_transfer_timeseries.pdf` and `.png`.
- `paper/figures/fig_extended_adaptation_comparison.pdf` and `.png`.
