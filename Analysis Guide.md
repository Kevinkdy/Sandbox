<img width="940" height="294" alt="image" src="https://github.com/user-attachments/assets/1f79e962-999d-4653-8889-59469b41318a" />



# Analysis Guide
## Append.do
```stata
clear all                  // Clears Stata's memory.
set more off               // Prevents output pauses.

cd "C:\Users\USER\Desktop\Tariff-RA-Data"   // Sets the working directory.

log using "Analysis\Codes\01a_append_log.smcl", replace   // Starts a log file.

global data "Analysis\Data Files"   // Defines the data folder path.

tempfile combined           // Creates a temporary file for the combined data.
local first = 1             // Identifies the first schedule.

forvalues schedule = 1/8 {  // Repeats the commands for schedules 1 through 8.

    import excel "$data\Raw Files\TSUS_data\verified_schedule`schedule'_test.xlsx", cellrange(A2) firstrow clear
    // Imports each Excel schedule. Uses row 2 as the variable names.

    capture drop AH
    // Drops the Excel column AH if it exists.

    tostring item suffix, replace
    // Converts item and suffix to strings to preserve formatting.

    capture confirm numeric variable flag
    if !_rc {
        tostring flag, replace
    }
    // Converts flag to a string if it is numeric.

    capture confirm numeric variable unit_spec
    if !_rc {
        tostring unit_spec, replace
    }
    // Converts unit_spec to a string if it is numeric.

    forvalues year = 1968/1972 {
        tostring duty1_spec`year' duty2_spec`year' duty1_ad`year' duty2_ad`year', replace force
    }
    // Converts the duty columns for 1968-1972 to strings.

    reshape long duty1_spec duty1_ad duty2_spec duty2_ad,
        i(item suffix units unit_spec flag notes) j(year)
    // Creates a separate observation for each item, suffix, and year.

    if `first' {
        save `combined'
        local first = 0
    }
    // Saves the first schedule as the temporary combined file.

    else {
        append using `combined'
        save `combined', replace
    }
    // Adds each later schedule to the temporary combined file.
}

foreach var of varlist _all {
    quietly count if !missing(`var')
    if r(N) == 0 {
        drop `var'
    }
}
// Drops columns that contain no data.

replace suffix = "00" if suffix == "0"
replace suffix = "00" if suffix == "000"
replace suffix = "05" if suffix == "5"
// Standardizes incorrectly formatted suffix values.
//The schedules were checked for other one-digit suffix values, but only "0" and "5" were found. Therefore, the script manually standardizes only the observed inconsistent entries: "0" and "000" to "00", and "5" to "05".

sort item
// Sorts the dataset by item code.

save "$data\Stata Files\tsus_appended.dta", replace
// Saves the combined dataset.

log close
// Closes the log file.
