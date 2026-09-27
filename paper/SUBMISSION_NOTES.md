# Submission compatibility notes

Checked against current publisher guidance on 28 September 2026.

## Primary target: Digital Chemical Engineering

The manuscript is structured as an Original Article and is aligned with the journal's scope: digital technologies applied to chemical engineering, industrial soft sensing, hybrid/process-informed modeling, and process digitalization.

Current Elsevier-compatible elements already present:
- concise stand-alone abstract;
- six keywords;
- four Highlights (each kept below 85 characters);
- numbered sections;
- embedded equations and tables;
- separate declaration sections;
- Data Availability statement;
- competing-interest statement;
- generative-AI disclosure placeholder/content.

Before submission:
- add the final anonymized process/soft-sensor schematic;
- commit the five publication figures (prefer vector PDF for journal submission);
- finalize corresponding-author e-mail and CRediT contributions;
- perform a final language/citation audit.

## Computers & Chemical Engineering

The structure is compatible with a full-length article. The journal explicitly welcomes comparisons of alternative methodologies, new applications of established methods, and state-of-the-art industrial applications.

The new chronological validation materially improves fit to this journal because the manuscript now:
- compares four modeling approaches on identical held-out splits;
- reports a real industrial regime-shift transfer test;
- discusses deployment leakage and maintenance limitations;
- does not present the software prototype itself as the novelty.

Before submission to C&CE, strengthen the methodological analysis of the A08 failure:
- inspect the fitted latent-property mapping and identify why predictions became unbounded;
- add a bounded/monotonic or extrapolation-guarded physics-guided variant if it can be done without changing the paper into a new project;
- report whether that safeguard removes the failure without harming normal windows.

This is the main remaining scientific weakness for C&CE.

## Industrial & Engineering Chemistry Research

Current I&EC Research requirements relevant to this paper:
- title page with all author names and full affiliations;
- corresponding author and e-mail;
- mandatory TOC/Abstract graphic;
- TOC graphic final size approximately 8.47 cm x 4.76 cm;
- abstract of 100–150 words;
- sectionalized main text;
- figures/tables numbered and cited;
- references ultimately numbered sequentially in order of first citation;
- a Supporting Information description when SI is supplied.

Current manuscript status:
- abstract: 143 words — compliant;
- title/authors/affiliations: present;
- corresponding e-mail: still to confirm;
- TOC graphic: not yet created;
- current BibTeX style is author-year for the cross-journal preprint and must be switched to ACS sequential numbering for I&EC submission;
- final SI paragraph/files still to prepare.

I&EC Research permits the original submitted manuscript to be posted on a preprint server, but its current policy says the preprint should be disclosed in the cover letter and states that authors may not revise those preprints. If I&EC remains a live target, freeze the manuscript before depositing the public preprint.

## Public-preprint / arXiv readiness

The LaTeX source is deliberately journal-neutral and uses standard packages. It is suitable as a base for an arXiv source package after:
- all figure labels are anonymized;
- the process schematic is added;
- corresponding-author data and author contributions are finalized;
- unnecessary project files, internal comments, raw data, and private metadata are excluded from the upload archive.

Because the work is chemical-process systems / soft sensing rather than a new machine-learning method, a systems-and-control-oriented arXiv category is more plausible than a pure machine-learning category. ChemRxiv remains the more domain-specific alternative for a chemical-engineering preprint.

## Build

From the paper directory:

    make pdf

or:

    latexmk -pdf -interaction=nonstopmode -halt-on-error main.tex

The LaTeX source uses placeholders if figure files are absent, so the manuscript remains compilable while figures are being regenerated.
