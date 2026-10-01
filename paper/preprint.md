---
title: "Physics-Guided Soft Sensing under Sparse Laboratory Measurements and Regime Shift in Industrial Monoammonium Phosphate Production"
article_type: "Original Article"
primary_target: "Digital Chemical Engineering"
compatible_targets:
  - "Computers & Chemical Engineering"
  - "Industrial & Engineering Chemistry Research (Process Systems Engineering)"
status: "Working preprint draft — updated after chronological validation"
latex_source: "paper/main.tex"
---

# Physics-Guided Soft Sensing under Sparse Laboratory Measurements and Regime Shift in Industrial Monoammonium Phosphate Production

**German A. Karnup\(^{a,b,*}\), Oleg A. Telminov\(^{b}\)**

\(^{a}\) Moscow Institute of Physics and Technology (National Research University), Dolgoprudny, Moscow Region, Russian Federation  
\(^{b}\) Molecular Electronics Research Institute, JSC (NIIME), Zelenograd, Moscow, Russian Federation  

ORCID: German A. Karnup — 0000-0001-6517-4712  
ORCID: Oleg A. Telminov — 0000-0002-2358-3689  

\* Corresponding author: [e-mail to confirm before submission]

> **Anonymization note.** The industrial data owner authorized use of the plant data for research calculations but requested de-identification of the company, production site, equipment identifiers, and internal signal tags. The manuscript therefore describes the facility only as an industrial monoammonium phosphate production line and uses generic variable names.

## Highlights

- Chronological validation exposes a hidden physics-guided failure mode.
- Ridge and LSBoost outperform the physics-guided model after regime shift.
- Sparse laboratory labels make regime-aware validation essential.
- One-minute telemetry enables virtual monitoring between laboratory samples.

## Abstract

Industrial plants generate high-frequency telemetry while key quality variables may be measured only every few hours. We evaluate a physics-guided soft sensor for an industrial monoammonium phosphate process using 139,681 one-minute records and 860 paired laboratory observations. Chronological validation used nine 14-day-train/7-day-test windows in the initial regime and one transfer test across a conductivity-driven regime shift. The physics-guided model showed unstable generalization: pooled initial-regime RMSE was 0.2125 for molar ratio and 0.0176 g cm\(^{-3}\) for density, driven by one catastrophic window. Ridge regression was more stable (0.0156/0.0085). On regime transfer, gradient boosting achieved 0.0188/0.0134 versus 0.0707/0.0310 for the physics-guided model. Physical structure alone therefore did not guarantee robustness under sparse labels and regime drift, motivating regime-aware calibration and leakage-safe temporal validation.

**Keywords:** soft sensor; virtual sensor; hybrid modeling; process monitoring; regime shift; monoammonium phosphate

## Nomenclature

| Symbol | Definition | Unit |
|---|---|---|
| \(c\) | online conductivity signal used as a proxy for acid state | process unit |
| \(Q_A\) | clarified phosphoric-acid volumetric flow | m\(^3\) h\(^{-1}\) |
| \(\dot m_N\) | ammonia mass flow | kg h\(^{-1}\) |
| \(Q_W\) | process-water volumetric flow | m\(^3\) h\(^{-1}\) |
| \(w_{P_2O_5}\) | mass fraction of \(P_2O_5\) in the acid stream | fraction or % |
| \(\rho_A\) | phosphoric-acid density | kg m\(^{-3}\) |
| \(R\) | \(NH_3/H_3PO_4\) molar ratio | dimensionless |
| \(\rho_M\) | downstream solution density | g cm\(^{-3}\) |
| \(\tau\) | time lag between telemetry and laboratory reference | min |
| \(W\) | aggregation-window length | min |

# 1. Introduction

Chemical-process plants routinely collect high-frequency online measurements while the variables that most directly describe product quality are measured less frequently by laboratory analysis or manual sampling. Soft sensors address this mismatch by inferring hard-to-measure quality variables from continuously available process measurements (Kadlec et al., 2009; Souza et al., 2016).

Industrial deployment is substantially harder than benchmark soft-sensor development. Real plant data contain missing values, sensor faults, short transients, asynchronous sampling, changing operating conditions, and uncertain reference measurements. Data preparation, temporal alignment, and model-maintenance strategy can therefore be as important as model class selection (Kadlec et al., 2009; Offermans et al., 2024; Dai et al., 2025).

Hybrid and physics-guided models are often proposed as a way to improve interpretability and extrapolation by embedding empirical relationships inside process knowledge rather than learning an unconstrained input-output map (Sansana et al., 2021; Bradley et al., 2022; Schweidtmann et al., 2024; Mousa et al., 2025). Industrial soft sensors are also increasingly treated as a digitalization layer that converts existing sensing infrastructure into higher-level virtual measurements for monitoring and decision support (Hamid et al., 2022; Pietrasik et al., 2024; Boskabadi et al., 2025).

Fertilizer production provides a relevant test case because composition and neutralization variables strongly affect product quality while several feed and intermediate-state properties are not continuously available. Hybrid soft sensing has previously been demonstrated for nutrient-content estimation in compound-fertilizer production (Fu et al., 2007). The novelty claimed here is therefore not the generic application of a soft sensor to fertilizer production. Instead, this study examines an industrial monoammonium phosphate (MAP) process with four characteristics that are important for real deployment: one-minute telemetry versus laboratory measurements every few hours, latent feed properties, substantial data-quality problems, and a pronounced operating-regime shift during the observation interval.

The original engineering prototype used a physics-guided model to estimate molar ratio and downstream solution density and then supplied those estimates to an offline operator-recommendation layer. The present paper asks a stricter scientific question: **does the physics-guided structure remain reliable under chronological hold-out testing and a real operating-regime shift, and how does it compare with simple data-driven baselines?**

The contributions are:

1. a real industrial multi-rate soft-sensing case with 139,681 minute records and 860 paired laboratory observations;
2. a reproducible chronological evaluation using fixed 14-day training and 7-day test windows;
3. comparison of the physics-guided model with Ridge, physics-only, and LSBoost baselines on identical temporal splits;
4. explicit analysis of a catastrophic physics-guided failure window and cross-regime transfer;
5. documentation of data-alignment and preprocessing choices that can create operational look-ahead even when target leakage is absent.

# 2. Industrial process and data

## 2.1. Process description

The investigated process is part of an industrial MAP production line. Clarified phosphoric acid is transferred through an intermediate stage to a tubular neutralization reactor. Ammonia is introduced for neutralization and process water is adjusted to influence downstream solution density. The principal reaction is represented in simplified form as

\[
NH_3 + H_3PO_4 \rightarrow NH_4H_2PO_4.
\tag{1}
\]

The two quality variables considered in this work are the \(NH_3/H_3PO_4\) molar ratio \(R\) and downstream solution density \(\rho_M\). The operational targets used during prototype development were

\[
R_{\mathrm{target}} = 1.06,
\qquad
\rho_{M,\mathrm{target}} = 1.21\ \mathrm{g\,cm^{-3}}.
\tag{2}
\]

The reference values were obtained from sparse laboratory/operator measurements rather than at the one-minute frequency of the process historian. Two phosphoric-acid properties needed by the material-balance calculation, the \(P_2O_5\) fraction and acid density, were not continuously measured with sufficient reliability and were therefore treated as latent variables.

**Figure 1 [to redraw before public release].** An anonymized process/soft-sensor schematic should show only generic units and variables: acid feed, intermediate vessel, reactor, ammonia and water feeds, downstream quality-sampling point, online telemetry, sparse laboratory references, latent-property reconstruction, material balance, and virtual outputs. Internal equipment numbers and plant tags must not appear.

## 2.2. Data sources

The study interval covers 1 March–6 June 2026.

| Data source | Variables | Sampling / count | Role |
|---|---|---:|---|
| Plant telemetry | conductivity, acid flow, ammonia flow, water flow | 139,681 one-minute records; 121,414 jointly valid after authoritative preprocessing | model inputs |
| Laboratory/operator references | molar ratio and solution density | 860 paired observations, typically every 2–8 h | calibration and evaluation targets |
| Downstream production records | product-flow information | daily / lower-frequency | exploratory calculation only |

The number of usable laboratory rows depends on lag and averaging-window configuration because a laboratory observation is eligible only when the required process window is sufficiently valid. This explains an apparent count inconsistency in the original development report. Under the regime-specific development configurations, 637 regime-A and 119 regime-B observations were obtained. These counts are produced by different masks and therefore should not be added. Under the single combined-model mask \(\tau=50\) min, \(W=60\) min, the partition is 643 regime-A plus 124 regime-B observations, giving the reported total of 767.

## 2.3. Data quality and preprocessing

The source data contain noisy process signals, short spikes and dropouts, missing or invalid values, incomplete time-series segments, and operating-regime changes. The preprocessing logic used in the validation study follows the documented engineering implementation and is treated as authoritative for this paper.

The workflow is:

1. read the native one-minute process series;
2. select the active redundant flow channel where applicable;
3. apply the documented conductivity filter and flow despiking;
4. apply process plausibility/range checks;
5. construct timestamps at which all required inputs are jointly valid;
6. associate each laboratory observation with an eligible process window determined by lag \(\tau\) and window length \(W\).

A total of 3,156 conductivity values were corrected by the authoritative process filter. Filtering does not use laboratory target values.

## 2.4. Operating-regime shift

The conductivity trajectory changes abruptly on 21 May 2026. The study therefore defines:

- **Regime A:** 1 March to 21 May;
- **Regime B:** 21 May onward.

The regime boundary is used as an externally observed process change, not as a label learned by the prediction models.

**Figure 2. Process signals, invalid intervals, and the operating-regime boundary.** Use the anonymized version of the supplied process-timeline figure. Replace the internal conductivity tag with “conductivity signal” before public release.

**Figure 3. Sparse laboratory references on the process timeline.** Use the supplied multi-rate sampling figure after replacing the internal conductivity tag with a generic label.

# 3. Methodology

## 3.1. Physics-guided soft sensor

The soft sensor is a grey-box sequence rather than a direct unconstrained regression. Conductivity is first mapped to a latent \(P_2O_5\) fraction,

\[
\widehat{w}_{P_2O_5}=f_{\theta}(c),
\tag{3}
\]

followed by a mapping from estimated composition to acid density,

\[
\widehat{\rho}_{A}=g_{\phi}\!\left(\widehat{w}_{P_2O_5}\right).
\tag{4}
\]

The candidate mappings are linear, quadratic, and PCHIP spline functions.

The acid mass flow and \(P_2O_5\) mass flow are then

\[
\dot m_A=\widehat{\rho}_A Q_A,
\tag{5}
\]

\[
\dot m_{P_2O_5}=\dot m_A\widehat{w}_{P_2O_5}.
\tag{6}
\]

The prototype converts \(P_2O_5\) mass to equivalent 100% phosphoric-acid mass using

\[
\dot m_{H_3PO_4,100\%}=1.38\,\dot m_{P_2O_5}.
\tag{7}
\]

The corresponding molar flows are

\[
\dot n_{H_3PO_4}=
\frac{\dot m_{H_3PO_4,100\%}}{M_{H_3PO_4}},
\qquad
\dot n_{NH_3}=
\frac{\dot m_N}{M_{NH_3}},
\tag{8}
\]

with \(M_{H_3PO_4}=98\) g mol\(^{-1}\) and \(M_{NH_3}=17\) g mol\(^{-1}\). The virtual molar ratio is

\[
\widehat R=
\frac{\dot n_{NH_3}}{\dot n_{H_3PO_4}}.
\tag{9}
\]

For publication, the downstream density balance is written in dimensionally explicit form as

\[
\widehat{\rho}_M=
\frac{\sum_i \dot m_i}{\sum_i Q_i},
\qquad
\dot m_i=\rho_iQ_i,
\tag{10}
\]

where the sums contain the streams used by the implemented downstream balance. Equation (10) uses the additive-volume approximation of the prototype. Any plant-specific correction terms should be stated separately rather than folded into the definition of density.

## 3.2. Time alignment and model selection

Candidate lags and aggregation windows are

\[
\tau\in\{0,10,\ldots,180\}\ \mathrm{min},
\qquad
W\in\{10,20,30,60\}\ \mathrm{min}.
\tag{11}
\]

For each validation scenario, lag, window, and physics-guided mapping type were selected using only the scenario training data. The first 9 days of the initial training interval were used for fitting and the following 5 days for inner chronological validation. The selection score was

\[
J=
\frac{\mathrm{RMSE}_R}{0.03}
+
\frac{\mathrm{RMSE}_{\rho}}{0.01}.
\tag{12}
\]

The selected configuration was then frozen for all outer splits in that scenario, while fitted coefficients were re-estimated from each outer training interval only.

For within-regime-A evaluation the selected configuration was \(\tau=90\) min, \(W=60\) min with a quadratic latent-property mapping. For the A-to-B transfer scenario it was \(\tau=100\) min, \(W=30\) min with PCHIP mapping.

## 3.3. Baseline models

All baselines use the same temporally aligned rows as the physics-guided model.

- **Ridge:** standardized multivariate Ridge regression using conductivity, acid flow, ammonia flow, and water flow; regularization selected on chronological inner validation.
- **Physics-only:** acid flow, ammonia flow, and water flow with \(P_2O_5\) fixed at 52 wt% and an unfitted acid-density prior.
- **Gradient boosting:** LSBoost with 100 cycles, learning rate 0.05, minimum leaf size 10, and maximum 20 splits.

The physics-only model is a reference calculation, not a separately calibrated mechanistic model.

## 3.4. Chronological validation

The prespecified outer protocol is a fixed 14-day training interval followed immediately by a 7-day held-out interval. Within Regime A, rolling origins advance by 7 days and yield nine complete tests (A01–A09).

Regime B does not contain the 21 days of paired laboratory coverage required for a complete within-regime 14+7-day split. No shortened or randomly sampled substitute was introduced.

Cross-regime transfer is evaluated using:

- train: 7 May–21 May 2026;
- test: 21 May–28 May 2026.

No random shuffling is used.

## 3.5. Evaluation metrics

For target \(y_i\) and prediction \(\hat y_i\),

\[
\mathrm{MAE}=\frac{1}{n}\sum_{i=1}^{n}|y_i-\hat y_i|,
\tag{13}
\]

\[
\mathrm{RMSE}=
\sqrt{\frac{1}{n}\sum_{i=1}^{n}(y_i-\hat y_i)^2},
\tag{14}
\]

\[
\mathrm{Bias}=
\frac{1}{n}\sum_{i=1}^{n}(\hat y_i-y_i).
\tag{15}
\]

We also report the 95th percentile of absolute error and the fraction of predictions within the prototype tolerances:

\[
|R-\widehat R|\le0.03,
\qquad
|\rho_M-\widehat{\rho}_M|\le0.01\ \mathrm{g\,cm^{-3}}.
\tag{16}
\]

Molar-ratio predictions from the physics-guided implementation are rounded to two decimal places before validation, matching the production reporting setting.

# 4. Results

## 4.1. Within-regime-A rolling validation

Nine non-overlapping 7-day test intervals produced 509 held-out laboratory observations in total. Training-set size varied from 99 to 138 laboratory observations.

**Table 1. Pooled held-out performance across the nine Regime-A test intervals.**

| Model | RMSE \(R\) | MAE \(R\) | Within ±0.03 | RMSE \(\rho_M\), g cm\(^{-3}\) | MAE \(\rho_M\) | Within ±0.01 |
|---|---:|---:|---:|---:|---:|---:|
| Physics-guided | 0.2125 | 0.0421 | 0.580 | 0.0176 | 0.0096 | 0.668 |
| Ridge | 0.0156 | 0.0114 | 0.914 | 0.0085 | 0.0063 | 0.827 |
| Physics-only | 0.1053 | 0.1002 | 0.020 | 0.0842 | 0.0838 | 0.000 |
| Gradient boosting | 0.0168 | 0.0128 | 0.894 | 0.0110 | 0.0087 | 0.625 |

The pooled molar-ratio RMSE of the physics-guided model is dominated by split A08. In that window, the model produced an RMSE of 0.7489, MAE of 0.2368, and P95 absolute error of 2.685. The remaining windows are substantially more stable. Across the nine windows, the **median** physics-guided RMSE is 0.0288 for molar ratio and 0.0100 g cm\(^{-3}\) for density. The median characterization is reported only to describe the distribution of split behavior; A08 remains part of all pooled metrics and is not excluded from any model comparison.

Ridge regression is the most stable model across the Regime-A rolling tests for the two outputs jointly. Gradient boosting gives similarly low molar-ratio errors but higher density error than Ridge. The physics-only reference is systematically biased and does not approach the specified tolerances.

**Figure 4. Held-out measured versus predicted values.** The supplied figure shows all Regime-A rolling tests and the A-to-B transfer test. The extreme physics-guided predictions visible in Regime A correspond to the A08 failure and explain the pooled RMSE.

## 4.2. A-to-B regime transfer

The transfer experiment trains on the final 14 days of Regime A and tests on the first 7 days of Regime B, with 99 training and 56 test laboratory observations.

**Table 2. Held-out A-to-B transfer performance.**

| Model | RMSE \(R\) | MAE \(R\) | Bias \(R\) | Within ±0.03 | RMSE \(\rho_M\), g cm\(^{-3}\) | MAE \(\rho_M\) | Bias \(\rho_M\) | Within ±0.01 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Physics-guided | 0.0707 | 0.0659 | -0.0655 | 0.089 | 0.0310 | 0.0291 | +0.0289 | 0.036 |
| Ridge | 0.0224 | 0.0179 | +0.0171 | 0.732 | 0.0114 | 0.0088 | -0.0063 | 0.643 |
| Physics-only | 0.0966 | 0.0912 | +0.0912 | 0.018 | 0.0877 | 0.0871 | -0.0871 | 0.000 |
| Gradient boosting | 0.0188 | 0.0145 | +0.0063 | 0.875 | 0.0134 | 0.0111 | -0.0047 | 0.500 |

The transfer test changes the interpretation of the prototype. The physics-guided architecture remains better than the uncalibrated physics-only reference, but it generalizes substantially worse than the data-driven baselines. Gradient boosting gives the lowest molar-ratio RMSE, while Ridge gives the lowest density RMSE. The physics-guided model exhibits a strong negative molar-ratio bias and positive density bias after the regime transition.

**Figure 5. A-to-B transfer hold-out: physics-guided predictions and residuals.** The supplied time-series plot shows a persistent negative residual for molar ratio and positive residual for density through most of the transfer week.

**Figure 6. Held-out baseline comparison.** RMSE values normalized by the engineering tolerances show the large Regime-A physics-guided penalty caused by A08 and the performance degradation of all physics-based variants under A-to-B transfer.

## 4.3. No complete within-regime-B test

The first paired laboratory record in Regime B occurs after the 21 May boundary and the final paired record is on 5 June. Consequently, there is no complete 14-day training plus 7-day held-out interval entirely within Regime B. The study reports this absence directly rather than shortening the test horizon or introducing a different validation protocol after observing the data.

## 4.4. Implications for model selection

The hold-out results do not support a claim that the current physics-guided model is the most accurate virtual sensor. Instead, they show a more useful deployment result: **the interpretable grey-box structure is vulnerable to calibration instability and operating-regime change, and its development-set performance is insufficient evidence of prospective robustness.**

For the present dataset, simple Ridge regression is markedly more stable across both outputs. Gradient boosting is competitive within Regime A and gives the lowest molar-ratio error in the A-to-B transfer. The physics-only reference performs poorly, showing that first-principles structure without calibrated latent-feed information is insufficient.

# 5. Discussion

## 5.1. Why the chronological result matters

The original development metrics suggested that the physics-guided prototype tracked the overall level of molar ratio and density. Chronological hold-out testing reveals a qualitatively different issue: most Regime-A windows are moderate, but one window is catastrophically unstable and the model transfers poorly across the later regime shift.

This distinction is central for industrial soft sensing. A model used between laboratory measurements must remain bounded and predictable when process conditions move away from the calibration interval. Average fit on a mixed development dataset can hide rare but operationally unacceptable failures.

## 5.2. Physics guidance does not guarantee robustness

Physics-guided structure provides interpretability: conductivity is used to reconstruct latent acid composition and density, and these variables enter a material-balance calculation. However, the learned latent-property mappings are still empirical. When their calibration becomes unstable or the conductivity-to-composition relationship changes, the physical downstream equations propagate rather than remove the error.

The comparison with Ridge and gradient boosting is therefore not an argument against physics-guided modeling in general. It shows that the present grey-box implementation needs explicit safeguards: bounded latent-property mappings, extrapolation detection, regime-conditioned calibration, or fallback to a more stable model when the current input domain is outside calibration support.

## 5.3. Regime shift and maintenance

The A-to-B experiment demonstrates that the relation among conductivity, latent feed properties, and downstream quality is not stationary enough for the current calibration to be carried unchanged across the boundary. A deployment architecture should therefore include at least one of the following:

- explicit operating-regime detection;
- drift monitoring on model inputs and residuals;
- bounded or monotonic latent-property mappings where physically justified;
- controlled recalibration using new laboratory results;
- a fallback predictor selected on prospective validation rather than development fit alone.

## 5.4. Sparse labels and validation design

The dataset is large in telemetry count but small in independent target observations. Nine Regime-A test windows contain only 40–74 laboratory targets each, and the transfer test contains 56. This makes random row-wise splitting particularly inappropriate because adjacent process observations are highly correlated and because the laboratory sampling process itself is sparse and multi-rate.

The fixed 14-day/7-day rolling protocol gives a more realistic estimate of operational performance, but it also makes uncertainty across windows visible. Future work should extend the observation horizon and report performance over additional regime transitions.

## 5.5. Preprocessing and operational look-ahead

The validation contains no outer-test target leakage: hyperparameter selection is nested chronologically and outer-test laboratory values are not used for fitting. Two preprocessing details nevertheless matter for prospective deployment.

First, the authoritative conductivity filtering and signal-repair routines include centered operations, including robust windows, Savitzky–Golay smoothing, and PCHIP repair, which can use nearby future process values. Second, laboratory alignment uses a centered averaging window around \(t_{\mathrm{lab}}-\tau\); when \(\tau<W/2\), the window can extend beyond the nominal laboratory timestamp.

These operations are retained because the present study validates the implemented R&D prototype. A truly online deployment study should replace them with causal alternatives and repeat the validation.

## 5.6. Decision-support scope

The prototype also calculates 10-minute recommendations for acid, ammonia, and water flows. Those calculations remain an offline decision-support demonstration. Because recommendation quality inherits soft-sensor error and no prospective plant intervention was performed, the present article does not claim closed-loop control performance, safety benefit, or economic benefit.

The production-output calculation used during the R&D project is likewise excluded from the primary claim because contemporaneous density measurements were unavailable for part of that calculation. The plant uses a moisture coefficient \(K=1.55\); that module is best retained as Supporting Information until independently validated with complete time-series inputs.

# 6. Limitations

1. Only approximately three months of operation and one major regime transition are available.
2. A complete within-Regime-B 14+7-day validation split is unavailable.
3. The laboratory reference itself has timing and measurement uncertainty.
4. The authoritative preprocessing contains short-horizon look-ahead and should be made causal for prospective deployment.
5. The extreme A08 failure is identified but not yet attributed to a single physical or numerical cause; root-cause analysis of the fitted latent-property mapping is required before deployment.
6. Raw industrial data cannot be released publicly under the data-owner agreement, limiting third-party reproduction from the original plant signals.

# 7. Conclusions

A physics-guided soft-sensor prototype was evaluated for an industrial MAP process in which one-minute telemetry must be reconciled with laboratory quality measurements obtained only every few hours. Strict chronological validation produced nine complete 14-day-train/7-day-test windows within the initial operating regime and one transfer test across a real conductivity-driven regime shift.

The principal result is a robustness limitation rather than an accuracy claim. The physics-guided model was acceptable in several individual windows but suffered a catastrophic molar-ratio failure in A08 and degraded strongly during A-to-B transfer. Ridge and gradient boosting were substantially more stable on the same held-out data. The physics-only reference performed poorly.

The study therefore shows that physical structure alone does not guarantee reliable virtual telemetry. For industrial deployment, physics-guided soft sensors require leakage-safe temporal validation, bounded or monitored extrapolation, regime-aware maintenance, and explicit fallback behavior. These requirements are especially important when labels are sparse and the empirical part of a hybrid model reconstructs latent feed properties that directly drive downstream material-balance calculations.

# Author contributions

**[TO CONFIRM BEFORE SUBMISSION]** Final CRediT roles must be agreed by both authors. Recommended roles to assign explicitly are Conceptualization, Methodology, Software, Validation, Formal analysis, Investigation, Data curation, Writing – original draft, Writing – review & editing, Visualization, Project administration, and Supervision.

# Funding

This work was performed within an industrial R&D project. The industrial data owner requested anonymization of the company, production site, equipment identifiers, and internal project identifiers. Funding metadata should be finalized before journal submission in a form consistent with that agreement.

# Declaration of competing interest

The authors declare that they have no known competing financial interests or personal relationships that could have appeared to influence the work reported in this paper.

# Data availability

The industrial data owner authorized use of the operational data for research calculations but requested de-identification of the company, site, equipment identifiers, and internal signal tags. Raw historian and laboratory data therefore cannot be made public. The manuscript reports derived aggregate metrics and the validation protocol. Subject to the same confidentiality constraints, analysis code and de-identified derived results may be released with the final article.

# Declaration of generative AI and AI-assisted technologies in the writing process

Generative AI tools were used for language and structural assistance during manuscript preparation. All scientific content, equations, calculations, citations, interpretations, and conclusions are subject to author verification and approval. The final disclosure should be adapted to the policy of the selected journal at submission.

# Supporting Information

Recommended Supporting Information:

- exact engineering preprocessing thresholds and signal-validity rules;
- latent-property model coefficients for each chronological fit;
- all per-split validation metrics;
- diagnostic output for the A08 failure;
- baseline configurations and regularization settings;
- additional residual distributions;
- decision-support equations and offline examples;
- production-output reconstruction using the plant moisture coefficient \(K=1.55\);
- data-provenance table using anonymized variable names.

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
