* Exploratory analysis of five potential research patterns.
* This file reads the panels created by 03a_panel_data.do.
* It prints results only and creates no persistent output file or graph.

do "C:\Users\USER\Desktop\Tariff-RA-Data\Analysis\Codes\00_setup.do"


capture program drop explore_five_patterns
program define explore_five_patterns

    * Explicit exploratory thresholds.
    local minimum_rate_range = 0.1
    local minimum_coverage = 0.80
    local stable_exposure_change = 0.5
    local stable_import_change = 10

    * -----------------------------------------------------------------------
    * 1. Products with a negative correlation between the ad valorem rate
    * and log import value over 1968--1972.
    * -----------------------------------------------------------------------
    foreach m in 1 2 {
        preserve
            use "$data/Stata Files/tsus_trade_tsusa_year_conval_panel.dta", clear
            keep if con_val_yr > 0 & !missing(duty`m'_ad)
            gen double ln_import = ln(con_val_yr)

            bysort tsusa: gen int n_years = _N
            bysort tsusa: egen double rate_min = min(duty`m'_ad)
            bysort tsusa: egen double rate_max = max(duty`m'_ad)
            gen double rate1968_row = duty`m'_ad if year == 1968
            gen double rate1972_row = duty`m'_ad if year == 1972
            gen double import1968_row = con_val_yr if year == 1968
            gen double import1972_row = con_val_yr if year == 1972
            bysort tsusa: egen double rate1968 = max(rate1968_row)
            bysort tsusa: egen double rate1972 = max(rate1972_row)
            bysort tsusa: egen double import1968 = max(import1968_row)
            bysort tsusa: egen double import1972 = max(import1972_row)

            tempfile product_panel product_stats
            save `product_panel', replace
            bysort tsusa: keep if _n == 1
            keep tsusa n_years rate_min rate_max ///
                rate1968 rate1972 import1968 import1972
            save `product_stats', replace

            use `product_panel', clear
            statsby corr_rate_import = r(rho), by(tsusa) clear: ///
                correlate duty`m'_ad ln_import
            merge 1:1 tsusa using `product_stats', assert(3) nogen

            quietly count
            local n_products = r(N)
            quietly count if missing(corr_rate_import)
            local n_missing_corr = r(N)
            display as result ///
                "1. duty`m'_ad: products with missing correlation = " ///
                `n_missing_corr' " of " `n_products'

            quietly count if n_years != 5
            local n_incomplete_years = r(N)
            display as result ///
                "1. duty`m'_ad: products without all five years = " ///
                `n_incomplete_years' " of " `n_products'

            keep if n_years == 5 & ///
                rate_max - rate_min >= `minimum_rate_range'

            gen byte rate_direction = cond(rate1972 > rate1968, 1, ///
                cond(rate1972 < rate1968, -1, 0))
            gen byte import_direction = cond(import1972 > import1968, 1, ///
                cond(import1972 < import1968, -1, 0))
            capture label drop change_direction
            label define change_direction -1 "Decrease" 0 "No change" ///
                1 "Increase"
            label values rate_direction change_direction
            label values import_direction change_direction

            display as result ///
                "1. duty`m'_ad: 1968--1972 tariff-rate and import-value changes"
            tabulate rate_direction import_direction, missing

            quietly count if corr_rate_import < 0
            display as result "1. duty`m'_ad: products with negative correlation = " r(N)

            keep if corr_rate_import < 0
            gsort corr_rate_import
            local list_last = min(_N, 20)
            if `list_last' > 0 {
                list tsusa corr_rate_import rate_min rate_max ///
                    in 1/`list_last', noobs abbreviate(24)
            }
        restore
    }

    * -----------------------------------------------------------------------
    * 2. Countries with a negative correlation between country-level tariff
    * exposure and total imports over 1968--1972.
    *
    * Tariffs vary by product, not origin country.  Construct each country's
    * annual tariff exposure using fixed 1968 product import shares.  Restrict
    * the basket to products with tariff observations in all five years so
    * changes in coverage do not generate changes in measured exposure.
    * -----------------------------------------------------------------------
    tempfile country_year_import base_basket product_rate_panel

    * Diagnostic: products absent from a country's 1968 import basket but
    * imported in at least one later year. This list is not used in the
    * fixed-1968-weight exposure calculation below.
    preserve
        use "$data/Stata Files/tsus_trade_country_year_conval_panel.dta", clear
        collapse (sum) import_value = con_val_yr, by(cty_code tsusa year)
        keep if inrange(year, 1968, 1972)
        reshape wide import_value, i(cty_code tsusa) j(year)

        foreach y in 1968 1969 1970 1971 1972 {
            replace import_value`y' = 0 if missing(import_value`y')
        }

        egen double later_import = rowtotal(import_value1969 import_value1970 ///
            import_value1971 import_value1972)
        keep if import_value1968 == 0 & later_import > 0
        sort cty_code tsusa

        display as result ///
            "2. Country-TSUSA pairs absent in 1968 but imported later"
        list cty_code tsusa import_value1968 import_value1969 import_value1970 ///
            import_value1971 import_value1972, noobs abbreviate(24)

        quietly count
        display as result ///
            "2. Country-TSUSA pairs absent in 1968 but imported later = " r(N)
    restore

    preserve
        use "$data/Stata Files/tsus_trade_country_year_conval_panel.dta", clear
        collapse (sum) total_import = con_val_yr, by(cty_code year)
        keep if inrange(year, 1968, 1972) & total_import > 0
        gen double ln_total_import = ln(total_import)
        save `country_year_import', replace
    restore

    preserve
        use "$data/Stata Files/tsus_trade_country_year_conval_panel.dta", clear
        keep if year == 1968 & con_val_yr > 0
        collapse (sum) base_import_value = con_val_yr, by(cty_code tsusa)
        bysort cty_code: egen double total_base_import = total(base_import_value)
        save `base_basket', replace
    restore

    foreach m in 1 2 {
        preserve
            use "$data/Stata Files/tsus_trade_tsusa_year_conval_panel.dta", clear
            keep if inrange(year, 1968, 1972) & !missing(duty`m'_ad)
            bysort tsusa: gen byte n_rate_years = _N
            keep if n_rate_years == 5
            keep tsusa year duty`m'_ad
            save `product_rate_panel', replace

            use `base_basket', clear
            joinby tsusa using `product_rate_panel'

            bysort cty_code: egen double covered_base_import = total(base_import_value) ///
                if year == 1968
            bysort cty_code: egen double covered_base_import_all = ///
                max(covered_base_import)
            drop covered_base_import
            rename covered_base_import_all covered_base_import

            gen double fixed_1968_weight = base_import_value / covered_base_import
            gen double exposure_component = fixed_1968_weight * duty`m'_ad

            collapse (sum) tariff_exposure = exposure_component ///
                (firstnm) covered_base_import total_base_import, by(cty_code year)
            gen double base_value_coverage = covered_base_import / total_base_import
            merge 1:1 cty_code year using `country_year_import', keep(3) nogen

            bysort cty_code: egen double mean_exposure = mean(tariff_exposure)
            bysort cty_code: egen double mean_ln_total_import = ///
                mean(ln_total_import)
            gen double exposure_import_cross = ///
                (tariff_exposure - mean_exposure) * ///
                (ln_total_import - mean_ln_total_import)
            gen double exposure_deviation_sq = ///
                (tariff_exposure - mean_exposure)^2
            gen double total_import_deviation_sq = ///
                (ln_total_import - mean_ln_total_import)^2
            bysort cty_code: egen double cross_sum = total(exposure_import_cross)
            bysort cty_code: egen double exposure_sq_sum = ///
                total(exposure_deviation_sq)
            bysort cty_code: egen double total_import_sq_sum = ///
                total(total_import_deviation_sq)
            gen double corr_exposure_import = cross_sum / ///
                sqrt(exposure_sq_sum * total_import_sq_sum) ///
                if exposure_sq_sum > 0 & total_import_sq_sum > 0
            bysort cty_code: gen byte n_years = _N
            bysort cty_code: egen double exposure_min = min(tariff_exposure)
            bysort cty_code: egen double exposure_max = max(tariff_exposure)
            bysort cty_code: egen double minimum_country_coverage = ///
                min(base_value_coverage)
            bysort cty_code: keep if _n == 1

            keep if n_years == 5 & ///
                minimum_country_coverage >= `minimum_coverage' & ///
                exposure_max - exposure_min >= `minimum_rate_range'

            quietly count if corr_exposure_import < 0
            display as result ///
                "2. duty`m'_ad: countries with negative exposure-import correlation = " r(N)

            keep if corr_exposure_import < 0
            gsort corr_exposure_import
            local list_last = min(_N, 20)
            if `list_last' > 0 {
                list cty_code corr_exposure_import exposure_min exposure_max ///
                    minimum_country_coverage in 1/`list_last', ///
                    noobs abbreviate(24)
            }
        restore
    }

    * -----------------------------------------------------------------------
    * 3 and 4. Country tariff exposure.
    * U.S. tariffs vary by product rather than origin country.  Define exposure
    * using each country's fixed 1968 product import shares.  This avoids using
    * contemporaneous import shares as tariff weights.
    * -----------------------------------------------------------------------
    tempfile country_import_change product_rate_change

    preserve
        use "$data/Stata Files/tsus_trade_country_year_conval_panel.dta", clear
        collapse (sum) con_val_yr, by(cty_code year)
        keep if inlist(year, 1968, 1972)
        reshape wide con_val_yr, i(cty_code) j(year)
        keep if !missing(con_val_yr1968, con_val_yr1972) & ///
            con_val_yr1968 > 0 & con_val_yr1972 > 0

        gen double log_import_change = ln(con_val_yr1972) - ln(con_val_yr1968)
        gen double import_pct_change = 100 * (con_val_yr1972 / con_val_yr1968 - 1)
        save `country_import_change', replace
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

            * 3. Bottom decile of tariff-exposure change, but imports declined.
            quietly summarize exposure_change ///
                if base_value_coverage >= `minimum_coverage', detail
            local exposure_p10 = r(p10)

            display as result ///
                "3. duty`m'_ad: large exposure decline but imports also declined"
            gsort exposure_change
            list cty_code exposure1968 exposure1972 exposure_change ///
                import_pct_change base_value_coverage ///
                if base_value_coverage >= `minimum_coverage' & ///
                   exposure_change <= `exposure_p10' & exposure_change < 0 & ///
                   log_import_change < 0, ///
                noobs abbreviate(24)

            * 4. Exposure changed by no more than 0.5 percentage point, while
            * import growth is in the top decile of the stable-exposure group.
            quietly summarize log_import_change ///
                if base_value_coverage >= `minimum_coverage' & ///
                   abs(exposure_change) <= `stable_exposure_change', detail
            local import_p90 = r(p90)

            display as result ///
                "4. duty`m'_ad: stable exposure but top-decile import growth"
            gsort -log_import_change
            list cty_code exposure1968 exposure1972 exposure_change ///
                import_pct_change base_value_coverage ///
                if base_value_coverage >= `minimum_coverage' & ///
                   abs(exposure_change) <= `stable_exposure_change' & ///
                   log_import_change >= `import_p90' & log_import_change > 0, ///
                noobs abbreviate(24)
        restore
    }

    * -----------------------------------------------------------------------
    * 5. Total import value changed by no more than 10%, but the number of
    * positively imported TSUSA products increased substantially.  Define a
    * substantial increase as the top decile of product-count growth among
    * countries with stable total import values.
    * -----------------------------------------------------------------------
    preserve
        use "$data/Stata Files/tsus_trade_country_year_conval_panel.dta", clear
        keep if con_val_yr > 0
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

        keep if abs(import_pct_change) <= `stable_import_change'
        quietly summarize product_pct_change, detail
        local product_growth_p90 = r(p90)

        keep if product_change > 0 & product_pct_change >= `product_growth_p90'
        gsort -product_pct_change -product_change

        display as result ///
            "5. Stable total imports but top-decile growth in imported products"
        display as text "   Product-count growth threshold (%) = " ///
            as result %9.2f `product_growth_p90'
        list cty_code con_val_yr1968 con_val_yr1972 import_pct_change ///
            n_products1968 n_products1972 product_change product_pct_change ///
            , noobs abbreviate(24)
    restore
end


explore_five_patterns
