# verified_schedule1-8.xlsx

[Back to RA Data Guide](00a_data_guide.md)

## File Role in Workflow

`verified_schedule1-8.xlsx` represents the verified Excel schedule files created from the original TSUS PDFs. These files are the first structured data input in the TSUS workflow: they translate the raw tariff schedules into rows and columns that can be imported by [`01a_append.do`](../analysis_guide/01a_append.md).

This file guide explains the role of the verified schedules as data inputs. The detailed rules for entering, interpreting, and verifying TSUS schedule information are documented separately in [TSUS Source and Data Conventions](00b_tsus_source_and_data_conventions.md).

## What This File Contains

The verified schedule files contain digitized TSUS schedule information for schedules 1 through 8. They preserve the core fields needed for later cleaning and analysis, including:

- tariff item codes;
- suffix codes;
- specific and ad valorem duty values;
- unit information;
- notes copied or summarized from the source schedules;
- flags for entries requiring special interpretation.

The schedules are stored as Excel files before being imported into Stata. Formatting choices such as text-formatted cells, preserved suffix values, and note fields matter because the later Stata scripts depend on these fields being readable and consistent.

## How It Is Produced

The verified schedules are created by digitizing the original TSUS PDF schedules into Excel and then checking the entered data against the source documents. The digitization and verification process follows the conventions in [TSUS Source and Data Conventions](00b_tsus_source_and_data_conventions.md).

This guide does not restate those conventions. Instead, it documents the resulting Excel files as the workflow input used by the Stata pipeline.

## How It Is Used Next

[`01a_append.do`](../analysis_guide/01a_append.md) imports the verified schedule Excel files, standardizes selected variable types, reshapes the schedule data, and appends schedules 1 through 8 into one combined TSUS dataset.

The output of that step is [`tsus_appended.dta`](01b_tsus_appended.dta.md).

# tsus_appended.dta

[Back to RA Data Guide](00a_data_guide.md)

## File Role in Workflow

`tsus_appended.dta` is the intermediate Stata dataset created from the verified Excel schedule files. It combines schedules 1-8 after import, type standardization, reshape, and append, and prepares the data for suffix cleaning and TSUSA code construction in [`01b_suffix_fix.do`](../analysis_guide/01b_suffix_fix.md).

## Created From

- [`verified_schedule1-8.xlsx`](01a_verified_schedule1-8.xlsx.md)

## Created By

- [`01a_append.do`](../analysis_guide/01a_append.md)

## What This File Contains

- Schedule 1-8 data imported from the verified Excel schedule files.
- One combined Stata dataset after the individual schedules are appended together.
- Tariff item codes, suffixes, units, duty values, notes, flags, and year-specific rate columns after the initial import and reshape steps.

## How This File Is Created

By the time this file is created:

- the verified Excel schedules have been imported into Stata;
- schedule-level files have been combined into one dataset;
- key columns have been standardized so they can be appended together;
- year-specific duty columns have been reshaped into a long format;
- the data is ready for suffix cleaning and TSUSA code construction in [`01b_suffix_fix.do`](../analysis_guide/01b_suffix_fix.md).

This file is not the final cleaned tariff dataset. It is an intermediate file used before suffix corrections, TSUSA construction, reference-rate fixes, and row expansion are applied.

# tsus_uncorrected.dta

[Back to RA Data Guide](00a_data_guide.md)

## File Role in Workflow

`tsus_uncorrected.dta` is the suffix-stage intermediate dataset created after suffix cleaning, TSUSA code creation, 320-331 and 301-302 reference-rate corrections, suffix-row expansion, and year extension. In this workflow, "uncorrected" means that the dataset has not yet gone through the final duty-variable cleaning step in [`01c_clean_duties.do`](../analysis_guide/01c_clean_duties.md).

## Created From

- [`tsus_appended.dta`](01b_tsus_appended.dta.md)

## Created By

- [`01b_suffix_fix.do`](../analysis_guide/01b_suffix_fix.md)

## Used By

- [`01c_clean_duties.do`](../analysis_guide/01c_clean_duties.md)

## How This File Is Created

`tsus_uncorrected.dta` is created by running [`01b_suffix_fix.do`](../analysis_guide/01b_suffix_fix.md) on [`tsus_appended.dta`](01b_tsus_appended.dta.md). This step turns the appended schedule data into the suffix-fixed TSUS tariff dataset.

The suffix-fixing step also handles the reference-rate cases. For the 320-331 series, item 320 is the base group, and rates for 321-331 are calculated from the corresponding 320 rate plus the additional rate assigned to each series:

```text
321-331 rate = corresponding 320 base rate + series-specific additional rate
```

For the 301-302 series, item 301 is the base group, and the 302 rate is calculated from the corresponding 301 rate plus the additional 302 rate:

```text
302 rate = corresponding 301 base rate + 302 additional rate
```

The corresponding base rate means the rate with the same suffix code.

The following tables are illustrative examples, not actual data from the file. They show how reference-rate entries are converted before the final duty-cleaning step.

320-series example:

Before suffix-fixing code:

| item | suffix | duty rate shown in source |
|---:|---:|---|
| 320 | 10 | 5 |
| 321 | 10 | 2 |
| 322 | 10 | 3 |
| 331 | 10 | 6 |

After suffix-fixing code:

| item | suffix | duty1_ad |
|---:|---:|---:|
| 320 | 10 | 5 |
| 321 | 10 | 7 |
| 322 | 10 | 8 |
| 331 | 10 | 11 |

301-series example:

Before suffix-fixing code:

| item | suffix | duty rate shown in source |
|---:|---:|---|
| 301 | 20 | 4 |
| 302 | 20 | 1.5 |

After suffix-fixing code:

| item | suffix | duty1_ad |
|---:|---:|---:|
| 301 | 20 | 4 |
| 302 | 20 | 5.5 |

By the time this file is created:

- leading and trailing spaces have been removed from `item` and `suffix`;
- known non-code suffix markers, specifically `"."` and `"1/"`, have been removed;
- remaining suffix values have been checked to make sure they contain only digits or are blank;
- `tsusa` codes have been created by combining the 5-digit item code with the suffix code, and recreated after suffix expansion;
- 320-331 and 301-302 reference-rate cases have been handled;
- rows that apply to multiple suffix codes have been expanded so that duty rates are recorded at the correct suffix level;
- 1973-1975 rows have been added by copying the 1972 row structure;
- specific-duty fields have been parsed and converted into numeric values after the suffix expansion step.

This file is the suffix-fixed tariff dataset in the workflow. Unlike [`tsus_appended.dta`](01b_tsus_appended.dta.md), it is no longer just the combined import of schedules 1-8; it includes the suffix corrections, TSUSA construction, rate fixes, and row expansions needed before final duty cleaning.

# tsus_final.dta

[Back to RA Data Guide](00a_data_guide.md)

## File Role in Workflow

`tsus_final.dta` is the final cleaned TSUS tariff dataset created after [`tsus_uncorrected.dta`](01c_tsus_uncorrected.dta.md) has gone through final duty-variable cleanup. It inherits the suffix, TSUSA, and reference-rate corrections created in [`01b_suffix_fix.do`](../analysis_guide/01b_suffix_fix.md), then applies the final cleaning needed for diagnostics, figures, weights, and trade-data merges.

## Created From

- [`tsus_uncorrected.dta`](01c_tsus_uncorrected.dta.md)

## Created By

- [`01c_clean_duties.do`](../analysis_guide/01c_clean_duties.md)

## Used By

- [`01d_diagnostics.do`](../analysis_guide/01d_diagnostics.md)
- [`02_merge.do`](../analysis_guide/02_merge.md)

## How This File Is Created

`tsus_final.dta` is created by running [`01c_clean_duties.do`](../analysis_guide/01c_clean_duties.md) on [`tsus_uncorrected.dta`](01c_tsus_uncorrected.dta.md). This step takes the suffix-fixed intermediate dataset and performs the final duty-variable cleanup needed before diagnostics, figures, weighting, and trade-data merges.

Later, [`02_merge.do`](../analysis_guide/02_merge.md) reloads this file for weighting and trade-data merge steps.

The 320-331 and 301-302 reference-rate corrections are not calculated in this step. They are inherited from [`tsus_uncorrected.dta`](01c_tsus_uncorrected.dta.md), which is created by [`01b_suffix_fix.do`](../analysis_guide/01b_suffix_fix.md).

By the time this file is created:

- duty variables have been checked for missing and non-numeric values;
- known text entries such as `base rate` have been recoded for later numeric processing;
- duty variables, `tsusa`, and `item` have been converted to numeric values where needed;
- selected 1969-1975 ad valorem duty values have been filled with the 1968 rate when the post-1968 values are all zero and the 1968 rate is positive;
- the dataset is ready to be used by [`01d_diagnostics.do`](../analysis_guide/01d_diagnostics.md) for diagnostics and figures and by [`02_merge.do`](../analysis_guide/02_merge.md) for weights and trade-data merges.

This file is the final cleaned tariff dataset in the workflow. Unlike `tsus_uncorrected.dta`, it has gone through the final duty-variable cleanup step and is the dataset used for downstream analysis outputs.

# tsus_final_weights.dta

[Back to RA Data Guide](00a_data_guide.md)

## File Role in Workflow

`tsus_final_weights.dta` is an intermediate weighted tariff file created by calculating quantity-based `spec_weight` values from 1976 import data and merging those weights onto the cleaned TSUS dataset.

## Created From

- [`tsus_final.dta`](01d_tsus_final.dta.md)
- [`Imports-1976.dta`](https://sumailsyr-my.sharepoint.com/shared?id=%2Fpersonal%2Fskhan78%5Fsyr%5Fedu%2FDocuments%2FTariff%2DRA%2DData%2FAnalysis%2FData%20Files%2FRaw%20Files%2FTrade%5Fdata&listurl=%2Fpersonal%2Fskhan78%5Fsyr%5Fedu%2FDocuments&viewid=86dc3307%2D03bb%2D450c%2D8873%2D3d25737bc75a&sharingv2=true&fromShare=true&at=9&CT=1779052695969&OR=OWA%2DNT%2DMail&FolderCTID=0x012000FA572F48052EFB478E38BA7D6582FC25)

## Created By

- [`02_merge.do`](../analysis_guide/02_merge.md)

## How This File Is Created

`tsus_final_weights.dta` is created in [`02_merge.do`](../analysis_guide/02_merge.md). The script uses [`Imports-1976.dta`](https://sumailsyr-my.sharepoint.com/shared?id=%2Fpersonal%2Fskhan78%5Fsyr%5Fedu%2FDocuments%2FTariff%2DRA%2DData%2FAnalysis%2FData%20Files%2FRaw%20Files%2FTrade%5Fdata&listurl=%2Fpersonal%2Fskhan78%5Fsyr%5Fedu%2FDocuments&viewid=86dc3307%2D03bb%2D450c%2D8873%2D3d25737bc75a&sharingv2=true&fromShare=true&at=9&CT=1779052695969&OR=OWA%2DNT%2DMail&FolderCTID=0x012000FA572F48052EFB478E38BA7D6582FC25) to calculate quantity-based `spec_weight` values for selected schedule 6 TSUS items. It first converts `tsusa` to numeric, keeps schedule 6 items, and then keeps the selected TSUS codes that need product weights.

The weight is calculated as:

```text
spec_weight = con_qy2_yr / (con_qy1_yr + con_qy2_yr)
```

This gives the share of quantity 2 in total quantity 1 plus quantity 2. Because the 1976 import data can have multiple observations for the same `tsusa`, the script averages `spec_weight` by `tsusa` to create one product-level weight per TSUS code.

The product-level weights are then merged onto [`tsus_final.dta`](01d_tsus_final.dta.md). The output keeps the cleaned TSUS tariff data and adds `spec_weight` where a matching 1976 weight is available.

Compared with [`tsus_final.dta`](01d_tsus_final.dta.md), this file keeps the cleaned TSUS data structure but adds 1976 import-based `spec_weight` values for analyses that require weighted specific-duty measures.

# trade_appended.dta

[Back to RA Data Guide](00a_data_guide.md)

## File Role in Workflow

`trade_appended.dta` is the combined import trade dataset created from the 1968-1972 raw import files. It is used as the trade-data input for creating [`tsus_trade_merged.dta`](02b_tsus_trade_merged.dta.md).

## Created From

- [`Imports-1968.dta`](https://sumailsyr-my.sharepoint.com/shared?id=%2Fpersonal%2Fskhan78%5Fsyr%5Fedu%2FDocuments%2FTariff%2DRA%2DData%2FAnalysis%2FData%20Files%2FRaw%20Files%2FTrade%5Fdata&listurl=%2Fpersonal%2Fskhan78%5Fsyr%5Fedu%2FDocuments&viewid=86dc3307%2D03bb%2D450c%2D8873%2D3d25737bc75a&sharingv2=true&fromShare=true&at=9&CT=1779052695969&OR=OWA%2DNT%2DMail&FolderCTID=0x012000FA572F48052EFB478E38BA7D6582FC25)
- [`Imports-1969.dta`](https://sumailsyr-my.sharepoint.com/shared?id=%2Fpersonal%2Fskhan78%5Fsyr%5Fedu%2FDocuments%2FTariff%2DRA%2DData%2FAnalysis%2FData%20Files%2FRaw%20Files%2FTrade%5Fdata&listurl=%2Fpersonal%2Fskhan78%5Fsyr%5Fedu%2FDocuments&viewid=86dc3307%2D03bb%2D450c%2D8873%2D3d25737bc75a&sharingv2=true&fromShare=true&at=9&CT=1779052695969&OR=OWA%2DNT%2DMail&FolderCTID=0x012000FA572F48052EFB478E38BA7D6582FC25)
- [`Imports-1970.dta`](https://sumailsyr-my.sharepoint.com/shared?id=%2Fpersonal%2Fskhan78%5Fsyr%5Fedu%2FDocuments%2FTariff%2DRA%2DData%2FAnalysis%2FData%20Files%2FRaw%20Files%2FTrade%5Fdata&listurl=%2Fpersonal%2Fskhan78%5Fsyr%5Fedu%2FDocuments&viewid=86dc3307%2D03bb%2D450c%2D8873%2D3d25737bc75a&sharingv2=true&fromShare=true&at=9&CT=1779052695969&OR=OWA%2DNT%2DMail&FolderCTID=0x012000FA572F48052EFB478E38BA7D6582FC25)
- [`Imports-1971.dta`](https://sumailsyr-my.sharepoint.com/shared?id=%2Fpersonal%2Fskhan78%5Fsyr%5Fedu%2FDocuments%2FTariff%2DRA%2DData%2FAnalysis%2FData%20Files%2FRaw%20Files%2FTrade%5Fdata&listurl=%2Fpersonal%2Fskhan78%5Fsyr%5Fedu%2FDocuments&viewid=86dc3307%2D03bb%2D450c%2D8873%2D3d25737bc75a&sharingv2=true&fromShare=true&at=9&CT=1779052695969&OR=OWA%2DNT%2DMail&FolderCTID=0x012000FA572F48052EFB478E38BA7D6582FC25)
- [`Imports-1972.dta`](https://sumailsyr-my.sharepoint.com/shared?id=%2Fpersonal%2Fskhan78%5Fsyr%5Fedu%2FDocuments%2FTariff%2DRA%2DData%2FAnalysis%2FData%20Files%2FRaw%20Files%2FTrade%5Fdata&listurl=%2Fpersonal%2Fskhan78%5Fsyr%5Fedu%2FDocuments&viewid=86dc3307%2D03bb%2D450c%2D8873%2D3d25737bc75a&sharingv2=true&fromShare=true&at=9&CT=1779052695969&OR=OWA%2DNT%2DMail&FolderCTID=0x012000FA572F48052EFB478E38BA7D6582FC25)

## Created By

- [`02_merge.do`](../analysis_guide/02_merge.md)

## How This File Is Created

`trade_appended.dta` is created in [`02_merge.do`](../analysis_guide/02_merge.md) by loading [`Imports-1968.dta`](https://sumailsyr-my.sharepoint.com/shared?id=%2Fpersonal%2Fskhan78%5Fsyr%5Fedu%2FDocuments%2FTariff%2DRA%2DData%2FAnalysis%2FData%20Files%2FRaw%20Files%2FTrade%5Fdata&listurl=%2Fpersonal%2Fskhan78%5Fsyr%5Fedu%2FDocuments&viewid=86dc3307%2D03bb%2D450c%2D8873%2D3d25737bc75a&sharingv2=true&fromShare=true&at=9&CT=1779052695969&OR=OWA%2DNT%2DMail&FolderCTID=0x012000FA572F48052EFB478E38BA7D6582FC25) and appending the 1969-1972 import files into one Stata dataset.

By the time this file is created:

- the annual import files for 1968-1972 have been combined into one dataset;
- `tsusa` has been converted to a numeric variable so it can be merged with the cleaned tariff data;
- the combined trade file is ready to be merged with [`tsus_final.dta`](01d_tsus_final.dta.md) by `tsusa` and `year`.

Compared with [`tsus_trade_merged.dta`](02b_tsus_trade_merged.dta.md), this file contains only the appended trade data. It does not yet include the cleaned TSUS tariff rates from [`tsus_final.dta`](01d_tsus_final.dta.md).

# tsus_trade_merged.dta

[Back to RA Data Guide](00a_data_guide.md)

## File Role in Workflow

`tsus_trade_merged.dta` is the analysis-ready merge output that combines cleaned TSUS tariff data with appended 1968-1972 import trade files by `tsusa` and `year`.

## Created From

- [`tsus_final.dta`](01d_tsus_final.dta.md)
- [`trade_appended.dta`](02a_trade_appended.dta.md)

## Created By

- [`02_merge.do`](../analysis_guide/02_merge.md)

## How This File Is Created

`tsus_trade_merged.dta` is created near the end of [`02_merge.do`](../analysis_guide/02_merge.md).

The file is built after two inputs are ready:

- [`tsus_final.dta`](01d_tsus_final.dta.md)
  - This is the cleaned TSUS tariff dataset.
  - It contains the tariff schedule structure, cleaned suffixes, `tsusa` codes, duty rates, units, notes, and flags.
- [`trade_appended.dta`](02a_trade_appended.dta.md)
  - This is the combined import trade dataset for 1968-1972.
  - It is created earlier in [`02_merge.do`](../analysis_guide/02_merge.md) by loading [`Imports-1968.dta`](https://sumailsyr-my.sharepoint.com/shared?id=%2Fpersonal%2Fskhan78%5Fsyr%5Fedu%2FDocuments%2FTariff%2DRA%2DData%2FAnalysis%2FData%20Files%2FRaw%20Files%2FTrade%5Fdata&listurl=%2Fpersonal%2Fskhan78%5Fsyr%5Fedu%2FDocuments&viewid=86dc3307%2D03bb%2D450c%2D8873%2D3d25737bc75a&sharingv2=true&fromShare=true&at=9&CT=1779052695969&OR=OWA%2DNT%2DMail&FolderCTID=0x012000FA572F48052EFB478E38BA7D6582FC25) and appending the 1969-1972 import files.

Before the final merge, [`02_merge.do`](../analysis_guide/02_merge.md) prepares the data so the two files can be matched correctly:

- `tsusa` is converted to a numeric variable so the tariff data and trade data use the same merge key format.
- The annual trade files have already been combined into [`trade_appended.dta`](02a_trade_appended.dta.md).
- [`tsus_final.dta`](01d_tsus_final.dta.md) is used as the cleaned tariff base for the merge.

The final merge is run with:

```stata
use "$data\Stata Files\tsus_final.dta", clear

merge 1:m tsusa year using "$data\Stata Files\trade_appended.dta"

save "$data\Stata Files\tsus_trade_merged.dta", replace
```

This is a `1:m` merge because [`tsus_final.dta`](01d_tsus_final.dta.md) is the master file in this step. For each `tsusa`-`year` combination, it provides the cleaned tariff schedule information. [`trade_appended.dta`](02a_trade_appended.dta.md) is the using file, and it can contain multiple import trade records for the same `tsusa`-`year` combination. The merge therefore attaches many possible trade observations to one cleaned tariff observation.

The following tables are an illustrative example, not actual data from the file.

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

This merge means:

- each cleaned tariff observation is matched to trade observations using `tsusa` and `year`;
- `tsusa` identifies the 7-digit tariff item;
- `year` makes sure tariff rates are matched to trade records from the same year;
- the merge allows multiple trade records to match one tariff-year record when the trade file has more detailed observations;
- the resulting dataset keeps the cleaned tariff variables and adds the matched import trade variables.

After the merge:

- compared with [`tsus_final.dta`](01d_tsus_final.dta.md), this file adds import trade data;
- compared with [`trade_appended.dta`](02a_trade_appended.dta.md), this file adds the cleaned TSUS tariff rates and schedule information;
- the file becomes the analysis-ready dataset for work that needs both tariff information and import trade data in the same file.
