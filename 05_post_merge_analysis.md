* Post-merge analysis: build panels, inspect distributions, and analyze changes in tariffs and import values.

cd "C:\Users\USER\Desktop\Tariff-RA-Data"

capture log close
log using "Analysis\Codes\05_post_merge_analysis_log.smcl", replace

global data "Analysis\Data Files"
global figures "Analysis\Figures"

* This file starts from tsus_trade_merged.dta, builds analysis panels,
* and examines relationships among tariff rates, tariff amounts, and changes in import values.


* ===========================================================================
* Main workflow
* ===========================================================================

capture program drop run_post_merge_analysis
program define run_post_merge_analysis
    prepare_merged_output
    * Load the merged tariff-trade data and check the variables required for analysis.

    build_tsusa_year_panel
    * Aggregate matched observations into a TSUSA-year panel.

    build_country_year_panel
    * Aggregate matched observations into a TSUSA-country-year panel.

    inspect_import_tariff_dist
    * Inspect the distributions of import values and tariff amounts.
    * Create histograms and import-value versus tariff-amount scatterplots.

    analyze_tariff_rates_and_amounts
    * Check whether products with higher tariff rates also have larger tariff amounts.

    analyze_import_value_changes
    * Compare changes in tariff rates and import values between 1968 and 1972.

    make_binned_tariff_change_graph
    * Bin tariff-rate changes and graph the corresponding mean changes.
end


* ===========================================================================
* Detailed code
* ===========================================================================

* ---------------------------------------------------------------------------
* 1. Load the merged tariff-trade data and create tariff-amount variables
* ---------------------------------------------------------------------------

capture program drop prepare_merged_output
program define prepare_merged_output
    * Load the completed merge, which is the starting point for all subsequent analysis.
    use "$data\Stata Files\tsus_trade_merged.dta", clear

    * Give the merge-result variable a more descriptive name if it is still called _merge.
    capture confirm variable tariff_merge_status
    if _rc {
        rename _merge tariff_merge_status
    }

    * Create an empty tariff-amount variable if it does not already exist.
    capture confirm variable total_tariff_amount1
    if _rc {
        gen total_tariff_amount1 = .
    }
    * Tariff amount 1 = ad valorem component + specific-duty component.
    replace total_tariff_amount1 = con_val_yr * (duty1_ad / 100) + con_qy1_yr * duty1_spec

    * Prepare the second tariff-amount variable in the same way.
    capture confirm variable total_tariff_amount2
    if _rc {
        gen total_tariff_amount2 = .
    }
    * Tariff amount 2 uses the second set of duty measures.
    replace total_tariff_amount2 = con_val_yr * (duty2_ad / 100) + con_qy1_yr * duty2_spec

    * Save the calculated tariff amounts back to the merged dataset.
    save "$data\Stata Files\tsus_trade_merged.dta", replace
end

* Notes:
*   Input: tsus_trade_merged.dta
*   - Rename _merge to tariff_merge_status when needed.
*   - Create total_tariff_amount1 and total_tariff_amount2 when needed.
*   - Save the updated merged dataset.


* ---------------------------------------------------------------------------
* 2. Aggregate matched data into a TSUSA-year import panel
* ---------------------------------------------------------------------------

capture program drop build_tsusa_year_panel
program define build_tsusa_year_panel
    * Reload the merged data to build the product-year panel.
    use "$data\Stata Files\tsus_trade_merged.dta", clear

    * Keep observations matched in both the tariff and trade data.
    keep if tariff_merge_status == 3

    * Combine multiple trade records within each TSUSA-year using sums or means.
    collapse ///
        (sum) con_val_yr con_qy1_yr gen_val_yr gen_qy1_yr ///
              ves_val_yr ves_wgt_yr air_val_yr air_wgt_yr ///
              total_tariff_amount1 total_tariff_amount2 ///
        (mean) duty1_spec duty2_spec duty1_ad duty2_ad, ///
        by(tsusa year)

    * Verify that TSUSA-year uniquely identifies observations.
    sort tsusa year
    isid tsusa year

    * Save the product-year panel.
    save "$data\Stata Files\tsus_trade_tsusa_year_conval_panel.dta", replace
end

* Notes:
*   Input: tsus_trade_merged.dta
*   Output: tsus_trade_tsusa_year_conval_panel.dta
*   - Keep observations matched in both source datasets.
*   - Aggregate values, quantities, and tariff amounts by TSUSA-year.
*   - Save one observation per TSUSA-year.


* ---------------------------------------------------------------------------
* 3. Aggregate matched data into a TSUSA-country-year panel
* ---------------------------------------------------------------------------

capture program drop build_country_year_panel
program define build_country_year_panel
    * Reload the merged data to build the product-country-year panel.
    use "$data\Stata Files\tsus_trade_merged.dta", clear

    * Keep observations matched in both the tariff and trade data.
    keep if tariff_merge_status == 3

    * Combine records within each TSUSA-country-year using sums or means.
    collapse ///
        (sum) con_val_yr con_qy1_yr gen_val_yr gen_qy1_yr ///
              ves_val_yr ves_wgt_yr air_val_yr air_wgt_yr ///
              total_tariff_amount1 total_tariff_amount2 ///
        (mean) duty1_spec duty2_spec duty1_ad duty2_ad, ///
        by(tsusa cty_code year)

    * Verify that TSUSA-country-year uniquely identifies observations.
    sort tsusa cty_code year
    isid tsusa cty_code year

    * Create a panel ID from the TSUSA and country-code combination.
    egen panel_id = group(tsusa cty_code)
    * Declare the panel ID-year structure for subsequent panel commands.
    xtset panel_id year

    * Save the country-specific product-year panel.
    save "$data\Stata Files\tsus_trade_country_year_conval_panel.dta", replace
end

* Notes:
*   Input: tsus_trade_merged.dta
*   Output: tsus_trade_country_year_conval_panel.dta
*   - Keep observations matched in both source datasets.
*   - Aggregate values, quantities, and tariff amounts by TSUSA-country-year.
*   - Create panel_id and declare the panel structure with xtset.


* ---------------------------------------------------------------------------
* Shared helper. Clean tariff inputs and recalculate tariff amounts
* ---------------------------------------------------------------------------

capture program drop clean_tariff_inputs
program define clean_tariff_inputs
    * Keep positive import values for logarithms and effective-rate calculations.
    keep if con_val_yr > 0

    * Treat 999999 as a sentinel rather than an actual duty value.
    replace duty1_spec = . if duty1_spec == 999999
    replace duty2_spec = . if duty2_spec == 999999

    * Preserve the original duty variables and create calculation-only copies.
    gen duty1_ad_calc = duty1_ad
    gen duty2_ad_calc = duty2_ad
    gen duty1_spec_calc = duty1_spec
    gen duty2_spec_calc = duty2_spec

    * Treat missing duty components as zero when calculating tariff amounts.
    replace duty1_ad_calc = 0 if missing(duty1_ad_calc)
    replace duty2_ad_calc = 0 if missing(duty2_ad_calc)
    replace duty1_spec_calc = 0 if missing(duty1_spec_calc)
    replace duty2_spec_calc = 0 if missing(duty2_spec_calc)

    * Recalculate tariff amounts using the cleaned duty variables.
    replace total_tariff_amount1 = con_val_yr * (duty1_ad_calc / 100) + con_qy1_yr * duty1_spec_calc
    replace total_tariff_amount2 = con_val_yr * (duty2_ad_calc / 100) + con_qy1_yr * duty2_spec_calc
end

* Notes:
*   Used by: inspect_import_tariff_dist, analyze_tariff_rates_and_amounts,
*                 prepare_1968_1972_change_data
*   - Keep observations with positive import values.
*   - Treat specific-duty value 999999 as missing.
*   - Replace missing duty components with zero and recalculate tariff amounts.


* ---------------------------------------------------------------------------
* 4. Examine the distributions and correlations of log import values and log tariff amounts with graphs
* ---------------------------------------------------------------------------

capture program drop inspect_import_tariff_dist
program define inspect_import_tariff_dist
    * Load the product-year panel to examine distributions and correlations.
    use "$data\Stata Files\tsus_trade_tsusa_year_conval_panel.dta", clear

    * Clean special tariff values and missing duty components.
    clean_tariff_inputs

    * Create logarithms because import values and tariff amounts may be right-skewed.
    gen ln_con_val = ln(con_val_yr) if con_val_yr > 0
    gen ln_tariff_amount1 = ln(total_tariff_amount1) if total_tariff_amount1 > 0
    gen ln_tariff_amount2 = ln(total_tariff_amount2) if total_tariff_amount2 > 0

    * First examine the distributions of the original and logged values numerically.
    summarize con_val_yr total_tariff_amount1 total_tariff_amount2 ///
              ln_con_val ln_tariff_amount1 ln_tariff_amount2, detail

    * Graph 4a: Show the distribution of total import values across TSUSA-year observations.
    * This graph checks whether import values are concentrated among a small number of large products.
    histogram ln_con_val, ///
        title("Distribution of Log Import Value") ///
        xtitle("Log Consumption Import Value") ///
        ytitle("Frequency")

    graph export "$figures\hist_log_import_value.pdf", as(pdf) replace

    * Graph 4b: Show the distribution of tariff amount 1 across TSUSA-year observations.
    * Check whether tariff amount 1 is skewed or contains many small values.
    histogram ln_tariff_amount1, ///
        title("Distribution of Log Tariff Amount 1") ///
        xtitle("Log Tariff Amount 1") ///
        ytitle("Frequency")

    graph export "$figures\hist_log_tariff_amount1.pdf", as(pdf) replace

    * Graph 4c: Show the distribution of tariff amount 2 across TSUSA-year observations.
    * Check whether the distribution of tariff amount 2 is similar to or different from tariff amount 1.
    histogram ln_tariff_amount2, ///
        title("Distribution of Log Tariff Amount 2") ///
        xtitle("Log Tariff Amount 2") ///
        ytitle("Frequency")

    graph export "$figures\hist_log_tariff_amount2.pdf", as(pdf) replace

    * Examine the simple correlations between log import value and log tariff amounts.
    correlate ln_con_val ln_tariff_amount1 ln_tariff_amount2

    * Graph 4d: Show the relationship between import value and tariff amount 1.
    * Check whether products with larger import values mechanically have larger tariff amount 1 values.
    twoway ///
        (scatter ln_tariff_amount1 ln_con_val) ///
        (lfit ln_tariff_amount1 ln_con_val), ///
        title("Import Value and Tariff Amount 1") ///
        xtitle("Log Import Value") ///
        ytitle("Log Tariff Amount 1") ///
        legend(label(1 "TSUSA-year observations") label(2 "Linear fit"))

    graph export "$figures\scatter_import_value_tariff_amount1.pdf", as(pdf) replace

    * Graph 4e: Show the relationship between import value and tariff amount 2.
    * Re-examine the import-value-to-tariff-amount relationship using tariff amount 2.
    twoway ///
        (scatter ln_tariff_amount2 ln_con_val) ///
        (lfit ln_tariff_amount2 ln_con_val), ///
        title("Import Value and Tariff Amount 2") ///
        xtitle("Log Import Value") ///
        ytitle("Log Tariff Amount 2") ///
        legend(label(1 "TSUSA-year observations") label(2 "Linear fit"))

    graph export "$figures\scatter_import_value_tariff_amount2.pdf", as(pdf) replace

    * Use a simple regression to examine how much import value explains tariff amount 1.
    reg ln_tariff_amount1 ln_con_val
    * Use the same approach to examine how much import value explains tariff amount 2.
    reg ln_tariff_amount2 ln_con_val
end

* Notes:
*   Input data: tsus_trade_tsusa_year_conval_panel.dta
*   Output graphs:
*     hist_log_import_value.pdf
*     hist_log_tariff_amount1.pdf
*     hist_log_tariff_amount2.pdf
*     scatter_import_value_tariff_amount1.pdf
*     scatter_import_value_tariff_amount2.pdf
*   - Create log import-value and log tariff-amount variables.
*   - Examine the original and logged variables using summary statistics.
*   - Save histograms of import values and tariff amounts.
*   - Examine correlations between import values and tariff amounts.
*   - Save scatterplots with fitted lines.


* ---------------------------------------------------------------------------
* 5. Compare the relationship between effective tariff rates and log tariff amounts
* ---------------------------------------------------------------------------

capture program drop analyze_tariff_rates_and_amounts
program define analyze_tariff_rates_and_amounts
    * Load the product-year panel to examine the relationship between tariff rates and tariff amounts.
    use "$data\Stata Files\tsus_trade_tsusa_year_conval_panel.dta", clear

    * Clean special tariff values and missing duty components.
    clean_tariff_inputs

    * Effective tariff rate = tariff amount / import value * 100.
    gen eff_tariff_rate1 = total_tariff_amount1 / con_val_yr * 100 if con_val_yr > 0
    gen eff_tariff_rate2 = total_tariff_amount2 / con_val_yr * 100 if con_val_yr > 0

    * Create indicators for whether tariff amounts are positive.
    gen has_tariff1 = total_tariff_amount1 > 0 if !missing(total_tariff_amount1)
    gen has_tariff2 = total_tariff_amount2 > 0 if !missing(total_tariff_amount2)
    gen has_tariff_any = has_tariff1 == 1 | has_tariff2 == 1

    * Summarize the distributions of tariff rates and tariff amounts, and check whether tariffs are imposed by year.
    summarize duty1_spec duty2_spec duty1_ad duty2_ad eff_tariff_rate1 eff_tariff_rate2, detail
    tab year has_tariff_any
    bysort year: summarize con_val_yr total_tariff_amount1 total_tariff_amount2 eff_tariff_rate1 eff_tariff_rate2

    * Use log tariff amounts in graphs and regressions because tariff amounts vary substantially in magnitude.
    gen ln_tariff_amount1 = ln(total_tariff_amount1) if total_tariff_amount1 > 0
    gen ln_tariff_amount2 = ln(total_tariff_amount2) if total_tariff_amount2 > 0

    * Graph 5a: Show the relationship between effective tariff rate 1 and tariff amount 1.
    * Check whether products with higher tariff rates also have larger tariff amount 1 values.
    twoway ///
        (scatter ln_tariff_amount1 eff_tariff_rate1) ///
        (lfit ln_tariff_amount1 eff_tariff_rate1), ///
        xtitle("Effective Tariff Rate 1 (%)") ///
        ytitle("Log Tariff Amount 1") ///
        title("Tariff Rate 1 and Tariff Amount 1") ///
        legend(label(1 "TSUSA-year observations") label(2 "Linear fit"))

    graph export "$figures\scatter_tariff_rate1_tariff_amount1.pdf", as(pdf) replace

    * Run a simple regression of log tariff amount 1 on effective tariff rate 1.
    reg ln_tariff_amount1 eff_tariff_rate1

    * Graph 5b: Show the relationship between effective tariff rate 2 and tariff amount 2.
    * Re-examine the same relationship using the second tariff measure.
    twoway ///
        (scatter ln_tariff_amount2 eff_tariff_rate2) ///
        (lfit ln_tariff_amount2 eff_tariff_rate2), ///
        xtitle("Effective Tariff Rate 2 (%)") ///
        ytitle("Log Tariff Amount 2") ///
        title("Tariff Rate 2 and Tariff Amount 2") ///
        legend(label(1 "TSUSA-year observations") label(2 "Linear fit"))

    graph export "$figures\scatter_tariff_rate2_tariff_amount2.pdf", as(pdf) replace

    * Run a simple regression of log tariff amount 2 on effective tariff rate 2.
    reg ln_tariff_amount2 eff_tariff_rate2
end

* Notes:
*   Input data: tsus_trade_tsusa_year_conval_panel.dta
*   Output graphs:
*     scatter_tariff_rate1_tariff_amount1.pdf
*     scatter_tariff_rate2_tariff_amount2.pdf
*   - Calculate effective tariff rates.
*   - Create indicator variables showing whether tariffs are actually imposed.
*   - Summarize tariff rates and tariff amounts by year.
*   - Examine the relationship between effective tariff rates and log tariff amounts using graphs.


* ---------------------------------------------------------------------------
* Shared helper. Reshape the 1968 and 1972 data to wide format and create change variables
* ---------------------------------------------------------------------------

capture program drop prepare_1968_1972_change_data
program define prepare_1968_1972_change_data
    * Load the product-year panel and create data for comparing 1968 and 1972.
    use "$data\Stata Files\tsus_trade_tsusa_year_conval_panel.dta", clear

    * Clean special tariff values and tariff amounts for analysis.
    clean_tariff_inputs

    * Create effective tariff rates to calculate tariff-rate changes between 1968 and 1972.
    gen eff_tariff_rate1 = total_tariff_amount1 / con_val_yr * 100 if con_val_yr > 0
    gen eff_tariff_rate2 = total_tariff_amount2 / con_val_yr * 100 if con_val_yr > 0
    * Also retain whether tariffs are positive in the change dataset.
    gen has_tariff1 = total_tariff_amount1 > 0 if !missing(total_tariff_amount1)
    gen has_tariff2 = total_tariff_amount2 > 0 if !missing(total_tariff_amount2)
    gen has_tariff_any = has_tariff1 == 1 | has_tariff2 == 1

    * The change analysis compares only 1968 and 1972.
    keep if inlist(year, 1968, 1972)

    * Keep only the core variables required for reshape.
    keep tsusa year con_val_yr total_tariff_amount1 total_tariff_amount2 ///
         eff_tariff_rate1 eff_tariff_rate2 has_tariff_any

    * Place the 1968 and 1972 values side by side in one row for each TSUSA.
    reshape wide con_val_yr total_tariff_amount1 total_tariff_amount2 ///
                 eff_tariff_rate1 eff_tariff_rate2 has_tariff_any, ///
        i(tsusa) j(year)

    * Subtract the 1968 tariff rate from the 1972 tariff rate to create tariff-rate changes.
    gen change_eff1 = eff_tariff_rate11972 - eff_tariff_rate11968
    gen change_eff2 = eff_tariff_rate21972 - eff_tariff_rate21968

    * Create level, percentage, and log changes in import value.
    gen change_con_val = con_val_yr1972 - con_val_yr1968
    gen pct_change_con_val = 100 * (con_val_yr1972 - con_val_yr1968) / con_val_yr1968 if con_val_yr1968 > 0
    gen log_change_con_val = ln(con_val_yr1972) - ln(con_val_yr1968) if con_val_yr1968 > 0 & con_val_yr1972 > 0

    * Calculate changes in tariff amounts by subtracting 1968 values from 1972 values.
    gen change_tariff_amount1 = total_tariff_amount11972 - total_tariff_amount11968
    gen change_tariff_amount2 = total_tariff_amount21972 - total_tariff_amount21968

    * Create a filter that retains the 1st--99th percentile range of log import-value changes for graphs.
    summarize log_change_con_val if !missing(log_change_con_val), detail
    gen keep_log_change = inrange(log_change_con_val, r(p1), r(p99)) if !missing(log_change_con_val)

    * Create a filter to reduce outliers in tariff-rate change 1.
    summarize change_eff1 if !missing(change_eff1), detail
    gen keep_change_eff1 = inrange(change_eff1, r(p1), r(p99)) if !missing(change_eff1)

    * Create a filter to reduce outliers in tariff-rate change 2.
    summarize change_eff2 if !missing(change_eff2), detail
    gen keep_change_eff2 = inrange(change_eff2, r(p1), r(p99)) if !missing(change_eff2)

    * Create final sample indicators for graphs and regressions.
    gen keep_change_graph1 = keep_log_change == 1 & keep_change_eff1 == 1 & con_val_yr1968 > 0
    gen keep_change_graph2 = keep_log_change == 1 & keep_change_eff2 == 1 & con_val_yr1968 > 0

    * Check the number of observations remaining after applying the filters.
    tab keep_change_graph1
    tab keep_change_graph2
end

* Notes:
*   Used by: analyze_import_value_changes, make_binned_tariff_change_graph
*   - Keep only observations from 1968 and 1972.
*   - Reshape the TSUSA-year panel from long to wide format.
*   - Create change variables for tariff rates, tariff amounts, and import values.
*   - Create percentile-based filters to reduce the influence of outliers in graphs and regressions.


* ---------------------------------------------------------------------------
* 6. Compare the relationship between 1968--1972 tariff-rate changes and import-value changes
* ---------------------------------------------------------------------------

capture program drop analyze_import_value_changes
program define analyze_import_value_changes
    * Create the 1968--1972 change dataset and analyze the relationship between tariff-rate and import-value changes.
    prepare_1968_1972_change_data

    * Examine the relationship between tariff-rate change 1 and log import-value change with a scatterplot and fitted line.
    twoway ///
        (scatter log_change_con_val change_eff1 [aw=con_val_yr1968] if keep_change_graph1 == 1) ///
        (lfit log_change_con_val change_eff1 [aw=con_val_yr1968] if keep_change_graph1 == 1), ///
        xtitle("Change in Effective Tariff Rate 1, 1972 - 1968") ///
        ytitle("Log Change in Consumption Import Value") ///
        title("Tariff Change 1 and Import Value Change") ///
        legend(label(1 "TSUSA observations") label(2 "Weighted linear fit"))

    graph export "$figures\scatter_tariff_change1_log_import_change.pdf", as(pdf) replace

    * Use a weighted regression to examine how tariff-rate change 1 is related to import-value change.
    reg log_change_con_val change_eff1 [aw=con_val_yr1968] if keep_change_graph1 == 1

    * Examine the relationship between tariff-rate change 2 and log import-value change using the same approach.
    twoway ///
        (scatter log_change_con_val change_eff2 [aw=con_val_yr1968] if keep_change_graph2 == 1) ///
        (lfit log_change_con_val change_eff2 [aw=con_val_yr1968] if keep_change_graph2 == 1), ///
        xtitle("Change in Effective Tariff Rate 2, 1972 - 1968") ///
        ytitle("Log Change in Consumption Import Value") ///
        title("Tariff Change 2 and Import Value Change") ///
        legend(label(1 "TSUSA observations") label(2 "Weighted linear fit"))

    graph export "$figures\scatter_tariff_change2_log_import_change.pdf", as(pdf) replace

    * Run a weighted regression for tariff-rate change 2 as well.
    reg log_change_con_val change_eff2 [aw=con_val_yr1968] if keep_change_graph2 == 1

    * Include both tariff-rate changes to examine their joint relationship with import-value change.
    reg log_change_con_val change_eff1 change_eff2 [aw=con_val_yr1968] if keep_log_change == 1 & keep_change_eff1 == 1 & keep_change_eff2 == 1 & con_val_yr1968 > 0
end

* Notes:
*   Input data: 1968--1972 change data created by prepare_1968_1972_change_data
*   Output graphs:
*     scatter_tariff_change1_log_import_change.pdf
*     scatter_tariff_change2_log_import_change.pdf
*   - Plot the relationship between tariff-rate changes and log import-value changes.
*   - Run weighted regressions using 1968 import value as the weight.


* ---------------------------------------------------------------------------
* 7. Group tariff-rate changes into bins and graph mean import-value changes
* ---------------------------------------------------------------------------

capture program drop make_binned_tariff_change_graph
program define make_binned_tariff_change_graph
    * Create the 1968--1972 change dataset and summarize tariff-rate changes by bin.
    prepare_1968_1972_change_data

    * Divide tariff-rate change 1 into 20 bins.
    xtile tariff_change_bin1 = change_eff1 if keep_change_graph1 == 1, nq(20)

    * Keep only observations for the graph and exclude large negative outliers.
    keep if keep_change_graph1 == 1
    keep if change_eff1 > -20

    * Create 20 bins again after excluding outliers.
    xtile tariff_change_bin1_trim = change_eff1, nq(20)

    * Calculate the number of observations, mean import-value change, and mean tariff-rate change for each bin.
    collapse ///
        (count) n_obs = log_change_con_val ///
        (mean) mean_log_change = log_change_con_val ///
               mean_change_eff1 = change_eff1 ///
        [aw=con_val_yr1968], ///
        by(tariff_change_bin1_trim)

    * Use bin means to show a smoother pattern between tariff-rate and import-value changes.
    twoway ///
        (scatter mean_log_change mean_change_eff1 [aw=n_obs]) ///
        (lfit mean_log_change mean_change_eff1), ///
        xtitle("Change in Effective Tariff Rate 1, 1972 - 1968") ///
        ytitle("Mean Log Change in Consumption Import Value") ///
        title("Binned Tariff Change 1 and Import Value Change, Trimmed")

    * Examine the simple linear relationship in the bin-mean data as well.
    reg mean_log_change mean_change_eff1 [aw=n_obs]
end

* Notes:
*   Input data: 1968--1972 change data created by prepare_1968_1972_change_data
*   - Divide tariff-rate changes into multiple bins.
*   - Collapse the data to bin-level means.
*   - Graph the relationship between mean tariff-rate changes and mean log import-value changes.


* ===========================================================================
* Run analysis
* ===========================================================================

run_post_merge_analysis

log close
