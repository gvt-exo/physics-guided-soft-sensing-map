# Control Engineering Practice — submission checklist

**Preparation branch:** `submission/control-engineering-practice`  
**Original manuscript:** CACE-D-26-01792 (*Computers & Chemical Engineering*)  
**Preprint:** https://doi.org/10.26434/chemrxiv.15009979/v1  
**Target journal:** *Control Engineering Practice*

## Ready in this branch

- [x] `paper/main.tex`: `elsarticle` manuscript reframed toward industrial soft sensing and monitoring.
- [x] Five authors shown in the requested order; Arkady V. Boyko added at JSC MERI, with `Data curation` and `Resources` CRediT roles.
- [x] `paper/references.bib`: relevant CEP literature added.
- [x] `paper/highlights.txt`: four editable, journal-length bullet points.
- [x] `paper/cover_letter_CEP.txt`: transfer-aware editorial cover-letter draft.
- [x] Four figures referenced by the file extensions **actually present in Git** (vector PDF).

## Mandatory author and ethics checks before transfer submission

- [ ] Submit and obtain editorial approval for the post-submission authorship change; the four existing authors agreed to add Boyko, but keep written documentation and obtain Boyko's own confirmation for the official Elsevier form. See `paper/authorship_change_CEP.md`.
- [ ] Confirm Arkady V. Boyko's preferred English spelling and whether `Data curation` / `Resources` accurately represent his substantive contribution.
- [ ] Confirm the new author has read/approved the full manuscript, agrees to be accountable for the work, and meets authorship criteria.
- [x] MERI salary support for Arkady V. Boyko confirmed by the corresponding author and disclosed in `main.tex`.
- [ ] Collect Boyko's full interests declaration and regenerate the separate Elsevier Word disclosure file with all four MERI-salaried authors. Other interests cannot be assumed absent.
- [ ] Ensure the new author is also entered in Editorial Manager, in the same order.
- [ ] Confirm the official name and address of the JSC MERI affiliation.
- [ ] Ensure all authors approve the updated manuscript and cover letter.
- [ ] Keep ChemRxiv v1 linked as an earlier four-author preprint; decide separately whether to submit a revised preprint after approvals.

## Submission-file and layout checks

- [ ] Build the PDF and inspect every page, especially the Nomenclature, Table 1, and Figures 2–4; no blank float pages, clipping, or missing references.
- [ ] Upload the manuscript PDF or source file as required by the **receiving CEP submission interface**. Retain the editable LaTeX sources for revision.
- [ ] Upload the highlights as a separate editable file.
- [ ] Upload four figures separately if requested; PDF is valid for vector figures in principle, but check the actual item-type extension restrictions and convert to EPS/TIFF if the portal requires.
- [ ] Upload the declaration of competing interests in Elsevier's requested editable format.
- [ ] Confirm whether CEP requires a graphical abstract or any additional file types at this submission stage; the full live CEP Guide for Authors could not be automatically retrieved.
- [ ] Review all figure captions and the generative-AI disclosure, including the architecture schematic.
- [ ] Cite every table and figure in order; check `references.bib` for missing/uncited entries.
- [ ] Use **subscription publication**, not paid Gold Open Access, if the goal remains to avoid APC; confirm the option in Editorial Manager.

## Scientific scope and terminology checks

- [x] The study is described as **retrospective validation** on plant data, not online closed-loop control.
- [x] Findings are described as **temporal transfer performance** and not proof of which latent relationship drifted.
- [x] The claim is comparative/model-assessment evidence, not a novel controller or a deployed process-automation system.
- [x] All numerical results carried over unchanged from the C&CE branch.
- [ ] The authors should independently confirm that the new explanatory wording accurately represents actual processing, filtering, and model selection.

**Note:** The public CEP aims/scope explicitly welcomes industrial soft sensing but expects practical evidence and reproducible reporting. The journal's official detailed Guide for Authors should still be checked directly in the portal at final submission.
