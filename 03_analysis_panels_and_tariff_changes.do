* Build analysis panels, tariff rates, tariff amounts, and import-change diagnostics
cd "C:\Users\USER\Desktop\Tariff-RA-Data"

capture log close
log using "Analysis\Codes\03_analysis_panels_and_tariff_changes_log.smcl", replace

global data "Analysis\Data Files"
global figures "Analysis\Figures"

* GitHub DY--Analysis code/ pipeline:
* 01b_suffix_fix.do creates tsus_uncorrected.dta.
* 01c_clean_duties.do creates the cleaned tsus_final.dta.
* 02_merge.do uses that file and creates tsus_trade_merged.dta.
* This file starts from that merged output, creates analysis panels, and
* then analyzes tariff rates, tariff amounts, and import-value changes.


* ---------------------------------------------------------------------------
* 1. Prepare merged output for panel construction
* ---------------------------------------------------------------------------

use "$data\Stata Files\tsus_trade_merged.dta", clear

capture confirm variable tariff_merge_status
if _rc {
    rename _merge tariff_merge_status
}

capture confirm variable total_tariff_amount1
if _rc {
    gen total_tariff_amount1 = .
}
replace total_tariff_amount1 = con_val_yr * (duty1_ad / 100) + con_qy1_yr * duty1_spec

capture confirm variable total_tariff_amount2
if _rc {
    gen total_tariff_amount2 = .
}
replace total_tariff_amount2 = con_val_yr * (duty2_ad / 100) + con_qy1_yr * duty2_spec

save "$data\Stata Files\tsus_trade_merged.dta", replace


* ---------------------------------------------------------------------------
* 2. Total U.S. import-value panel by TSUSA-year
* ---------------------------------------------------------------------------

use "$data\Stata Files\tsus_trade_merged.dta", clear

keep if tariff_merge_status == 3

collapse ///
    (sum) con_val_yr con_qy1_yr gen_val_yr gen_qy1_yr ///
          ves_val_yr ves_wgt_yr air_val_yr air_wgt_yr ///
          total_tariff_amount1 total_tariff_amount2 ///
    (mean) duty1_spec duty2_spec duty1_ad duty2_ad, ///
    by(tsusa year)

sort tsusa year
isid tsusa year

save "$data\Stata Files\tsus_trade_tsusa_year_conval_panel.dta", replace


* ---------------------------------------------------------------------------
* 3. Country-level import-value panel by TSUSA-country-year
* ---------------------------------------------------------------------------

use "$data\Stata Files\tsus_trade_merged.dta", clear

keep if tariff_merge_status == 3

collapse ///
    (sum) con_val_yr con_qy1_yr gen_val_yr gen_qy1_yr ///
          ves_val_yr ves_wgt_yr air_val_yr air_wgt_yr ///
          total_tariff_amount1 total_tariff_amount2 ///
    (mean) duty1_spec duty2_spec duty1_ad duty2_ad, ///
    by(tsusa cty_code year)

sort tsusa cty_code year
isid tsusa cty_code year

egen panel_id = group(tsusa cty_code)
xtset panel_id year

save "$data\Stata Files\tsus_trade_country_year_conval_panel.dta", replace


* ---------------------------------------------------------------------------
* 4. Analyze tariff rates, tariff amounts, and import changes
* ---------------------------------------------------------------------------

use "$data\Stata Files\tsus_trade_tsusa_year_conval_panel.dta", clear

* Keep usable observations.
keep if con_val_yr > 0

* Treat 999999 as a sentinel/outlier, not as a real tariff rate.
replace duty1_spec = . if duty1_spec == 999999
replace duty2_spec = . if duty2_spec == 999999

* Recalculate tariff amounts after removing the sentinel values.
gen duty1_ad_calc = duty1_ad
gen duty2_ad_calc = duty2_ad
gen duty1_spec_calc = duty1_spec
gen duty2_spec_calc = duty2_spec

replace duty1_ad_calc = 0 if missing(duty1_ad_calc)
replace duty2_ad_calc = 0 if missing(duty2_ad_calc)
replace duty1_spec_calc = 0 if missing(duty1_spec_calc)
replace duty2_spec_calc = 0 if missing(duty2_spec_calc)

replace total_tariff_amount1 = con_val_yr * (duty1_ad_calc / 100) + con_qy1_yr * duty1_spec_calc
replace total_tariff_amount2 = con_val_yr * (duty2_ad_calc / 100) + con_qy1_yr * duty2_spec_calc

* Effective tariff rates.
gen eff_tariff_rate1 = total_tariff_amount1 / con_val_yr * 100 if con_val_yr > 0
gen eff_tariff_rate2 = total_tariff_amount2 / con_val_yr * 100 if con_val_yr > 0

* Tariff incidence indicators for diagnostics.
gen has_tariff1 = total_tariff_amount1 > 0 if !missing(total_tariff_amount1)
gen has_tariff2 = total_tariff_amount2 > 0 if !missing(total_tariff_amount2)
gen has_tariff_any = has_tariff1 == 1 | has_tariff2 == 1

* Diagnostics after removing 999999.
summarize duty1_spec duty2_spec duty1_ad duty2_ad eff_tariff_rate1 eff_tariff_rate2, detail
tab year has_tariff_any
bysort year: summarize con_val_yr total_tariff_amount1 total_tariff_amount2 eff_tariff_rate1 eff_tariff_rate2

* Log tariff amount variables.
gen ln_tariff_amount1 = ln(total_tariff_amount1) if total_tariff_amount1 > 0
gen ln_tariff_amount2 = ln(total_tariff_amount2) if total_tariff_amount2 > 0

* Scatter plot with linear fit: tariff rate 1 vs tariff amount 1.
twoway ///
    (scatter ln_tariff_amount1 eff_tariff_rate1) ///
    (lfit ln_tariff_amount1 eff_tariff_rate1), ///
    xtitle("Effective Tariff Rate 1 (%)") ///
    ytitle("Log Tariff Amount 1") ///
    title("Tariff Rate 1 and Tariff Amount 1") ///
    legend(label(1 "TSUSA-year observations") label(2 "Linear fit"))

graph export "$figures\scatter_tariff_rate1_tariff_amount1.pdf", as(pdf) replace

reg ln_tariff_amount1 eff_tariff_rate1

* Scatter plot with linear fit: tariff rate 2 vs tariff amount 2.
twoway ///
    (scatter ln_tariff_amount2 eff_tariff_rate2) ///
    (lfit ln_tariff_amount2 eff_tariff_rate2), ///
    xtitle("Effective Tariff Rate 2 (%)") ///
    ytitle("Log Tariff Amount 2") ///
    title("Tariff Rate 2 and Tariff Amount 2") ///
    legend(label(1 "TSUSA-year observations") label(2 "Linear fit"))

graph export "$figures\scatter_tariff_rate2_tariff_amount2.pdf", as(pdf) replace

reg ln_tariff_amount2 eff_tariff_rate2

* Build 1968-1972 change dataset.
keep if inlist(year, 1968, 1972)

keep tsusa year con_val_yr total_tariff_amount1 total_tariff_amount2 ///
     eff_tariff_rate1 eff_tariff_rate2 has_tariff_any

reshape wide con_val_yr total_tariff_amount1 total_tariff_amount2 ///
             eff_tariff_rate1 eff_tariff_rate2 has_tariff_any, ///
    i(tsusa) j(year)

* Changes from 1968 to 1972.
gen change_eff1 = eff_tariff_rate11972 - eff_tariff_rate11968
gen change_eff2 = eff_tariff_rate21972 - eff_tariff_rate21968

gen change_con_val = con_val_yr1972 - con_val_yr1968
gen pct_change_con_val = 100 * (con_val_yr1972 - con_val_yr1968) / con_val_yr1968 if con_val_yr1968 > 0
gen log_change_con_val = ln(con_val_yr1972) - ln(con_val_yr1968) if con_val_yr1968 > 0 & con_val_yr1972 > 0

gen change_tariff_amount1 = total_tariff_amount11972 - total_tariff_amount11968
gen change_tariff_amount2 = total_tariff_amount21972 - total_tariff_amount21968

* Outlier filters for change graphs and regressions.
* The first two scatter plots use all cleaned TSUSA-year observations above.
* These filters apply only after the 1968-1972 change variables are created.
summarize log_change_con_val if !missing(log_change_con_val), detail
gen keep_log_change = inrange(log_change_con_val, r(p1), r(p99)) if !missing(log_change_con_val)

summarize change_eff1 if !missing(change_eff1), detail
gen keep_change_eff1 = inrange(change_eff1, r(p1), r(p99)) if !missing(change_eff1)

summarize change_eff2 if !missing(change_eff2), detail
gen keep_change_eff2 = inrange(change_eff2, r(p1), r(p99)) if !missing(change_eff2)

gen keep_change_graph1 = keep_log_change == 1 & keep_change_eff1 == 1 & con_val_yr1968 > 0
gen keep_change_graph2 = keep_log_change == 1 & keep_change_eff2 == 1 & con_val_yr1968 > 0

tab keep_change_graph1
tab keep_change_graph2

* Scatter plot with linear fit: tariff-rate change 1 vs log import-value change.
twoway ///
    (scatter log_change_con_val change_eff1 [aw=con_val_yr1968] if keep_change_graph1 == 1) ///
    (lfit log_change_con_val change_eff1 [aw=con_val_yr1968] if keep_change_graph1 == 1), ///
    xtitle("Change in Effective Tariff Rate 1, 1972 - 1968") ///
    ytitle("Log Change in Consumption Import Value") ///
    title("Tariff Change 1 and Import Value Change") ///
    legend(label(1 "TSUSA observations") label(2 "Weighted linear fit"))

graph export "$figures\scatter_tariff_change1_log_import_change.pdf", as(pdf) replace

reg log_change_con_val change_eff1 [aw=con_val_yr1968] if keep_change_graph1 == 1

* Scatter plot with linear fit: tariff-rate change 2 vs log import-value change.
twoway ///
    (scatter log_change_con_val change_eff2 [aw=con_val_yr1968] if keep_change_graph2 == 1) ///
    (lfit log_change_con_val change_eff2 [aw=con_val_yr1968] if keep_change_graph2 == 1), ///
    xtitle("Change in Effective Tariff Rate 2, 1972 - 1968") ///
    ytitle("Log Change in Consumption Import Value") ///
    title("Tariff Change 2 and Import Value Change") ///
    legend(label(1 "TSUSA observations") label(2 "Weighted linear fit"))

graph export "$figures\scatter_tariff_change2_log_import_change.pdf", as(pdf) replace

reg log_change_con_val change_eff2 [aw=con_val_yr1968] if keep_change_graph2 == 1

* Weighted regression: log import-value change on both tariff changes.
reg log_change_con_val change_eff1 change_eff2 [aw=con_val_yr1968] if keep_log_change == 1 & keep_change_eff1 == 1 & keep_change_eff2 == 1 & con_val_yr1968 > 0

xtile tariff_change_bin1 = change_eff1 if keep_change_graph1 == 1, nq(20)

preserve

keep if keep_change_graph1 == 1
keep if change_eff1 > -20

xtile tariff_change_bin1_trim = change_eff1, nq(20)

collapse ///
    (count) n_obs = log_change_con_val ///
    (mean) mean_log_change = log_change_con_val ///
           mean_change_eff1 = change_eff1 ///
    [aw=con_val_yr1968], ///
    by(tariff_change_bin1_trim)

twoway ///
    (scatter mean_log_change mean_change_eff1 [aw=n_obs]) ///
    (lfit mean_log_change mean_change_eff1), ///
    xtitle("Change in Effective Tariff Rate 1, 1972 - 1968") ///
    ytitle("Mean Log Change in Consumption Import Value") ///
    title("Binned Tariff Change 1 and Import Value Change, Trimmed")

reg mean_log_change mean_change_eff1 [aw=n_obs]

restore

log close
