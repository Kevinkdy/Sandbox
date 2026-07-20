```stata
* Post-merge analysis: build panels, inspect distributions, and analyze changes in tariffs and import values.

* Load machine-specific project paths (project_root, data, figures, and codes).
do "/Users/dongyeon/Documents/Tariff Project/tariff project onedrive/Analysis/Codes/00_setup.do"

capture log close
log using "$codes/05_post_merge_analysis_log.smcl", replace

* This file starts from tsus_trade_merged.dta, builds the two original analysis panels,
* adds a separate country-year ad valorem panel, and then runs post-merge analysis.

* ===========================================================================
* Main workflow
* ===========================================================================

capture program drop run_post_merge_analysis
program define run_post_merge_analysis
    prepare_merged_output
    * Load the merged tariff-trade data and prepare original tariff amounts.

    build_tsusa_year_panel
    * Aggregate matched observations into a TSUSA-year panel.

    build_country_year_panel
    * Aggregate matched observations into a TSUSA-country-year panel.

    build_cty_year_adval_panel
    * Aggregate the existing TSUSA-country-year panel into a separate country-year ad valorem panel.

    explore_five_patterns
    * Print the five exploratory research-pattern checks requested below.

    inspect_import_tariff_dist
    analyze_tariff_rates_and_amounts
    analyze_import_value_changes
    make_binned_tariff_change_graph
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
    use "$data/Stata Files/tsus_trade_merged.dta", clear

    * Give the merge-result variable a more descriptive name if it is still called _merge.
    capture confirm variable tariff_merge_status
    if _rc {
        rename _merge tariff_merge_status
    }

    * Preserve the raw first specific-duty field before converting it to numeric.
    capture confirm string variable duty1_spec
    if !_rc {
        capture confirm variable duty1_spec_raw
        if _rc {
            clonevar duty1_spec_raw = duty1_spec
        }
        destring duty1_spec, replace force
    }

    * Treat 999999 as a sentinel before calculating observation-level tariff amounts.
    replace duty1_spec = . if duty1_spec == 999999
    replace duty2_spec = . if duty2_spec == 999999

    gen double duty1_ad_calc = duty1_ad
    gen double duty2_ad_calc = duty2_ad
    gen double duty1_spec_calc = duty1_spec
    gen double duty2_spec_calc = duty2_spec

    replace duty1_ad_calc = 0 if missing(duty1_ad_calc)
    replace duty2_ad_calc = 0 if missing(duty2_ad_calc)
    replace duty1_spec_calc = 0 if missing(duty1_spec_calc)
    replace duty2_spec_calc = 0 if missing(duty2_spec_calc)

    capture confirm variable total_tariff_amount1
    if _rc {
        gen double total_tariff_amount1 = .
    }
    capture confirm variable total_tariff_amount2
    if _rc {
        gen double total_tariff_amount2 = .
    }

    * Ad valorem rates are percentages and specific duties are cents per stated unit.
    replace total_tariff_amount1 = con_val_yr * (duty1_ad_calc / 100) + ///
        con_qy1_yr * (duty1_spec_calc / 100)
    replace total_tariff_amount2 = con_val_yr * (duty2_ad_calc / 100) + ///
        con_qy1_yr * (duty2_spec_calc / 100)

    drop duty1_ad_calc duty2_ad_calc duty1_spec_calc duty2_spec_calc

    save "$data/Stata Files/tsus_trade_merged.dta", replace
end

* Notes:
*   Input: tsus_trade_merged.dta
*   - Rename _merge to tariff_merge_status when needed.
*   - Preserve the raw first specific-duty field and convert its calculation copy to numeric.
*   - Calculate original tariff-amount measures before panel aggregation.


* ---------------------------------------------------------------------------
* 2. Aggregate matched data into a TSUSA-year import panel
* ---------------------------------------------------------------------------

capture program drop build_tsusa_year_panel
program define build_tsusa_year_panel
    * Reload the merged data to build the product-year panel.
    use "$data/Stata Files/tsus_trade_merged.dta", clear

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
    save "$data/Stata Files/tsus_trade_tsusa_year_conval_panel.dta", replace
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
    use "$data/Stata Files/tsus_trade_merged.dta", clear

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
    save "$data/Stata Files/tsus_trade_country_year_conval_panel.dta", replace
end

* Notes:
*   Input: tsus_trade_merged.dta
*   Output: tsus_trade_country_year_conval_panel.dta
*   - Keep observations matched in both source datasets.
*   - Aggregate values, quantities, and tariff amounts by TSUSA-country-year.
*   - Create panel_id and declare the panel structure with xtset.


* ---------------------------------------------------------------------------
* 4. Aggregate the TSUSA-country-year panel into a country-year ad valorem panel
* ---------------------------------------------------------------------------

capture program drop build_cty_year_adval_panel
program define build_cty_year_adval_panel
    * Use the existing product-country-year panel without overwriting it.
    use "$data/Stata Files/tsus_trade_country_year_conval_panel.dta", clear

    isid tsusa cty_code year

    * Correct the single corrupted 1968 country code before country aggregation.
    replace cty_code = "423" if year == 1968 & tsusa == 3827882 & cty_code == "@23"
    assert cty_code != "@23"

    * Count each TSUSA only once after the country-code correction.
    egen byte product_tag = tag(cty_code year tsusa)

    gen double total_import_value = con_val_yr

    * Missing ad valorem rates are not treated as zero.  Explicit zero rates remain included.
    gen double adval_import_base1 = con_val_yr if !missing(duty1_ad)
    gen double adval_import_base2 = con_val_yr if !missing(duty2_ad)

    * Calculate only the ad valorem component, in dollars.
    gen double adval_tariff_amount1 = con_val_yr * duty1_ad / 100 if !missing(duty1_ad)
    gen double adval_tariff_amount2 = con_val_yr * duty2_ad / 100 if !missing(duty2_ad)

    gen int n_products = product_tag
    gen int n_products_adval1 = product_tag * !missing(duty1_ad)
    gen int n_products_adval2 = product_tag * !missing(duty2_ad)

    collapse ///
        (sum) total_import_value ///
              adval_import_base1 adval_import_base2 ///
              adval_tariff_amount1 adval_tariff_amount2 ///
              n_products n_products_adval1 n_products_adval2, ///
        by(cty_code year)

    * Coverage of observed ad valorem rates in total matched import value.
    gen double adval_value_coverage1 = adval_import_base1 / total_import_value ///
        if total_import_value > 0
    gen double adval_value_coverage2 = adval_import_base2 / total_import_value ///
        if total_import_value > 0

    egen country_id = group(cty_code)
    isid cty_code year
    xtset country_id year

    order country_id cty_code year total_import_value ///
          adval_import_base1 adval_tariff_amount1 adval_value_coverage1 ///
          adval_import_base2 adval_tariff_amount2 adval_value_coverage2 ///
          n_products n_products_adval1 n_products_adval2

    label variable total_import_value       "Matched consumption import value, all products ($)"
    label variable adval_import_base1       "Import value with observed ad valorem rate 1 ($)"
    label variable adval_import_base2       "Import value with observed ad valorem rate 2 ($)"
    label variable adval_tariff_amount1     "Ad valorem tariff amount 1 ($)"
    label variable adval_tariff_amount2     "Ad valorem tariff amount 2 ($)"
    label variable adval_value_coverage1    "Share of matched import value with ad valorem rate 1"
    label variable adval_value_coverage2    "Share of matched import value with ad valorem rate 2"

    save "$data/Stata Files/trade_country_year_adval_panel.dta", replace
end

* Notes:
*   Input: tsus_trade_country_year_conval_panel.dta
*   Output: trade_country_year_adval_panel.dta
*   - Keep the two existing panels unchanged.
*   - Collapse across TSUSA products to one observation per country-year.
*   - Calculate only ad valorem tariff amounts; do not construct a weighted tariff-rate measure.


* ---------------------------------------------------------------------------
* Shared helper. Keep observations valid for log and effective-rate analysis
* ---------------------------------------------------------------------------

capture program drop keep_positive_import_values
program define keep_positive_import_values
    * Keep positive import values for logarithms and effective-rate calculations.
    keep if con_val_yr > 0
end

* Notes:
*   Used by: inspect_import_tariff_dist, analyze_tariff_rates_and_amounts,
*                 prepare_1968_1972_change_data
*   - Keep observations with positive import values.
*   - Tariff inputs and observation-level tariff amounts are already prepared before panel aggregation.


* ---------------------------------------------------------------------------
* 5. Examine the distributions and correlations of log import values and log tariff amounts with graphs
* ---------------------------------------------------------------------------

capture program drop inspect_import_tariff_dist
program define inspect_import_tariff_dist
    * Load the product-year panel to examine distributions and correlations.
    use "$data/Stata Files/tsus_trade_tsusa_year_conval_panel.dta", clear

    * Keep positive import values for the log analysis.
    keep_positive_import_values

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

    graph export "$figures/hist_log_import_value.pdf", as(pdf) replace

    * Graph 4b: Show the distribution of tariff amount 1 across TSUSA-year observations.
    * Check whether tariff amount 1 is skewed or contains many small values.
    histogram ln_tariff_amount1, ///
        title("Distribution of Log Tariff Amount 1") ///
        xtitle("Log Tariff Amount 1") ///
        ytitle("Frequency")

    graph export "$figures/hist_log_tariff_amount1.pdf", as(pdf) replace

    * Graph 4c: Show the distribution of tariff amount 2 across TSUSA-year observations.
    * Check whether the distribution of tariff amount 2 is similar to or different from tariff amount 1.
    histogram ln_tariff_amount2, ///
        title("Distribution of Log Tariff Amount 2") ///
        xtitle("Log Tariff Amount 2") ///
        ytitle("Frequency")

    graph export "$figures/hist_log_tariff_amount2.pdf", as(pdf) replace

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

    graph export "$figures/scatter_import_value_tariff_amount1.pdf", as(pdf) replace

    * Graph 4e: Show the relationship between import value and tariff amount 2.
    * Re-examine the import-value-to-tariff-amount relationship using tariff amount 2.
    twoway ///
        (scatter ln_tariff_amount2 ln_con_val) ///
        (lfit ln_tariff_amount2 ln_con_val), ///
        title("Import Value and Tariff Amount 2") ///
        xtitle("Log Import Value") ///
        ytitle("Log Tariff Amount 2") ///
        legend(label(1 "TSUSA-year observations") label(2 "Linear fit"))

    graph export "$figures/scatter_import_value_tariff_amount2.pdf", as(pdf) replace

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
* 6. Compare the relationship between effective tariff rates and log tariff amounts
* ---------------------------------------------------------------------------

capture program drop analyze_tariff_rates_and_amounts
program define analyze_tariff_rates_and_amounts
    * Load the product-year panel to examine the relationship between tariff rates and tariff amounts.
    use "$data/Stata Files/tsus_trade_tsusa_year_conval_panel.dta", clear

    * Keep positive import values for the effective-rate analysis.
    keep_positive_import_values

    * Effective tariff rate ㅁ= tariff amount / import value * 100.
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

    graph export "$figures/scatter_tariff_rate1_tariff_amount1.pdf", as(pdf) replace

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

    graph export "$figures/scatter_tariff_rate2_tariff_amount2.pdf", as(pdf) replace

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
    use "$data/Stata Files/tsus_trade_tsusa_year_conval_panel.dta", clear

    * Keep positive import values for the 1968--1972 change analysis.
    keep_positive_import_values

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
* 7. Compare the relationship between 1968--1972 tariff-rate changes and import-value changes
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

    graph export "$figures/scatter_tariff_change1_log_import_change.pdf", as(pdf) replace

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

    graph export "$figures/scatter_tariff_change2_log_import_change.pdf", as(pdf) replace

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
* 8. Group tariff-rate changes into bins and graph mean import-value changes
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


* ---------------------------------------------------------------------------
* 9. Exploratory checks for five potential research patterns
* ---------------------------------------------------------------------------

capture program drop explore_five_patterns
program define explore_five_patterns

    * -----------------------------------------------------------------------
    * Check 1. Products with a negative within-product correlation between
    * the statutory ad valorem rate and log import value, 1968--1972.
    * Require all five positive-import years and at least a 0.1 percentage-point
    * rate range so storage precision is not mistaken for a tariff change.
    * -----------------------------------------------------------------------
    foreach m in 1 2 {
        preserve
            use "$data/Stata Files/tsus_trade_tsusa_year_conval_panel.dta", clear
            keep if con_val_yr > 0 & !missing(duty`m'_ad)
            gen double ln_import = ln(con_val_yr)

            bysort tsusa: egen double corr_rate_import = corr(duty`m'_ad ln_import)
            bysort tsusa: gen int n_years = _N
            bysort tsusa: egen double rate_min = min(duty`m'_ad)
            bysort tsusa: egen double rate_max = max(duty`m'_ad)
            bysort tsusa: keep if _n == 1

            keep if n_years == 5 & rate_max - rate_min >= 0.1
            quietly count if corr_rate_import < 0
            display as result "Check 1, duty`m'_ad: products with negative correlation = " r(N)

            keep if corr_rate_import < 0
            gsort corr_rate_import
            list tsusa corr_rate_import rate_min rate_max in 1/20, ///
                noobs abbreviate(24)
        restore
    }

    * -----------------------------------------------------------------------
    * Check 2. Countries with a negative within-country correlation across
    * product-year observations.  Require at least 100 usable observations
    * and representation in all five years.  This is descriptive, not causal.
    * -----------------------------------------------------------------------
    foreach m in 1 2 {
        preserve
            use "$data/Stata Files/tsus_trade_country_year_conval_panel.dta", clear
            replace cty_code = "423" if cty_code == "@23"
            keep if con_val_yr > 0 & !missing(duty`m'_ad)
            gen double ln_import = ln(con_val_yr)

            bysort cty_code: egen double corr_rate_import = corr(duty`m'_ad ln_import)
            bysort cty_code: gen long n_obs = _N
            egen byte country_year_tag = tag(cty_code year)
            bysort cty_code: egen byte n_years = total(country_year_tag)
            egen byte country_tag = tag(cty_code)

            keep if country_tag == 1 & n_obs >= 100 & n_years == 5
            quietly count if corr_rate_import < 0
            display as result "Check 2, duty`m'_ad: countries with negative correlation = " r(N)

            keep if corr_rate_import < 0
            gsort corr_rate_import
            list cty_code corr_rate_import n_obs in 1/20, ///
                noobs abbreviate(24)
        restore
    }

    * -----------------------------------------------------------------------
    * Checks 3 and 4 require a country-level tariff-exposure definition because
    * U.S. statutory tariffs vary by product, not by origin country.
    * Definition used here: hold each country's 1968 product import shares fixed,
    * and apply the 1968 and 1972 product-level ad valorem rates to that basket.
    * Require at least 80% coverage of the country's 1968 matched import value.
    * -----------------------------------------------------------------------
    tempfile country_import_change base_basket product_rate_change

    preserve
        use "$data/Stata Files/tsus_trade_country_year_conval_panel.dta", clear
        replace cty_code = "423" if cty_code == "@23"
        collapse (sum) con_val_yr, by(cty_code year)
        keep if inlist(year, 1968, 1972)
        reshape wide con_val_yr, i(cty_code) j(year)
        keep if !missing(con_val_yr1968, con_val_yr1972) & ///
            con_val_yr1968 > 0 & con_val_yr1972 > 0
        gen double log_import_change = ln(con_val_yr1972) - ln(con_val_yr1968)
        gen double import_pct_change = 100 * (con_val_yr1972 / con_val_yr1968 - 1)
        save `country_import_change', replace
    restore

    preserve
        use "$data/Stata Files/tsus_trade_country_year_conval_panel.dta", clear
        replace cty_code = "423" if cty_code == "@23"
        keep if year == 1968 & con_val_yr > 0
        collapse (sum) con_val_yr, by(cty_code tsusa)
        rename con_val_yr base_import_value
        save `base_basket', replace
    restore

    foreach m in 1 2 {
        preserve
            use "$data/Stata Files/tsus_trade_tsusa_year_conval_panel.dta", clear
            keep if inlist(year, 1968, 1972)
            keep tsusa year duty`m'_ad
            reshape wide duty`m'_ad, i(tsusa) j(year)
            keep if !missing(duty`m'_ad1968, duty`m'_ad1972)
            save `product_rate_change', replace

            use `base_basket', clear
            merge m:1 tsusa using `product_rate_change', keep(3) nogen

            bysort cty_code: egen double covered_base_import = total(base_import_value)
            gen double fixed_1968_weight = base_import_value / covered_base_import
            gen double exposure1968 = fixed_1968_weight * duty`m'_ad1968
            gen double exposure1972 = fixed_1968_weight * duty`m'_ad1972

            collapse (sum) exposure1968 exposure1972 base_import_value, by(cty_code)
            rename base_import_value covered_base_import
            merge 1:1 cty_code using `country_import_change', keep(3) nogen

            gen double base_value_coverage = covered_base_import / con_val_yr1968
            gen double exposure_change = exposure1972 - exposure1968

            * Check 3: bottom decile of fixed-weight tariff-exposure change,
            * but total imports also declined between 1968 and 1972.
            quietly summarize exposure_change if base_value_coverage >= 0.80, detail
            local exposure_p10 = r(p10)
            display as result "Check 3, duty`m'_ad: large exposure decline but imports declined"
            gsort exposure_change
            list cty_code exposure1968 exposure1972 exposure_change ///
                import_pct_change base_value_coverage ///
                if base_value_coverage >= 0.80 & ///
                   exposure_change <= `exposure_p10' & log_import_change < 0, ///
                noobs abbreviate(24)

            * Check 4: exposure changed by no more than 0.5 percentage point,
            * while import growth is in the top decile of that stable-exposure group.
            quietly summarize log_import_change if base_value_coverage >= 0.80 & ///
                abs(exposure_change) <= 0.5, detail
            local import_p90 = r(p90)
            display as result "Check 4, duty`m'_ad: stable exposure but top-decile import growth"
            gsort -log_import_change
            list cty_code exposure1968 exposure1972 exposure_change ///
                import_pct_change base_value_coverage ///
                if base_value_coverage >= 0.80 & abs(exposure_change) <= 0.5 & ///
                   log_import_change >= `import_p90', ///
                noobs abbreviate(24)
        restore
    }

    * -----------------------------------------------------------------------
    * Check 5. Total import value changed by no more than 10%, but the number
    * of imported TSUSA products increased.  Rank candidates by product growth.
    * -----------------------------------------------------------------------
    preserve
        use "$data/Stata Files/tsus_trade_country_year_conval_panel.dta", clear
        replace cty_code = "423" if cty_code == "@23"
        egen byte product_tag = tag(cty_code year tsusa)
        collapse (sum) con_val_yr n_products = product_tag, by(cty_code year)
        keep if inlist(year, 1968, 1972)
        reshape wide con_val_yr n_products, i(cty_code) j(year)
        keep if !missing(con_val_yr1968, con_val_yr1972, ///
                         n_products1968, n_products1972) & con_val_yr1968 > 0

        gen double import_pct_change = 100 * (con_val_yr1972 / con_val_yr1968 - 1)
        gen long product_change = n_products1972 - n_products1968
        gen double product_pct_change = 100 * ///
            (n_products1972 / n_products1968 - 1) if n_products1968 > 0

        keep if abs(import_pct_change) <= 10 & product_change > 0
        gsort -product_pct_change -product_change
        display as result "Check 5: stable total imports but more imported products"
        list cty_code con_val_yr1968 con_val_yr1972 import_pct_change ///
            n_products1968 n_products1972 product_change product_pct_change ///
            in 1/20, noobs abbreviate(24)
    restore
end

* Notes:
*   - Prints exploratory rankings to the Results window only.
*   - Creates no persistent output dataset or graph.
*   - Thresholds (0.1 pp, 80% coverage, 0.5 pp, and 10%) are explicit
*     exploratory definitions and can be changed at the top of each check.


* ===========================================================================
* Run analysis
* ===========================================================================

run_post_merge_analysis

log close
```
