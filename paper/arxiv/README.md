# arXiv source package

This directory is the self-contained public-preprint source package.

Contents:

- `main.tex`: manuscript source;
- `references.bib`: bibliography database;
- `figures/`: public, de-identified manuscript figures.

The three extended-validation figures are included as PNG files used by the
manuscript and as vector PDF files. Raw historian data, laboratory workbooks,
private ingestion utilities, internal signal identifiers, and local build
artifacts are intentionally excluded.

Expected build command:

```text
latexmk -pdf -interaction=nonstopmode -halt-on-error main.tex
```

The source uses framed placeholders for manuscript figures that have not been
provided as public files, so absence of those optional images does not prevent
compilation.
