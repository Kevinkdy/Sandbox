# Analysis Guide
```stata
clear all                  // Clears Stata’s memory before running the script.
set more off               // Prevents Stata from pausing the output.

cd "C:\Users\USER\Desktop\Tariff-RA-Data"   // Sets the project folder as the working directory.

log using "Analysis\Codes\01a_append_log.smcl", replace   // Starts a log file to record the script output.

global data "Analysis\Data Files"   // Defines the main data folder path.

tempfile combined           // Creates a temporary file to store the appended dataset.
local first = 1             // Marks the first loop iteration when combining files.

forvalues schedule = 1/8 {

    import excel "$data\Raw Files\TSUS_data\verified_schedule`schedule'_test.xlsx", cellrange(A2) firstrow clear  //This command imports the Excel file corresponding to the current schedule number. The import starts at cell A2, and the first row of the imported range is used as the variable names. The clear option removes the previously loaded dataset from memory before importing the next schedule.

    * Drop spurious Excel column
    capture drop AH

    * Standardize types before append
    tostring item suffix, replace
    capture confirm numeric variable flag
    if !_rc {
        tostring flag, replace
    }
    capture confirm numeric variable unit_spec
    if !_rc {
        tostring unit_spec, replace
    }

    * Convert duty variables to string
    forvalues year = 1968/1972 {
        tostring duty1_spec`year' duty2_spec`year' duty1_ad`year' duty2_ad`year', replace force
    }

    * Reshape from wide to long
    reshape long duty1_spec duty1_ad duty2_spec duty2_ad, ///
        i(item suffix units unit_spec flag notes) ///
        j(year)

    * Append to combined dataset
    if `first' {
        save `combined'
        local first = 0
    }
    else {
        append using `combined'
        save `combined', replace
    }
}

* Drop completely empty variables
foreach var of varlist _all {
    quietly count if !missing(`var')
    if r(N) == 0 {
        drop `var'
    }
}

* Clean suffix formatting
replace suffix = "00" if suffix == "0"
replace suffix = "00" if suffix == "000"
replace suffix = "05" if suffix == "5"

sort item

save "$data\Stata Files\tsus_appended.dta", replace

log close
```
