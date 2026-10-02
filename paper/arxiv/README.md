# arXiv source package

This directory is the self-contained public-preprint source package.

Contents:

- `main.tex`: manuscript source;
- `references.bib`: bibliography database;
- `figures/`: public, de-identified manuscript figures.

The four manuscript figures are included as vector PDF files. PNG previews,
raw historian data, laboratory workbooks, private ingestion utilities,
source-system identifiers, and local build artifacts are intentionally
excluded.

Expected build command:

```text
latexmk -pdf -interaction=nonstopmode -halt-on-error main.tex
```

All figures referenced by this source package are included.
