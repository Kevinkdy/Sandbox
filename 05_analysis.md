```stata
* 병합 이후 분석: 기존 패널을 사용해 분포, 관세 변화, 수입액 변화를 분석한다.

cd "C:\Users\USER\Desktop\Tariff-RA-Data"

capture log close
log using "Analysis\Codes\05_post_merge_analysis_log.smcl", replace

global data "Analysis\Data Files"
global figures "Analysis\Figures"

* 이 파일은 기존 TSUSA-연도 패널을 사용해
* 관세율, 관세총액, 수입액 변화의 관계를 확인한다.


* ===========================================================================
* 전체 실행 흐름
* ===========================================================================

capture program drop run_post_merge_analysis
program define run_post_merge_analysis
    prepare_merged_output
    * 병합된 관세-무역 자료를 불러오고, 분석에 필요한 기본 변수들이 있는지 확인한다.

    inspect_import_tariff_dist
    * 수입액과 관세총액의 분포를 확인한다.
    * 히스토그램과 수입액-관세총액 산점도를 만든다.

    analyze_tariff_rates_and_amounts
    * 관세율이 높은 품목일수록 관세총액도 큰지 확인한다.

    analyze_import_value_changes
    * 1968년과 1972년 사이의 관세율 변화와 수입액 변화를 비교한다.

    make_binned_tariff_change_graph
    * 관세율 변화를 구간별로 묶어 더 보기 쉬운 평균 변화 그래프를 만든다.
end


* ===========================================================================
* 세부 코드
* ===========================================================================

* ---------------------------------------------------------------------------
* 1. 병합된 관세-무역 자료를 불러오고 관세총액 변수를 만든다
* ---------------------------------------------------------------------------

capture program drop prepare_merged_output
program define prepare_merged_output
    * 병합 완료 자료를 불러온다. 이 파일이 이후 모든 post-merge 분석의 출발점이다.
    use "$data\Stata Files\tsus_trade_merged.dta", clear

    * merge 결과 변수 이름이 아직 _merge라면 더 읽기 쉬운 이름으로 바꾼다.
    capture confirm variable tariff_merge_status
    if _rc {
        rename _merge tariff_merge_status
    }

    * 관세총액 1 변수가 없으면 빈 변수로 먼저 만든다.
    capture confirm variable total_tariff_amount1
    if _rc {
        gen total_tariff_amount1 = .
    }
    * 관세총액 1 = 종가세 부분 + 종량세 부분.
    replace total_tariff_amount1 = con_val_yr * (duty1_ad / 100) + con_qy1_yr * duty1_spec

    * 관세총액 2 변수도 같은 방식으로 준비한다.
    capture confirm variable total_tariff_amount2
    if _rc {
        gen total_tariff_amount2 = .
    }
    * 관세총액 2 = 두 번째 duty measure를 사용한 종가세 부분 + 종량세 부분.
    replace total_tariff_amount2 = con_val_yr * (duty2_ad / 100) + con_qy1_yr * duty2_spec

    * 계산된 관세총액 변수를 병합 자료에 다시 저장한다.
    save "$data\Stata Files\tsus_trade_merged.dta", replace
end

* 설명:
*   입력 자료: tsus_trade_merged.dta
*   - _merge 변수가 있으면 tariff_merge_status로 이름을 바꾼다.
*   - total_tariff_amount1과 total_tariff_amount2가 없으면 새로 만든다.
*   - 업데이트된 병합 자료를 다시 저장한다.


* ---------------------------------------------------------------------------
* 공통 보조 단계. 관세율 입력값을 정리하고 관세총액을 다시 계산한다
* ---------------------------------------------------------------------------

capture program drop clean_tariff_inputs
program define clean_tariff_inputs
    * 로그 계산과 effective rate 계산을 위해 수입액이 양수인 관측치만 남긴다.
    keep if con_val_yr > 0

    * 999999는 실제 관세율이 아니라 특수 표시값이므로 결측 처리한다.
    replace duty1_spec = . if duty1_spec == 999999
    replace duty2_spec = . if duty2_spec == 999999

    * 원래 duty 변수는 보존하고, 계산용 복사본을 만든다.
    gen duty1_ad_calc = duty1_ad
    gen duty2_ad_calc = duty2_ad
    gen duty1_spec_calc = duty1_spec
    gen duty2_spec_calc = duty2_spec

    * 결측 duty 구성요소는 관세총액 계산에서 0으로 처리한다.
    replace duty1_ad_calc = 0 if missing(duty1_ad_calc)
    replace duty2_ad_calc = 0 if missing(duty2_ad_calc)
    replace duty1_spec_calc = 0 if missing(duty1_spec_calc)
    replace duty2_spec_calc = 0 if missing(duty2_spec_calc)

    * 정리된 duty 변수를 사용해 관세총액을 다시 계산한다.
    replace total_tariff_amount1 = con_val_yr * (duty1_ad_calc / 100) + con_qy1_yr * duty1_spec_calc
    replace total_tariff_amount2 = con_val_yr * (duty2_ad_calc / 100) + con_qy1_yr * duty2_spec_calc
end

* 설명:
*   사용되는 곳: inspect_import_tariff_dist, analyze_tariff_rates_and_amounts,
*                 prepare_1968_1972_change_data
*   - 수입액이 0보다 큰 관측치만 남긴다.
*   - specific duty 값 999999는 실제 관세율이 아니라 특수 표시값으로 보고 결측 처리한다.
*   - 결측 관세 구성요소를 0으로 바꾼 뒤 관세총액을 다시 계산한다.


* ---------------------------------------------------------------------------
* 4. 로그 수입액과 로그 관세총액의 분포 및 상관관계를 그래프로 확인한다
* ---------------------------------------------------------------------------

capture program drop inspect_import_tariff_dist
program define inspect_import_tariff_dist
    * 품목-연도 패널을 불러와 분포와 상관관계를 확인한다.
    use "$data\Stata Files\tsus_trade_tsusa_year_conval_panel.dta", clear

    * 관세율 특수값과 결측 duty 구성요소를 정리한다.    
    clean_tariff_inputs

    * 수입액과 관세총액은 오른쪽으로 치우칠 수 있으므로 로그값을 만든다.
    gen ln_con_val = ln(con_val_yr) if con_val_yr > 0
    gen ln_tariff_amount1 = ln(total_tariff_amount1) if total_tariff_amount1 > 0
    gen ln_tariff_amount2 = ln(total_tariff_amount2) if total_tariff_amount2 > 0

    * 원래 값과 로그값의 분포를 숫자로 먼저 확인한다.
    summarize con_val_yr total_tariff_amount1 total_tariff_amount2 ///
              ln_con_val ln_tariff_amount1 ln_tariff_amount2, detail

    * 그래프 4a: TSUSA-연도 관측치별 총수입액의 분포를 본다.
    * 수입액이 소수의 큰 품목에 집중되어 있는지 확인하는 그래프다.
    histogram ln_con_val, ///
        title("Distribution of Log Import Value") ///
        xtitle("Log Consumption Import Value") ///
        ytitle("Frequency")

    graph export "$figures\hist_log_import_value.pdf", as(pdf) replace

    * 그래프 4b: TSUSA-연도 관측치별 관세총액 1의 분포를 본다.
    * 관세총액 1이 한쪽으로 치우쳐 있는지, 작은 값이 많은지 확인한다.
    histogram ln_tariff_amount1, ///
        title("Distribution of Log Tariff Amount 1") ///
        xtitle("Log Tariff Amount 1") ///
        ytitle("Frequency")

    graph export "$figures\hist_log_tariff_amount1.pdf", as(pdf) replace

    * 그래프 4c: TSUSA-연도 관측치별 관세총액 2의 분포를 본다.
    * 관세총액 2의 분포가 관세총액 1과 비슷한지 다른지 확인한다.
    histogram ln_tariff_amount2, ///
        title("Distribution of Log Tariff Amount 2") ///
        xtitle("Log Tariff Amount 2") ///
        ytitle("Frequency")

    graph export "$figures\hist_log_tariff_amount2.pdf", as(pdf) replace

    * 로그 수입액과 로그 관세총액 사이의 단순 상관계수를 확인한다.
    correlate ln_con_val ln_tariff_amount1 ln_tariff_amount2

    * 그래프 4d: 수입액과 관세총액 1의 관계를 본다.
    * 수입액이 큰 품목일수록 관세총액 1도 기계적으로 커지는지 확인한다.
    twoway ///
        (scatter ln_tariff_amount1 ln_con_val) ///
        (lfit ln_tariff_amount1 ln_con_val), ///
        title("Import Value and Tariff Amount 1") ///
        xtitle("Log Import Value") ///
        ytitle("Log Tariff Amount 1") ///
        legend(label(1 "TSUSA-year observations") label(2 "Linear fit"))

    graph export "$figures\scatter_import_value_tariff_amount1.pdf", as(pdf) replace

    * 그래프 4e: 수입액과 관세총액 2의 관계를 본다.
    * 관세총액 2를 사용해 같은 수입액-관세총액 관계를 다시 확인한다.
    twoway ///
        (scatter ln_tariff_amount2 ln_con_val) ///
        (lfit ln_tariff_amount2 ln_con_val), ///
        title("Import Value and Tariff Amount 2") ///
        xtitle("Log Import Value") ///
        ytitle("Log Tariff Amount 2") ///
        legend(label(1 "TSUSA-year observations") label(2 "Linear fit"))

    graph export "$figures\scatter_import_value_tariff_amount2.pdf", as(pdf) replace

    * 수입액이 관세총액 1을 얼마나 설명하는지 단순 회귀로 확인한다.
    reg ln_tariff_amount1 ln_con_val
    * 수입액이 관세총액 2를 얼마나 설명하는지도 같은 방식으로 확인한다.
    reg ln_tariff_amount2 ln_con_val
end

* 설명:
*   입력 자료: tsus_trade_tsusa_year_conval_panel.dta
*   출력 그래프:
*     hist_log_import_value.pdf
*     hist_log_tariff_amount1.pdf
*     hist_log_tariff_amount2.pdf
*     scatter_import_value_tariff_amount1.pdf
*     scatter_import_value_tariff_amount2.pdf
*   - 로그 수입액과 로그 관세총액 변수를 만든다.
*   - 원자료 변수와 로그 변수를 요약 통계로 확인한다.
*   - 수입액과 관세총액의 히스토그램을 저장한다.
*   - 수입액과 관세총액의 상관관계를 확인한다.
*   - fitted line이 포함된 산점도를 저장한다.


* ---------------------------------------------------------------------------
* 5. 실효 관세율과 로그 관세총액의 관계를 비교한다
* ---------------------------------------------------------------------------

capture program drop analyze_tariff_rates_and_amounts
program define analyze_tariff_rates_and_amounts
    * 품목-연도 패널을 불러와 관세율과 관세총액의 관계를 본다.
    use "$data\Stata Files\tsus_trade_tsusa_year_conval_panel.dta", clear

    * 관세율 특수값과 결측 duty 구성요소를 정리한다.
    clean_tariff_inputs

    * 실효 관세율 = 관세총액 / 수입액 * 100.
    gen eff_tariff_rate1 = total_tariff_amount1 / con_val_yr * 100 if con_val_yr > 0
    gen eff_tariff_rate2 = total_tariff_amount2 / con_val_yr * 100 if con_val_yr > 0

    * 관세총액이 양수인지 여부를 indicator로 만든다.
    gen has_tariff1 = total_tariff_amount1 > 0 if !missing(total_tariff_amount1)
    gen has_tariff2 = total_tariff_amount2 > 0 if !missing(total_tariff_amount2)
    gen has_tariff_any = has_tariff1 == 1 | has_tariff2 == 1

    * 관세율과 관세총액의 분포를 요약하고, 연도별 관세 부과 여부를 확인한다.
    summarize duty1_spec duty2_spec duty1_ad duty2_ad eff_tariff_rate1 eff_tariff_rate2, detail
    tab year has_tariff_any
    bysort year: summarize con_val_yr total_tariff_amount1 total_tariff_amount2 eff_tariff_rate1 eff_tariff_rate2

    * 관세총액의 크기 차이가 크므로 그래프와 회귀에는 로그 관세총액을 사용한다.
    gen ln_tariff_amount1 = ln(total_tariff_amount1) if total_tariff_amount1 > 0
    gen ln_tariff_amount2 = ln(total_tariff_amount2) if total_tariff_amount2 > 0

    * 그래프 5a: 실효 관세율 1과 관세총액 1의 관계를 본다.
    * 관세율이 높은 품목일수록 관세총액 1도 큰지 확인한다.
    twoway ///
        (scatter ln_tariff_amount1 eff_tariff_rate1) ///
        (lfit ln_tariff_amount1 eff_tariff_rate1), ///
        xtitle("Effective Tariff Rate 1 (%)") ///
        ytitle("Log Tariff Amount 1") ///
        title("Tariff Rate 1 and Tariff Amount 1") ///
        legend(label(1 "TSUSA-year observations") label(2 "Linear fit"))

    graph export "$figures\scatter_tariff_rate1_tariff_amount1.pdf", as(pdf) replace

    * 실효 관세율 1과 로그 관세총액 1의 단순 회귀를 실행한다.
    reg ln_tariff_amount1 eff_tariff_rate1

    * 그래프 5b: 실효 관세율 2와 관세총액 2의 관계를 본다.
    * 두 번째 관세 측정치를 사용해 같은 관계를 다시 확인한다.
    twoway ///
        (scatter ln_tariff_amount2 eff_tariff_rate2) ///
        (lfit ln_tariff_amount2 eff_tariff_rate2), ///
        xtitle("Effective Tariff Rate 2 (%)") ///
        ytitle("Log Tariff Amount 2") ///
        title("Tariff Rate 2 and Tariff Amount 2") ///
        legend(label(1 "TSUSA-year observations") label(2 "Linear fit"))

    graph export "$figures\scatter_tariff_rate2_tariff_amount2.pdf", as(pdf) replace

    * 실효 관세율 2와 로그 관세총액 2의 단순 회귀를 실행한다.
    reg ln_tariff_amount2 eff_tariff_rate2
end

* 설명:
*   입력 자료: tsus_trade_tsusa_year_conval_panel.dta
*   출력 그래프:
*     scatter_tariff_rate1_tariff_amount1.pdf
*     scatter_tariff_rate2_tariff_amount2.pdf
*   - 실효 관세율을 계산한다.
*   - 관세가 실제로 부과되었는지를 나타내는 indicator 변수를 만든다.
*   - 연도별 관세율과 관세총액을 요약한다.
*   - 실효 관세율과 로그 관세총액의 관계를 그래프로 확인한다.


* ---------------------------------------------------------------------------
* 공통 보조 단계. 1968년과 1972년 자료를 wide 형태로 바꾸고 변화 변수를 만든다
* ---------------------------------------------------------------------------

capture program drop prepare_1968_1972_change_data
program define prepare_1968_1972_change_data
    * 품목-연도 패널을 불러와 1968년과 1972년 비교용 자료를 만든다.
    use "$data\Stata Files\tsus_trade_tsusa_year_conval_panel.dta", clear

    * 관세율 특수값과 관세총액을 분석용으로 정리한다.
    clean_tariff_inputs

    * 1968년과 1972년의 관세율 변화를 계산하기 위해 실효 관세율을 만든다.
    gen eff_tariff_rate1 = total_tariff_amount1 / con_val_yr * 100 if con_val_yr > 0
    gen eff_tariff_rate2 = total_tariff_amount2 / con_val_yr * 100 if con_val_yr > 0
    * 관세가 양수인지 여부도 변화 자료에 같이 남긴다.
    gen has_tariff1 = total_tariff_amount1 > 0 if !missing(total_tariff_amount1)
    gen has_tariff2 = total_tariff_amount2 > 0 if !missing(total_tariff_amount2)
    gen has_tariff_any = has_tariff1 == 1 | has_tariff2 == 1

    * 변화 분석은 1968년과 1972년만 비교한다.
    keep if inlist(year, 1968, 1972)

    * reshape에 필요한 핵심 변수만 남긴다.
    keep tsusa year con_val_yr total_tariff_amount1 total_tariff_amount2 ///
         eff_tariff_rate1 eff_tariff_rate2 has_tariff_any

    * tsusa별로 1968년 값과 1972년 값을 한 행에 나란히 배치한다.
    reshape wide con_val_yr total_tariff_amount1 total_tariff_amount2 ///
                 eff_tariff_rate1 eff_tariff_rate2 has_tariff_any, ///
        i(tsusa) j(year)

    * 1972년 관세율에서 1968년 관세율을 빼서 관세율 변화를 만든다.
    gen change_eff1 = eff_tariff_rate11972 - eff_tariff_rate11968
    gen change_eff2 = eff_tariff_rate21972 - eff_tariff_rate21968

    * 수입액의 수준 변화, 퍼센트 변화, 로그 변화를 만든다.
    gen change_con_val = con_val_yr1972 - con_val_yr1968
    gen pct_change_con_val = 100 * (con_val_yr1972 - con_val_yr1968) / con_val_yr1968 if con_val_yr1968 > 0
    gen log_change_con_val = ln(con_val_yr1972) - ln(con_val_yr1968) if con_val_yr1968 > 0 & con_val_yr1972 > 0

    * 관세총액도 1972년 값에서 1968년 값을 빼서 변화를 계산한다.
    gen change_tariff_amount1 = total_tariff_amount11972 - total_tariff_amount11968
    gen change_tariff_amount2 = total_tariff_amount21972 - total_tariff_amount21968

    * 로그 수입액 변화의 1-99 percentile 범위만 그래프용으로 남기기 위한 필터를 만든다.
    summarize log_change_con_val if !missing(log_change_con_val), detail
    gen keep_log_change = inrange(log_change_con_val, r(p1), r(p99)) if !missing(log_change_con_val)

    * 관세율 변화 1의 극단값을 줄이기 위한 필터를 만든다.
    summarize change_eff1 if !missing(change_eff1), detail
    gen keep_change_eff1 = inrange(change_eff1, r(p1), r(p99)) if !missing(change_eff1)

    * 관세율 변화 2의 극단값을 줄이기 위한 필터를 만든다.
    summarize change_eff2 if !missing(change_eff2), detail
    gen keep_change_eff2 = inrange(change_eff2, r(p1), r(p99)) if !missing(change_eff2)

    * 그래프와 회귀에 사용할 최종 표본 indicator를 만든다.
    gen keep_change_graph1 = keep_log_change == 1 & keep_change_eff1 == 1 & con_val_yr1968 > 0
    gen keep_change_graph2 = keep_log_change == 1 & keep_change_eff2 == 1 & con_val_yr1968 > 0

    * 필터 적용 후 남는 관측치 수를 확인한다.
    tab keep_change_graph1
    tab keep_change_graph2
end

* 설명:
*   사용되는 곳: analyze_import_value_changes, make_binned_tariff_change_graph
*   - 1968년과 1972년 관측치만 남긴다.
*   - TSUSA-연도 패널을 long format에서 wide format으로 바꾼다.
*   - 관세율 변화, 관세총액 변화, 수입액 변화 변수를 만든다.
*   - 그래프와 회귀분석에서 극단값 영향을 줄이기 위해 percentile 기준 필터를 만든다.


* ---------------------------------------------------------------------------
* 6. 1968-1972년 관세율 변화와 수입액 변화의 관계를 비교한다
* ---------------------------------------------------------------------------

capture program drop analyze_import_value_changes
program define analyze_import_value_changes
    * 1968-1972년 변화 자료를 만든 뒤, 관세율 변화와 수입액 변화의 관계를 분석한다.
    prepare_1968_1972_change_data

    * 관세율 변화 1과 로그 수입액 변화의 관계를 산점도와 fitted line으로 확인한다.
    twoway ///
        (scatter log_change_con_val change_eff1 [aw=con_val_yr1968] if keep_change_graph1 == 1) ///
        (lfit log_change_con_val change_eff1 [aw=con_val_yr1968] if keep_change_graph1 == 1), ///
        xtitle("Change in Effective Tariff Rate 1, 1972 - 1968") ///
        ytitle("Log Change in Consumption Import Value") ///
        title("Tariff Change 1 and Import Value Change") ///
        legend(label(1 "TSUSA observations") label(2 "Weighted linear fit"))

    graph export "$figures\scatter_tariff_change1_log_import_change.pdf", as(pdf) replace

    * 관세율 변화 1이 수입액 변화와 얼마나 관련되는지 가중 회귀로 확인한다.
    reg log_change_con_val change_eff1 [aw=con_val_yr1968] if keep_change_graph1 == 1

    * 관세율 변화 2와 로그 수입액 변화의 관계를 같은 방식으로 확인한다.
    twoway ///
        (scatter log_change_con_val change_eff2 [aw=con_val_yr1968] if keep_change_graph2 == 1) ///
        (lfit log_change_con_val change_eff2 [aw=con_val_yr1968] if keep_change_graph2 == 1), ///
        xtitle("Change in Effective Tariff Rate 2, 1972 - 1968") ///
        ytitle("Log Change in Consumption Import Value") ///
        title("Tariff Change 2 and Import Value Change") ///
        legend(label(1 "TSUSA observations") label(2 "Weighted linear fit"))

    graph export "$figures\scatter_tariff_change2_log_import_change.pdf", as(pdf) replace

    * 관세율 변화 2에 대해서도 가중 회귀를 실행한다.
    reg log_change_con_val change_eff2 [aw=con_val_yr1968] if keep_change_graph2 == 1

    * 두 관세율 변화를 동시에 넣어 수입액 변화와의 관계를 확인한다.
    reg log_change_con_val change_eff1 change_eff2 [aw=con_val_yr1968] if keep_log_change == 1 & keep_change_eff1 == 1 & keep_change_eff2 == 1 & con_val_yr1968 > 0
end

* 설명:
*   입력 자료: prepare_1968_1972_change_data가 만든 1968-1972 변화 자료
*   출력 그래프:
*     scatter_tariff_change1_log_import_change.pdf
*     scatter_tariff_change2_log_import_change.pdf
*   - 관세율 변화와 로그 수입액 변화의 관계를 산점도로 그린다.
*   - 1968년 수입액을 가중치로 사용해 가중 회귀분석을 실행한다.


* ---------------------------------------------------------------------------
* 7. 관세율 변화를 구간으로 묶고 평균 수입액 변화를 그래프로 그린다
* ---------------------------------------------------------------------------

capture program drop make_binned_tariff_change_graph
program define make_binned_tariff_change_graph
    * 1968-1972년 변화 자료를 만든 뒤, 관세율 변화를 구간별로 요약한다.
    prepare_1968_1972_change_data

    * 관세율 변화 1을 20개 구간으로 나눈다.
    xtile tariff_change_bin1 = change_eff1 if keep_change_graph1 == 1, nq(20)

    * 그래프에 사용할 관측치만 남기고, 큰 음수 극단값을 제외한다.
    keep if keep_change_graph1 == 1
    keep if change_eff1 > -20

    * 극단값 제외 후 다시 20개 구간을 만든다.
    xtile tariff_change_bin1_trim = change_eff1, nq(20)

    * 구간별 관측치 수, 평균 수입액 변화, 평균 관세율 변화를 계산한다.
    collapse ///
        (count) n_obs = log_change_con_val ///
        (mean) mean_log_change = log_change_con_val ///
               mean_change_eff1 = change_eff1 ///
        [aw=con_val_yr1968], ///
        by(tariff_change_bin1_trim)

    * 구간 평균값을 이용해 관세율 변화와 수입액 변화의 패턴을 더 부드럽게 보여준다.
    twoway ///
        (scatter mean_log_change mean_change_eff1 [aw=n_obs]) ///
        (lfit mean_log_change mean_change_eff1), ///
        xtitle("Change in Effective Tariff Rate 1, 1972 - 1968") ///
        ytitle("Mean Log Change in Consumption Import Value") ///
        title("Binned Tariff Change 1 and Import Value Change, Trimmed")

    * 구간 평균 자료에서도 단순 선형 관계를 확인한다.
    reg mean_log_change mean_change_eff1 [aw=n_obs]
end

* 설명:
*   입력 자료: prepare_1968_1972_change_data가 만든 1968-1972 변화 자료
*   - 관세율 변화를 여러 구간으로 나눈다.
*   - 각 구간별 평균값으로 자료를 합친다.
*   - 평균 관세율 변화와 평균 로그 수입액 변화의 관계를 그래프로 그린다.


* ===========================================================================
* 실행
* ===========================================================================

run_post_merge_analysis

log close
```
