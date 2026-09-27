---
title: "Physics-Guided Soft Sensing under Sparse Laboratory Measurements in Industrial Monoammonium Phosphate Production"
article_type: "Original Article"
primary_target: "Digital Chemical Engineering"
compatible_targets:
  - "Computers & Chemical Engineering"
  - "Industrial & Engineering Chemistry Research (Process Systems Engineering)"
status: "Working preprint draft — complete the items marked [TO COMPLETE] before public posting"
---

# Physics-Guided Soft Sensing under Sparse Laboratory Measurements in Industrial Monoammonium Phosphate Production

**[Author 1]\(^a\), [Author 2]\(^a\), [Author 3]\(^b\), ...**

\(^a\) [Affiliation 1]  
\(^b\) [Affiliation 2]  
\* Corresponding author: [name, e-mail]

> **Draft note.** The manuscript below is deliberately written as a journal-compatible preprint rather than as a technical report. It uses only results currently supported by the project technical specification and R&D report. Items that require additional calculations, source-data reconciliation, figures, or formal approval are marked **[TO COMPLETE]** and are also collected in the companion checklist.

## Highlights

- Physics-guided soft sensing reconstructs sparse MAP quality measurements.
- One-minute plant telemetry is fused with laboratory data sampled every 2–8 h.
- Operating-regime shifts cause measurable bias changes in virtual sensing.
- Data quality is the main current limitation to deployment as decision support.

## Graphical abstract / TOC graphic concept

**[TO COMPLETE — FIGURE GA]** A compact left-to-right scheme:

`1-min plant telemetry → quality screening + time alignment → latent acid properties → material-balance soft sensor → virtual molar ratio & density → 10-min operator decision support`

Show sparse laboratory samples entering the calibration block from above and a regime-shift marker on the telemetry stream. For an I&EC Research submission, prepare the final TOC graphic at the journal-required aspect and size.

## Abstract

Industrial chemical plants often generate high-frequency process telemetry while key quality variables are available only from intermittent laboratory measurements. This study develops a physics-guided soft sensor for monoammonium phosphate production that combines one-minute plant telemetry, sparse laboratory references, low-order empirical mappings for latent phosphoric-acid properties, and material-balance calculations. The dataset covers 1 March–6 June 2026 and contains 139,681 telemetry records and 860 laboratory records; 121,414 and 767 records, respectively, passed quality screening. An abrupt conductivity shift on 21 May created two distinct operating regimes. On the combined development dataset, the model achieved RMSE values of 0.0358 for molar ratio and 0.0113 g cm\(^{-3}\) for solution density, with 53.7% and 65.12% of estimates within the specified tolerances. Error patterns and bias changes across regimes show that data quality and nonstationarity currently limit deployment. The results support virtual telemetry as an industrial decision-support layer while motivating regime-aware validation and improved measurement quality.

**Keywords:** soft sensor; virtual sensor; hybrid modeling; process monitoring; industrial digitalization; monoammonium phosphate

## Nomenclature

| Symbol | Definition | Unit |
|---|---|---|
| \(c\) | phosphoric-acid conductivity measurement | [TO VERIFY unit] |
| \(Q_A\) | clarified phosphoric-acid volumetric flow | m\(^3\) h\(^{-1}\) |
| \(\dot m_N\) | ammonia mass flow to the tubular reactor | kg h\(^{-1}\) |
| \(Q_W\) | process-water volumetric flow | m\(^3\) h\(^{-1}\) |
| \(w_{P_2O_5}\) | mass fraction of \(P_2O_5\) in the acid stream | fraction or % |
| \(\rho_A\) | phosphoric-acid density | kg m\(^{-3}\) |
| \(R\) | \(NH_3/H_3PO_4\) molar ratio | dimensionless |
| \(\rho_M\) | solution density in the downstream vessel | g cm\(^{-3}\) |
| \(M_i\) | molar mass of component \(i\) | g mol\(^{-1}\) |
| \(\tau\) | time lag between process telemetry and laboratory reference | min |
| \(W\) | aggregation window around a laboratory reference | min |
| MAE | mean absolute error | variable-dependent |
| RMSE | root mean squared error | variable-dependent |
| P95 | 95th percentile of absolute error | variable-dependent |

# 1. Introduction

Chemical-process plants increasingly collect large volumes of online measurements through distributed control, manufacturing execution, and laboratory information systems. However, the variables that most directly describe product quality are frequently unavailable at the same temporal resolution as process telemetry. They may require laboratory analysis, manual sampling, or instruments that are expensive or impractical to deploy at every relevant process location. Soft sensors address this mismatch by using continuously available measurements to infer hard-to-measure quality variables between direct observations (Kadlec et al., 2009; Souza et al., 2016).

Industrial deployment is more difficult than benchmark soft-sensor development. Real plant data contain missing values, sensor faults, short transients, asynchronous sampling, process-mode changes, and uncertain reference measurements. These conditions can degrade nominally accurate models after deployment and often make data preparation and maintenance as important as model class selection (Kadlec et al., 2009; Offermans et al., 2024; Dai et al., 2025). Recent work has therefore emphasized hybrid and physics-guided modeling, in which empirical relationships are embedded in or constrained by process knowledge rather than learned as unconstrained mappings (Sansana et al., 2021; Bradley et al., 2022; Schweidtmann et al., 2024; Mousa et al., 2025).

Soft sensing is also increasingly treated as an enabling layer for process digitalization rather than as an isolated regression task. Industrial examples combine process knowledge, data analytics, online monitoring, and decision support to construct virtual measurements from existing sensing infrastructure (Hamid et al., 2022; Pietrasik et al., 2024; Boskabadi et al., 2025). Recent industrial studies have explicitly addressed sparse quality sampling, interpretability, transfer between operating conditions, concept drift, and lifecycle management of deployed soft sensors (Kay et al., 2024; Metcalfe et al., 2025; Fricz et al., 2026).

Fertilizer production is a relevant case because composition and neutralization variables strongly affect product quality while several feed and intermediate-state properties are not measured continuously. Hybrid soft sensing has previously been demonstrated for nutrient-content estimation in compound-fertilizer production (Fu et al., 2007). The present study therefore does not claim novelty from applying soft sensing to fertilizer production alone. Instead, it focuses on a specific industrial monoammonium phosphate (MAP) process in which: (i) plant telemetry is sampled every minute while reference quality measurements are obtained only every 2–8 h; (ii) two important phosphoric-acid properties are latent during normal operation; (iii) the available plant data contain substantial missingness, outliers, and sensor nonstationarity; and (iv) a pronounced operating-regime change occurs within the study interval.

The objective is to construct and evaluate a physics-guided virtual-telemetry layer for estimating the \(NH_3/H_3PO_4\) molar ratio and downstream solution density from existing plant data. The scientific questions are:

1. Can sparse laboratory measurements be combined with one-minute plant telemetry and material-balance constraints to produce useful virtual measurements of MAP process quality?
2. How strongly do data quality and operating-regime changes affect soft-sensor error?
3. Can the resulting virtual measurements support an operator-facing decision-support layer without claiming closed-loop control readiness?

The main contributions are an industrial multi-rate case study, a low-complexity hybrid architecture that reconstructs latent feed properties before applying process balances, an explicit analysis of regime-dependent error, and a practical separation between soft sensing and downstream operator recommendations.

# 2. Industrial process and data

## 2.1. Process description

The investigated process is part of an industrial MAP production line. Clarified phosphoric acid is transferred from an upstream acid source to an intermediate vessel and then supplied to a tubular reactor. Ammonia is introduced for neutralization and process water is adjusted to influence downstream solution density. The principal reaction is represented in simplified form as

\[
NH_3 + H_3PO_4 \rightarrow NH_4H_2PO_4.
\tag{1}
\]

The reactor product is collected in a downstream vessel in which the two principal quality variables considered in this work are the \(NH_3/H_3PO_4\) molar ratio \(R\) and solution density \(\rho_M\). The operational targets used in the project were

\[
R_{\mathrm{target}} = 1.06,
\qquad
\rho_{M,\mathrm{target}} = 1.21\ \mathrm{g\,cm^{-3}}.
\tag{2}
\]

The corresponding reference measurements were available from laboratory/operator records rather than at the one-minute frequency of the process historian. Two phosphoric-acid properties required by the process calculations—the \(P_2O_5\) mass fraction and acid density—were not continuously available with sufficient reliability during the study. They were therefore treated as latent variables and reconstructed during model calibration.

**[TO COMPLETE — FIGURE 1]** Redraw the process diagram as a publication-quality schematic containing only the equipment and variables relevant to the paper: acid feed, intermediate tank, tubular reactor, ammonia and water feeds, downstream sampling vessel, online telemetry, and laboratory reference measurements. Remove internal UI notes, unresolved tag comments, and commercially sensitive plant identifiers.

## 2.2. Data sources and sampling structure

The study interval was 1 March–6 June 2026. The process dataset combined high-frequency plant telemetry, sparse laboratory reference measurements, and daily production records.

| Data source | Variables used | Sampling / count | Role |
|---|---|---:|---|
| Plant telemetry | acid flow, ammonia flow, water flow, acid conductivity; selected downstream flows for production estimate | 139,681 one-minute records; 121,414 passed joint validity screening | soft-sensor inputs |
| Laboratory / operator reference data | molar ratio and solution density | 860 records, typically every 2–8 h; 767 passed screening | calibration/reference targets |
| Production records | daily MAP output | 92 daily values | exploratory downstream validation |
| Substitute historical density values | three downstream stream densities | fixed averages from April 2025 where contemporaneous sensors were unavailable | exploratory production-balance calculation |

The joint process-data screening retained approximately 86.9% of one-minute records, while approximately 89.2% of laboratory records were retained. A laboratory record was accepted only when it passed its own plausibility checks and sufficient valid process observations were available around the reference time.

The laboratory and process measurements are intrinsically multi-rate. A single laboratory value may correspond to material that passed through the upstream process tens of minutes or hours earlier. The development procedure therefore treated time lag and aggregation window as model-selection parameters rather than assuming synchronous sampling.

## 2.3. Data-quality limitations

The source data contained several characteristics typical of industrial historian data:

- noisy process signals;
- short spikes and dropouts in flow measurements;
- missing and invalid values;
- periods with incomplete time-series coverage;
- operating-regime changes;
- nonfunctioning sensors for selected downstream density measurements;
- possible inconsistencies among laboratory logs, plant-system exports, dispatcher records, and technical reports.

These issues are not treated as incidental preprocessing details. They define the practical domain of applicability of the virtual sensor because the target tolerance for the predicted variables is of the same order as, or smaller than, the uncertainty introduced by some input measurements.

## 2.4. Operating-regime shift

The acid-conductivity signal exhibited a pronounced abrupt shift on 21 May 2026. The development report consequently separated the data into two periods:

- **Regime A:** 1 March–20 May, conductivity level approximately 20 in the project scale;
- **Regime B:** 21 May–6 June, conductivity level approximately 10 in the project scale.

A model was also evaluated on the combined interval. This natural regime change provides a useful industrial test of nonstationarity: changes in model bias across the two periods indicate whether a single global calibration can remain stable when the relationship between conductivity and latent feed properties changes.

**[TO COMPLETE — FIGURE 2]** Plot conductivity and the three principal manipulated/measured flows across the full study period. Mark 21 May and show valid/invalid segments. This figure should make the regime shift and data-quality problem visible before any model results are presented.

# 3. Methodology

## 3.1. Signal validation and preprocessing

The online variables entering the soft-sensor layer were acid conductivity \(c\), acid flow \(Q_A\), ammonia flow \(\dot m_N\), and water flow \(Q_W\). The project specification defined process-specific plausibility limits, outlier removal, active-channel selection for redundant ammonia-flow measurements, and rejection of any calculation step for which required inputs were missing, nonnumeric, negative where physically impossible, or outside permitted operating ranges.

The processing sequence was:

1. read the process measurements at their native one-minute sampling interval;
2. select the active ammonia-flow channel;
3. remove or invalidate short abnormal excursions according to process-specific rules;
4. apply range checks;
5. construct valid multi-channel timestamps only when all required inputs are simultaneously valid;
6. align process windows with laboratory reference timestamps using candidate lags and aggregation windows.

No online retraining was planned during normal operation. Model identification and calibration were performed offline and the selected parameterization was then intended to be fixed for deployment until a controlled recalibration.

**[TO COMPLETE — TABLE S1 / Methods text]** Reconcile the exact outlier-duration rule and final validity thresholds between the technical specification and implementation logs before release.

## 3.2. Time alignment of telemetry and laboratory measurements

For each laboratory observation at time \(t_j\), candidate process windows were constructed with lag \(\tau\) and window length \(W\). The project specification searched

\[
\tau \in \{0,10,\ldots,180\}\ \mathrm{min}
\tag{3}
\]

and

\[
W \in \{10,20,30,60\}\ \mathrm{min}.
\tag{4}
\]

Process observations in the selected window were aggregated to obtain the model inputs associated with the laboratory sample. Linear, quadratic, and piecewise-cubic Hermite interpolation (PCHIP) relationships were considered for the empirical latent-variable mappings.

The development report identified different time-alignment settings in the two operating regimes: \(\tau=180\) min and \(W=60\) min for Regime A, \(\tau=20\) min and \(W=20\) min for Regime B, and \(\tau=50\) min and \(W=60\) min for the combined dataset. The large difference in selected lag is itself evidence that a single stationary model may not adequately represent both periods.

## 3.3. Physics-guided latent-variable reconstruction

The soft sensor was structured as a grey-box model rather than as a direct black-box regression from all telemetry channels to both outputs. Conductivity was first mapped to the latent \(P_2O_5\) fraction,

\[
\widehat{w}_{P_2O_5}=f_{\theta}(c),
\tag{5}
\]

and the resulting composition estimate was mapped to phosphoric-acid density,

\[
\widehat{\rho}_{A}=g_{\phi}\!\left(\widehat{w}_{P_2O_5}\right),
\tag{6}
\]

where \(f_\theta\) and \(g_\phi\) were selected from low-order linear, quadratic, and PCHIP candidates.

These latent estimates were then inserted into material-balance calculations. The phosphoric-acid mass flow is

\[
\dot m_A=\widehat{\rho}_A Q_A.
\tag{7}
\]

The estimated \(P_2O_5\) mass flow is

\[
\dot m_{P_2O_5}=\dot m_A \widehat{w}_{P_2O_5}.
\tag{8}
\]

Using the stoichiometric conversion factor employed in the project specification,

\[
\dot m_{H_3PO_4,100\%}=1.38\,\dot m_{P_2O_5}.
\tag{9}
\]

The corresponding molar flows are

\[
\dot n_{H_3PO_4}=
\frac{\dot m_{H_3PO_4,100\%}}{M_{H_3PO_4}},
\qquad
\dot n_{NH_3}=
\frac{\dot m_N}{M_{NH_3}},
\tag{10}
\]

with \(M_{H_3PO_4}=98\) g mol\(^{-1}\) and \(M_{NH_3}=17\) g mol\(^{-1}\). The virtual molar ratio is then

\[
\widehat{R}=
\frac{\dot n_{NH_3}}{\dot n_{H_3PO_4}}.
\tag{11}
\]

The second soft-sensor output, downstream solution density \(\widehat{\rho}_M\), was obtained from the project material-balance model using the acid, ammonia, and water streams together with the reconstructed acid properties.

**[TO COMPLETE — EQUATION 12]** Insert the exact implemented density equation after a dimensional-consistency audit. The current technical specification contains a shorthand density expression that is insufficiently defined for publication and should not be reproduced without reconciliation with the source code/calculation workbook.

This two-stage architecture preserves a direct physical interpretation: the data-driven part estimates missing feed properties, while the process model propagates them to the quality variables of interest.

## 3.4. Model selection and error metrics

Candidate lag, window, and nonlinearity configurations were compared using errors between virtual and laboratory measurements. The reported metrics were MAE, RMSE, bias, P95 absolute error, and the fraction of observations within the project tolerances:

\[
|R-\widehat{R}| \le 0.03
\tag{12}
\]

and

\[
|\rho_M-\widehat{\rho}_M| \le 0.01\ \mathrm{g\,cm^{-3}}.
\tag{13}
\]

For a target variable \(y_i\) and estimate \(\hat y_i\),

\[
\mathrm{MAE}=\frac{1}{n}\sum_{i=1}^{n}|y_i-\hat y_i|,
\tag{14}
\]

\[
\mathrm{RMSE}=
\sqrt{\frac{1}{n}\sum_{i=1}^{n}(y_i-\hat y_i)^2},
\tag{15}
\]

\[
\mathrm{Bias}=
\frac{1}{n}\sum_{i=1}^{n}(\hat y_i-y_i).
\tag{16}
\]

P95 is the 95th percentile of \(|y_i-\hat y_i|\).

## 3.5. Temporal validation protocol

The project specification defines chronological validation rather than random train/test splitting: an early 14-day interval is used for model fitting and the following 7-day interval for testing, subject to minimum laboratory-sample counts.

This temporal design is appropriate because randomly mixing nearby one-minute observations would produce information leakage and would not test the model under evolving plant conditions. For a publication-grade analysis, the protocol should be executed as repeated rolling-origin windows within each operating regime and, separately, as a transfer test across the 21 May regime change.

**Current evidence limitation:** the available R&D report provides aggregate development metrics but does not unambiguously identify which reported metrics are strictly held-out results. Consequently, Section 4 reports the existing metrics as **development-set performance** and leaves the publication-critical held-out comparison to be inserted after the temporal-validation run.

## 3.6. Baseline models

**[TO COMPLETE BEFORE PREPRINT RELEASE]** At minimum, two baselines should be evaluated on the identical temporal splits:

1. a simple data-driven baseline such as ridge regression or PLS using the same aligned process inputs;
2. a physics-only / fixed-parameter baseline in which the empirical latent-variable calibration is removed or frozen.

For Computers & Chemical Engineering in particular, a comparison against at least one additional nonlinear baseline (e.g., random forest, gradient boosting, or a compact feedforward neural network) would materially strengthen the methodological argument. The main paper does not require an exhaustive benchmark suite; the purpose is to show whether the hybrid structure provides value beyond a trivial regression and beyond the uncalibrated balance model.

## 3.7. Downstream decision-support layer

The prototype used the virtual measurements to calculate recommended acid, ammonia, and water flows every 10 min. The recommendations were designed to move the modeled state toward the target molar ratio and density while retaining the process mass-balance structure.

These calculations are treated here as a downstream **decision-support demonstration**, not as a validated control strategy. The recommendations were evaluated offline by recalculating the model outputs after the proposed flow changes; they were not prospectively tested as closed-loop actions on the industrial process during the reported study.

Because the scientific contribution of this paper is the virtual-sensing layer, the detailed recommendation algebra is better placed in Supporting Information after a dimensional and process-logic audit.

## 3.8. Exploratory production-output reconstruction

A secondary model estimated MAP production from downstream suspension and mother-liquor flows:

\[
\dot m_{\mathrm{prod}}=
\left(\dot m_{1}+\dot m_{2}-\dot m_{3}\right)K,
\tag{17}
\]

with

\[
\dot m_1=F_{350}\rho_{350},\qquad
\dot m_2=F_{389}\rho_{389},\qquad
\dot m_3=F_{305}\rho_{305}.
\tag{18}
\]

During the study, contemporaneous density measurements were unavailable for part of this calculation, so fixed historical averages from April 2025 were used: \(\rho_{350}=1.315\), \(\rho_{389}=1.299\), and \(\rho_{305}=1.31\) g cm\(^{-3}\). The project used a factor \(K=1.55\) associated with product moisture.

Because the physical interpretation and units of \(K\) must be formally documented and because several densities were substituted by historical averages, this calculation is treated as exploratory and is not used to support the main soft-sensor claim.

# 4. Results

## 4.1. Data retention and process nonstationarity

Of 139,681 one-minute plant records, 121,414 (86.9%) passed simultaneous validity screening. Of 860 laboratory records, 767 (89.2%) were retained for model development. These retention rates show that the dataset is large in terms of telemetry samples but comparatively sparse in supervised target observations.

The conductivity trajectory changed abruptly on 21 May, motivating separate calibrations for Regimes A and B. The selected time lags differed substantially between the regimes (180 min versus 20 min), suggesting that the relation among sampled quality, transport delay, and process signals was not stationary across the study.

**[TO COMPLETE — FIGURE 3]** Show laboratory molar-ratio and density measurements over time on top of the aligned one-minute process timeline. Indicate the two operating regimes and the sampling sparsity.

## 4.2. Development-set soft-sensor accuracy

Table 1 summarizes the metrics currently available from the R&D report.

**Table 1. Reported development-set performance of the physics-guided soft sensor.**

| Metric | Regime A: 1 Mar–20 May | Regime B: 21 May–6 Jun | Combined: 1 Mar–6 Jun |
|---|---:|---:|---:|
| Conductivity regime | ~20 | ~10 | mixed |
| Laboratory points | 637* | 119* | 767* |
| Selected lag, min | 180 | 20 | 50 |
| Selected window, min | 60 | 20 | 60 |
| RMSE, molar ratio | 0.0342 | 0.0321 | 0.0358 |
| MAE, molar ratio | 0.0263 | 0.0287 | 0.0277 |
| Bias, molar ratio | -0.0139 | +0.0169 | -0.0097 |
| P95 absolute error, molar ratio | 0.0665 | 0.0500 | 0.0700 |
| Within \(\pm0.03\), molar ratio | 55.71% | 35.90% | 53.70% |
| RMSE, density, g cm\(^{-3}\) | 0.0119 | 0.0094 | 0.0113 |
| MAE, density, g cm\(^{-3}\) | 0.0092 | 0.0082 | 0.0086 |
| Bias, density, g cm\(^{-3}\) | +0.0043 | -0.0057 | +0.0019 |
| P95 absolute error, density, g cm\(^{-3}\) | 0.0227 | 0.0167 | 0.0214 |
| Within \(\pm0.01\) g cm\(^{-3}\), density | 62.86% | 56.41% | 65.12% |

\* **[TO RECONCILE]** The two regime counts reported in the source table sum to 756 rather than the stated combined total of 767. The final manuscript must regenerate this table directly from the analysis dataset.

The combined model reproduced the overall level of both target variables but did not meet the project tolerance for a substantial fraction of observations. Molar-ratio RMSE was 0.0358 against a target tolerance of \(\pm0.03\), while density RMSE was 0.0113 g cm\(^{-3}\) against a tolerance of \(\pm0.01\) g cm\(^{-3}\).

The most informative feature of Table 1 is the change in bias sign between the two regimes. Molar-ratio bias changed from \(-0.0139\) in Regime A to \(+0.0169\) in Regime B, while density bias changed from \(+0.0043\) to \(-0.0057\) g cm\(^{-3}\). This pattern is consistent with calibration drift or a change in the relationship between conductivity, latent acid properties, and downstream quality.

**[TO COMPLETE — FIGURE 4]** Publication-quality time-series panels for each regime: laboratory reference, virtual estimate, and residual for molar ratio and density. Use the held-out predictions after temporal validation, not the current training/development curves.

**[TO COMPLETE — FIGURE 5]** Predicted-versus-measured scatter plots for the two outputs, split by operating regime. Include the identity line and report \(n\), RMSE, MAE, and bias in the caption.

## 4.3. Temporal hold-out and baseline comparison

**[TO COMPLETE — CORE RESULT]** Replace this section with the results of the chronological 14-day/7-day rolling validation and baseline models.

Recommended final table:

| Model | Test regime | \(R\) RMSE | \(R\) MAE | \(R\) within tolerance | \(\rho_M\) RMSE | \(\rho_M\) MAE | \(\rho_M\) within tolerance |
|---|---|---:|---:|---:|---:|---:|---:|
| Physics-guided soft sensor | within Regime A | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| Physics-guided soft sensor | within Regime B | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| Physics-guided soft sensor | A \(\rightarrow\) B transfer | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| PLS / ridge baseline | same splits | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| Physics-only baseline | same splits | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |

The final discussion should distinguish three questions: interpolation within a stable regime, prediction on later data from the same regime, and transfer across the regime shift.

## 4.4. Sensitivity of modeled quality variables to manipulated flows

The development report calculated local partial derivatives of the modeled outputs with respect to the three principal flow variables:

**Table 2. Reported local sensitivities of the model outputs.**

| Output | phosphoric-acid flow | ammonia flow | water flow |
|---|---:|---:|---:|
| Molar ratio \(R\) | -0.123 | +0.00055 | 0 |
| Density \(\rho_M\) | +0.021 | -0.00003 | -0.007 |

The signs agree with the intended control interpretation of the prototype: ammonia primarily changes molar ratio, water primarily changes density, and acid flow couples the two objectives. The numerical derivative magnitudes cannot be directly compared across columns because the inputs have different physical units.

**[TO COMPLETE]** Add units and the operating point at which the derivatives were evaluated. For publication, either normalize the sensitivities or report them as dimensional derivatives with explicit units.

## 4.5. Offline decision-support demonstration

The prototype generated 10-min recommendations for acid, ammonia, and water flows by solving the process-specific algebraic correction layer using the estimated quality variables. Offline back-calculation showed that the recommendation engine could produce candidate settings consistent with the model targets.

These results should not be interpreted as evidence of closed-loop control performance. Recommendation accuracy inherits the error of the soft sensor, and no prospective plant trial was reported. Accordingly, the paper presents this layer as evidence that virtual telemetry can support operator decision making, while reserving control-performance claims for a future intervention study.

**[TO COMPLETE — OPTIONAL FIGURE 6]** If the recommendation layer remains in the main paper, plot current versus recommended flows for a short representative interval and the corresponding predicted movement of \(R\) and \(\rho_M\). Avoid using the entire three-month high-density plot, which is difficult to interpret.

## 4.6. Exploratory production-output reconstruction

The production-balance model was compared with daily dispatcher and technical-report values. Monthly results were:

| Month | Calculated production, t | Dispatcher production, t | Technical-report production, t | Daily MAPE |
|---|---:|---:|---:|---:|
| March | 1,214 | 4,800 | 4,640 | 79.1% |
| April | 4,482 | 4,622 | 4,573 | 41.8% |
| May | 4,726 | 4,560 | 4,557 | 24.2% |

Performance improved as the fraction of valid downstream measurements increased, but the daily error remained too large for this module to support the principal publication claim. The May monthly total was close to the documented output, yet only 32.3% of May days had a reported daily error below 10%.

For a minimal and focused preprint, this subsection can remain as an exploratory demonstration or be moved to Supporting Information. It should not appear in the title or abstract.

# 5. Discussion

## 5.1. Virtual telemetry as a digitalization layer

The industrial value of the proposed architecture is not that it replaces physical instrumentation. Rather, it converts already available plant telemetry into higher-level virtual measurements at a frequency closer to process operation than manual laboratory sampling. This is consistent with the broader role of soft sensors as part of process digitalization: they increase observability without requiring a new physical analyzer at every location (Hamid et al., 2022; Pietrasik et al., 2024; Boskabadi et al., 2025).

The architecture is deliberately low-complexity. The empirical component is restricted to latent feed-property reconstruction, while downstream calculations retain explicit process structure. This makes the output easier to audit than a direct high-capacity black-box predictor and is aligned with hybrid-modeling arguments that process knowledge can improve interpretability and extrapolation behavior (Sansana et al., 2021; Bradley et al., 2022; Schweidtmann et al., 2024).

## 5.2. Comparison with industrial soft-sensor literature

The case shares the classical characteristics summarized by Kadlec et al. (2009): unequal sampling rates, noise, outliers, missing data, and time-varying operating conditions. The present dataset also illustrates why expert process knowledge remains important in industrial soft-sensor development. Only a small set of physically relevant flow and conductivity signals was used, and latent variables were connected through material balances rather than inferred from unrestricted feature engineering, consistent with the findings of Offermans et al. (2024).

The work is also related to recent industrial studies in which quality measurements are available only every several hours. Fricz et al. (2026), for example, evaluated soft-sensor models for an industrial quality variable with sparse sampling, while Boskabadi et al. (2025) combined process knowledge and machine learning for virtual sensing in a large-scale production environment. The present MAP case differs in using a simple grey-box sequence of latent-property reconstruction and material-balance calculation and in explicitly exposing a strong within-study operating-regime shift.

A fertilizer-specific precedent is particularly important. Fu et al. (2007) combined data-driven and simplified first-principles models for online nutrient-content estimation in compound-fertilizer production. Therefore, the contribution here is not the generic idea of a fertilizer soft sensor. The differentiating aspects are the MAP neutralization process, sparse multi-rate laboratory references, reconstruction of phosphoric-acid feed properties, and quantitative analysis of data-quality and regime-shift limitations in an industrial dataset.

## 5.3. Regime dependence and model maintenance

The bias reversal across the 21 May shift is operationally more important than the small difference in RMSE between the two development subsets. A model can retain similar average error while changing the direction of systematic error. For operator decision support, this can produce persistent over- or under-correction.

The project results therefore support a regime-aware deployment strategy. One practical option is to maintain separate calibrations for stable conductivity regimes and use a fallback global model only when the current regime is uncertain. A more general approach would use drift detection and controlled recalibration. Recent work on industrial soft-sensor lifecycle management similarly treats concept drift and maintenance as first-class deployment problems (Metcalfe et al., 2025).

## 5.4. Data quality as the dominant current limitation

The current model error is comparable with the operational tolerances, while several process measurements contain spikes, dropouts, and periods of missing data. In addition, the study lacked reliable contemporaneous measurements for some variables and substituted historical averages for part of the production calculation.

This suggests that increasing model complexity alone is unlikely to solve the present limitation. Recent soft-sensor research has shown that missing-data treatment and quality-aware imputation can materially affect downstream prediction (Dai et al., 2025). For this process, however, the highest-priority improvements are more basic: establish a trusted data pipeline, reconcile conflicting sources, restore direct measurement of critical feed properties where feasible, and define regime-specific data-quality rules.

## 5.5. Limitations

The current study has five principal limitations.

First, the available technical report does not unambiguously distinguish fitted/development metrics from strict chronological test metrics. Temporal hold-out evaluation is therefore required before the preprint should be posted.

Second, no baseline model comparison is currently available. Without a simple data-driven and physics-only baseline, the incremental value of the hybrid architecture cannot be quantified.

Third, the laboratory reference itself may contain timing and measurement uncertainty. Because laboratory sampling is sparse and process transport delays vary, part of the model residual may originate from reference alignment rather than from the virtual-sensor equations.

Fourth, the dataset spans only approximately three months and contains one major regime transition. Broader seasonal and feedstock variability remains untested.

Fifth, the recommendation engine was evaluated offline only. The results support decision-support feasibility but not automated control performance, safety, or economic benefit.

# 6. Conclusions

A physics-guided soft-sensor prototype was developed for an industrial MAP process in which one-minute plant telemetry must be reconciled with quality measurements obtained only every 2–8 h. The model reconstructs latent phosphoric-acid properties from conductivity and combines them with material-balance calculations to estimate the \(NH_3/H_3PO_4\) molar ratio and downstream solution density.

On the combined development dataset, the reported RMSE was 0.0358 for molar ratio and 0.0113 g cm\(^{-3}\) for density. An abrupt conductivity shift divided the study into two operating regimes and produced a reversal in prediction bias, demonstrating that nonstationarity is a central deployment issue. The analysis also shows that noise, missing values, inconsistent data sources, and unavailable direct measurements currently constrain accuracy at least as strongly as model form.

The results support virtual telemetry as a practical intermediate layer between raw plant signals and operator decision support. Before public release and journal submission, the analysis should be completed with chronological hold-out validation, simple baselines, a reconciled data audit, and an exact publication-ready specification of the density calculation.

# Author contributions

**[TO COMPLETE]** Use CRediT roles, e.g. Conceptualization; Methodology; Software; Validation; Formal analysis; Investigation; Data curation; Writing – original draft; Writing – review & editing; Visualization; Project administration; Supervision.

# Funding

**[TO COMPLETE]** State the contractual / institutional funding source in a form approved for publication. Do not reproduce confidential contract identifiers unless authorized.

# Declaration of competing interest

The authors declare that they have no known competing financial interests or personal relationships that could have appeared to influence the work reported in this paper.

**[TO VERIFY with all authors and industrial partner before submission.]**

# Data availability

The raw plant historian, laboratory, and production datasets contain proprietary industrial information and are not currently approved for public release. The authors intend to provide the variable definitions, preprocessing logic, model equations, and aggregated evaluation results required to assess the reported conclusions. Subject to industrial-partner approval, a de-identified sample or synthetic dataset and analysis code may be released with the final article.

**[TO VERIFY against the final confidentiality agreement and target-journal data policy.]**

# Declaration of generative AI and AI-assisted technologies in the writing process

**[TO COMPLETE AT SUBMISSION]** If required by the target journal, disclose the use of generative AI tools for drafting or language/structure assistance according to the journal policy in force at submission. All scientific content, calculations, citations, and conclusions must be checked and approved by the authors.

# Supporting Information

Recommended Supporting Information:

- detailed signal-validity rules and thresholds;
- complete latent-variable model coefficients for each operating regime;
- exact downstream density equation;
- rolling temporal-validation results for all windows;
- baseline model configurations and hyperparameters;
- additional residual plots and error distributions;
- recommendation-layer equations and offline examples;
- production-output reconstruction details;
- negative turbidity-correlation analysis;
- data dictionary and provenance map.

# References

Boskabadi, M.R., Murugaiah, M., Nielsen, T.R., Sivaram, A., Sin, G., Mansouri, S.S., 2025. Virtual Sensor for Sustainable Large-Scale Process Monitoring. *Industrial & Engineering Chemistry Research* 64(7), 3902–3917. https://doi.org/10.1021/acs.iecr.4c03342

Bradley, W., Kim, J., Kilwein, Z., Blakely, L., Eydenberg, M., Jalvin, J., Laird, C., Boukouvala, F., 2022. Perspectives on the integration between first-principles and data-driven modeling. *Computers & Chemical Engineering* 166, 107898. https://doi.org/10.1016/j.compchemeng.2022.107898

Dai, Y., Yang, C., Liu, K., Liu, Y., Yao, Y., 2025. Quality-aware industrial data imputation with self-supervised recovery for process soft sensor development. *Computers & Chemical Engineering* 203, 109328. https://doi.org/10.1016/j.compchemeng.2025.109328

Fricz, B., Horváth, G., Kummer, A., 2026. Kolmogorov–Arnold and deep learning networks for industrial explainable product quality prediction. *Digital Chemical Engineering* 18, 100289. https://doi.org/10.1016/j.dche.2026.100289

Fu, Y., Su, H., Chu, J., 2007. MIMO soft-sensor model of nutrient content for compound fertilizer based on hybrid modeling technique. *Chinese Journal of Chemical Engineering* 15(4), 554–559. https://doi.org/10.1016/S1004-9541(07)60123-2

Hamid, A., Hasan, A.H., Azhari, S.N., Harun, Z., Putra, Z.A., 2022. Hybrid modelling for remote process monitoring and optimisation. *Digital Chemical Engineering* 4, 100044. https://doi.org/10.1016/j.dche.2022.100044

Kadlec, P., Gabrys, B., Strandt, S., 2009. Data-driven soft sensors in the process industry. *Computers & Chemical Engineering* 33(4), 795–814. https://doi.org/10.1016/j.compchemeng.2008.12.012

Kay, S., Kay, H., Mowbray, M., Lane, A., Mendoza, C., Martin, P., Zhang, D., 2024. Integrating transfer learning within data-driven soft sensor design to accelerate product quality control. *Digital Chemical Engineering* 10, 100142. https://doi.org/10.1016/j.dche.2024.100142

Metcalfe, B., Acosta-Pavas, J.C., Robles-Rodriguez, C.E., Georgakilas, G.K., Dalamagas, T., Aceves-Lara, C.A., Daboussi, F., Koehorst, J.J., Corrales, D.C., 2025. Towards a machine learning operations (MLOps) soft sensor for real-time predictions in industrial-scale fed-batch fermentation. *Computers & Chemical Engineering* 194, 108991. https://doi.org/10.1016/j.compchemeng.2024.108991

Mousa, J., Negny, S., Ouaret, R., 2025. Hybrid neural networks for improved chemical process modeling: Bridging data-driven insights with physical consistency. *Digital Chemical Engineering* 16, 100256. https://doi.org/10.1016/j.dche.2025.100256

Offermans, T., Szymańska, E., Souza, F.A.A., Jansen, J.J., 2024. Process expert knowledge is essential in creating value from data-driven industrial soft sensors. *Computers & Chemical Engineering* 183, 108602. https://doi.org/10.1016/j.compchemeng.2024.108602

Pietrasik, M., Wilbik, A., Grefen, P., 2024. The enabling technologies for digitalization in the chemical process industry. *Digital Chemical Engineering* 12, 100161. https://doi.org/10.1016/j.dche.2024.100161

Sansana, J., Joswiak, M.N., Castillo, I., Wang, Z., Rendall, R., Chiang, L.H., Reis, M.S., 2021. Recent trends on hybrid modeling for Industry 4.0. *Computers & Chemical Engineering* 151, 107365. https://doi.org/10.1016/j.compchemeng.2021.107365

Schweidtmann, A.M., Zhang, D., von Stosch, M., 2024. A review and perspective on hybrid modeling methodologies. *Digital Chemical Engineering* 10, 100136. https://doi.org/10.1016/j.dche.2023.100136

Souza, F.A.A., Araújo, R., Mendes, J., 2016. Review of soft sensor methods for regression applications. *Chemometrics and Intelligent Laboratory Systems* 152, 69–79. https://doi.org/10.1016/j.chemolab.2015.12.011