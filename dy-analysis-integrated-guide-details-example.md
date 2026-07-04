# Example: More Readable Collapsible File Notes

This file shows one possible way to make the collapsible sections in
`dy-analysis-integrated-guide-readable.md` easier to scan.

The goal is not to remove detail. The goal is to make each expanded section start with
the most useful information, then move into longer explanation only when needed.

## Pattern

Use this structure for each file note:

```md
<details>
<summary><strong>Input: filename.dta</strong> - one-line reason this file matters</summary>

#### Quick View

| Field | Details |
|---|---|
| Role | Short workflow role |
| Created from | `previous_file.dta` |
| Created by | `script.do` |
| Used by | `next_script.do` |

#### What It Contains

- Short bullet.
- Short bullet.
- Short bullet.

#### Notes

One or two short paragraphs for interpretation, edge cases, or examples.

</details>
```

## Example 1: Short Input File Note

This is how a compact file note could look for `tsus_final.dta`.

<details>
<summary><strong>Input: tsus_final.dta</strong> - cleaned TSUS tariff data used by diagnostics and merge steps</summary>

#### Quick View

| Field | Details |
|---|---|
| Role | Final cleaned TSUS tariff dataset |
| Created from | `tsus_uncorrected.dta` |
| Created by | `01c_clean_duties.do` |
| Used by | `01d_diagnostics.do`, `02_merge.do` |

#### What It Contains

- Cleaned tariff schedule structure.
- Cleaned suffixes and `tsusa` codes.
- Duty variables prepared for diagnostics, weighting, and trade-data merges.
- Notes, units, and flags preserved from the earlier TSUS cleaning steps.

#### Why It Matters

`tsus_final.dta` is the main cleaned TSUS file. Diagnostics use it to check tariff-rate
patterns, and `02_merge.do` uses it as the tariff-side input for the trade merge.

</details>

## Example 2: Longer Output File Note

This is how a longer file note could look for `tsus_trade_merged.dta`. The explanation
is still detailed, but it is divided into sections so readers can stop after the part
they need.

<details>
<summary><strong>Output: tsus_trade_merged.dta</strong> - analysis-ready tariff and trade dataset</summary>

#### Quick View

| Field | Details |
|---|---|
| Role | Final merged dataset for tariff-trade analysis |
| Created from | `tsus_final.dta`, `trade_appended.dta` |
| Created by | `02_merge.do` |
| Merge keys | `tsusa`, `year` |
| Merge type | `1:m`, with tariff data as the master file |

#### What It Contains

- Cleaned TSUS tariff variables from `tsus_final.dta`.
- Import trade variables from `trade_appended.dta`.
- Observations matched by `tsusa` and `year`.
- Multiple trade records can attach to one tariff-year record.

#### How It Is Created

`02_merge.do` first prepares the cleaned tariff data and the appended trade data so
both files use the same merge keys. It then loads `tsus_final.dta` as the master file
and merges in `trade_appended.dta`.

```stata
use "$data\Stata Files\tsus_final.dta", clear

merge 1:m tsusa year using "$data\Stata Files\trade_appended.dta"

save "$data\Stata Files\tsus_trade_merged.dta", replace
```

#### How To Read The Merge

The `1:m` merge means each cleaned tariff observation can match multiple trade
observations for the same `tsusa` and `year`.

| Source file | Meaning |
|---|---|
| `tsus_final.dta` | One cleaned tariff record for a tariff item and year |
| `trade_appended.dta` | One or more import trade records for the same tariff item and year |
| `tsus_trade_merged.dta` | The tariff record repeated across the matching trade records |

#### Small Example

`tsus_final.dta` before merge:

| tsusa | year | tariff_rate |
|---:|---:|---:|
| 6012800 | 1968 | 10 |

`trade_appended.dta` before merge:

| tsusa | year | city_code | import_value |
|---:|---:|---:|---:|
| 6012800 | 1968 | 101 | 2500 |
| 6012800 | 1968 | 205 | 1800 |
| 6012800 | 1968 | 318 | 950 |

`tsus_trade_merged.dta` after merge:

| tsusa | year | tariff_rate | city_code | import_value |
|---:|---:|---:|---:|---:|
| 6012800 | 1968 | 10 | 101 | 2500 |
| 6012800 | 1968 | 10 | 205 | 1800 |
| 6012800 | 1968 | 10 | 318 | 950 |

#### Bottom Line

Compared with `tsus_final.dta`, this file adds import trade data. Compared with
`trade_appended.dta`, this file adds cleaned TSUS tariff information.

</details>

## Example 3: Annual Trade Inputs Without Repeating The Same Long Link

For repeated raw files, avoid listing the same long source link five times. Use one
source-folder link and list the annual files plainly.

<details>
<summary><strong>Inputs: Imports-1968.dta through Imports-1972.dta</strong> - annual trade files appended by 02_merge.do</summary>

#### Quick View

| Field | Details |
|---|---|
| Role | Raw annual trade inputs |
| Years | 1968, 1969, 1970, 1971, 1972 |
| Created by | External trade-data source |
| Used by | `02_merge.do` |
| Output created | `trade_appended.dta` |

#### Input Files

- `Imports-1968.dta`
- `Imports-1969.dta`
- `Imports-1970.dta`
- `Imports-1971.dta`
- `Imports-1972.dta`

#### What They Become

`02_merge.do` appends these separate annual files into `trade_appended.dta`. The
appended trade file is then merged with `tsus_final.dta` to create
`tsus_trade_merged.dta`.

</details>

## Why This Reads Better

- The collapsed line tells readers whether the section is worth opening.
- The first expanded item is always a `Quick View` table.
- Long explanations are broken into named subsections.
- Bullets are shown as normal Markdown, not inside a code block.
- Repeated links and repeated wording are reduced.

