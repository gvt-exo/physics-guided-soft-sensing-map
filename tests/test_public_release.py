#!/usr/bin/env python3
"""Data-free checks for the public repository and committed derived outputs."""

from __future__ import annotations

import csv
import hashlib
import math
import re
import subprocess
from collections import defaultdict
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RAW_SUFFIXES = {".xlsx", ".xls", ".xlsm", ".xlsb", ".ods", ".mat", ".parquet", ".feather"}
REQUIRED = [
    "README.md",
    "CITATION.cff",
    "docs/DATA_REQUIREMENTS.md",
    "run_publication_validation.m",
    "run_extended_validation.m",
    "results/publication/VALIDATION.md",
    "results/publication/metrics_summary.csv",
    "results/publication_extended/VALIDATION_EXTENDED.md",
    "results/publication_extended/metrics_summary.csv",
    "results/publication_extended/metrics_per_split.csv",
    "results/publication_extended/heldout_predictions.csv",
]
EXPECTED_FIGURES = {
    "fig_extended_validation_timeline.pdf",
    "soft_sensor_architecture.pdf",
    "fig_extended_adaptation_comparison.pdf",
    "fig_extended_transfer_timeseries.pdf",
}


def read_csv(relative: str) -> list[dict[str, str]]:
    with (ROOT / relative).open(newline="", encoding="utf-8-sig") as stream:
        return list(csv.DictReader(stream))


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def matlab_decimal(value: str, places: int, signed: bool = False) -> str:
    quantum = Decimal(1).scaleb(-places)
    rounded = Decimal(value).quantize(quantum, rounding=ROUND_HALF_UP)
    return f"{rounded:+.{places}f}" if signed else f"{rounded:.{places}f}"


def close(actual: float, expected: float, tolerance: float = 1e-11) -> None:
    assert math.isclose(actual, expected, rel_tol=tolerance, abs_tol=tolerance), (actual, expected)


def check_prediction_summary(directory: str) -> None:
    predictions = read_csv(f"{directory}/heldout_predictions.csv")
    summary = read_csv(f"{directory}/metrics_summary.csv")
    per_split = read_csv(f"{directory}/metrics_per_split.csv")
    grouped: dict[tuple[str, str], list[dict[str, str]]] = defaultdict(list)
    grouped_split: dict[tuple[str, str, str], list[dict[str, str]]] = defaultdict(list)
    for row in predictions:
        grouped[(row["Scenario"], row["Model"])].append(row)
        grouped_split[(row["Scenario"], row["SplitID"], row["Model"])].append(row)

    for row in summary:
        key = (row["Scenario"], row["Model"])
        values = grouped[key]
        assert len(values) == int(row["NTest"]), key
        mo = [float(item["MO_Residual"]) for item in values]
        rho = [float(item["Rho_Residual"]) for item in values]
        close(math.sqrt(sum(x * x for x in mo) / len(mo)), float(row["RMSE_MO"]))
        close(sum(abs(x) for x in mo) / len(mo), float(row["MAE_MO"]))
        close(sum(mo) / len(mo), float(row["Bias_MO"]))
        # MATLAB subtraction leaves nominal boundary values on either side of
        # the binary threshold; CSV round-tripping makes a strict comparison
        # the stable cross-language equivalent for these committed outputs.
        close(sum(abs(x) < 0.03 for x in mo) / len(mo), float(row["FractionWithin_MO_0p03"]))
        close(math.sqrt(sum(x * x for x in rho) / len(rho)), float(row["RMSE_Rho"]))
        close(sum(abs(x) for x in rho) / len(rho), float(row["MAE_Rho"]))
        close(sum(rho) / len(rho), float(row["Bias_Rho"]))
        close(sum(abs(x) < 0.01 for x in rho) / len(rho), float(row["FractionWithin_Rho_0p01"]))

    for row in per_split:
        key = (row["Scenario"], row["SplitID"], row["Model"])
        values = grouped_split[key]
        assert len(values) == int(row["NTest"]), key
        mo = [float(item["MO_Residual"]) for item in values]
        rho = [float(item["Rho_Residual"]) for item in values]
        close(math.sqrt(sum(x * x for x in mo) / len(mo)), float(row["RMSE_MO"]))
        close(sum(abs(x) for x in mo) / len(mo), float(row["MAE_MO"]))
        close(sum(mo) / len(mo), float(row["Bias_MO"]))
        close(math.sqrt(sum(x * x for x in rho) / len(rho)), float(row["RMSE_Rho"]))
        close(sum(abs(x) for x in rho) / len(rho), float(row["MAE_Rho"]))
        close(sum(rho) / len(rho), float(row["Bias_Rho"]))


def check_markdown_summary(directory: str, report_name: str, extended: bool) -> None:
    report = (ROOT / directory / report_name).read_text(encoding="utf-8")
    for row in read_csv(f"{directory}/metrics_summary.csv"):
        prefix = [row["Scenario"], row["Model"], row["NSplits"]]
        if extended:
            prefix.append(row["NTest"])
        else:
            prefix.extend([f'{row["NTrainMin"]}-{row["NTrainMax"]}', row["NTest"]])
        values = [
            matlab_decimal(row["RMSE_MO"], 4),
            matlab_decimal(row["MAE_MO"], 4),
            matlab_decimal(row["Bias_MO"], 4, signed=True),
            matlab_decimal(row["P95AbsError_MO"], 4),
            matlab_decimal(row["FractionWithin_MO_0p03"], 3),
            matlab_decimal(row["RMSE_Rho"], 4),
            matlab_decimal(row["MAE_Rho"], 4),
            matlab_decimal(row["Bias_Rho"], 4, signed=True),
            matlab_decimal(row["P95AbsError_Rho"], 4),
            matlab_decimal(row["FractionWithin_Rho_0p01"], 3),
        ]
        expected = "| " + " | ".join(prefix + values) + " |"
        assert expected in report, expected


def main() -> None:
    for relative in REQUIRED:
        assert (ROOT / relative).is_file(), relative

    tracked = subprocess.check_output(
        ["git", "ls-files"], cwd=ROOT, text=True, encoding="utf-8"
    ).splitlines()
    raw = [path for path in tracked if Path(path).suffix.lower() in RAW_SUFFIXES]
    assert not raw, f"Tracked private-data candidates: {raw}"

    figures = {path.name for path in (ROOT / "paper" / "figures").iterdir() if path.is_file() and path.name != "README.md"}
    assert figures == EXPECTED_FIGURES, figures
    arxiv_figures = {path.name for path in (ROOT / "paper" / "arxiv" / "figures").iterdir() if path.is_file()}
    assert arxiv_figures == EXPECTED_FIGURES, arxiv_figures
    assert digest(ROOT / "paper" / "main.tex") == digest(ROOT / "paper" / "arxiv" / "main.tex")
    assert digest(ROOT / "paper" / "references.bib") == digest(ROOT / "paper" / "arxiv" / "references.bib")
    for name in EXPECTED_FIGURES:
        assert digest(ROOT / "paper" / "figures" / name) == digest(ROOT / "paper" / "arxiv" / "figures" / name)

    citation = (ROOT / "CITATION.cff").read_text(encoding="utf-8")
    assert "cff-version: 1.2.0" in citation
    assert citation.count("family-names:") == 4

    text_suffixes = {".m", ".md", ".tex", ".bib", ".yml", ".yaml", ".cff", ".py"}
    windows_user_root = r"[A-Za-z]:" + re.escape("\\" + "Users" + "\\")
    unix_user_root = "/" + "Users" + "/"
    unix_home_root = "/" + "home" + "/"
    absolute_path = re.compile(f"(?:{windows_user_root}|{unix_user_root}|{unix_home_root})")
    path_hits = []
    for relative in tracked:
        path = ROOT / relative
        if path.is_file() and path.suffix.lower() in text_suffixes:
            content = path.read_text(encoding="utf-8", errors="replace")
            if absolute_path.search(content):
                path_hits.append(relative)
    assert not path_hits, f"Tracked local absolute paths: {path_hits}"

    extended_counts = {row["Item"]: int(row["Count"]) for row in read_csv("results/publication_extended/dataset_counts.csv")}
    assert extended_counts["process_rows_total"] == 260642
    assert extended_counts["laboratory_pairs_complete_total"] == 1325

    splits = read_csv("results/publication_extended/splits.csv")
    rolling = [row for row in splits if row["Scenario"] == "post_repair_comparison"]
    assert len(rolling) == 10
    assert all(row["Eligible"] in {"1", "true", "True"} for row in rolling)
    assert min(int(row["NTrainAligned"]) for row in rolling) >= 40
    assert min(int(row["NTestAligned"]) for row in rolling) >= 10

    check_prediction_summary("results/publication")
    check_prediction_summary("results/publication_extended")
    check_markdown_summary("results/publication", "VALIDATION.md", extended=False)
    check_markdown_summary("results/publication_extended", "VALIDATION_EXTENDED.md", extended=True)
    print("Public-release checks passed.")


if __name__ == "__main__":
    main()
