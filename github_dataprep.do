

use "$datadir\intermediate\dataset", clear		

/*******************************************************************************
*******************************************************************************
#A. MAKE dates DATASET - date at change in state of each var
*******************************************************************************
*******************************************************************************/	

/* 
Go through each variable and create a dataset containing the variable and date. 
Then append each of these datasets to each other. 
Using the completed dataset containing all dates:
	 - check for records that happen on the same day
	 - time-update all records using [_n+/-1]
	 - calculate age in days at date (used to create interval)
	 - calculate interval in days between changes in state (records)
	 - drop any records before indexdate and after end of FU
	 - identify whether MACE event happens within interval
*/
	
	
/*******************************************************************************
#2. Find start and end dates and save to file
*******************************************************************************/	
preserve	
keep patid indexdate enddate // only keep useful vars
		
* 2.1 date1 = start FU
gen long date1=indexdate
label var date1 "indexdate"
drop indexdate

* 2.2 date2 = end FU
gen long date2=enddate
label var date2 "end FU date"
drop enddate	
				
* 2.3 reshape
reshape long date, i(patid) j(type)
label var date "date at cutpoint"
format date %td
label var type "type of cutpoint, use with label var"
		
* 2.4 label as start/end dates
gen label=1
label var label "label to identify type of cutpt"
* create value labels for all values of the label var
label define lablelbl 1 "startend" 2 "period" 3 "season"
label values label lablelbl
		
* 2.5 save
label data "dates and cutpoint types"
notes: cutpts and cutpoint types
save "$datadir\intermediate\dates", replace
restore
	
	
/*******************************************************************************
#3. Generate exposure group cutpoints and reshape and save to dates file
*******************************************************************************/
preserve 
keep patid exposdate enddate // only keep useful vars

* 3.1 create cutpoints for each risk period
local counter=1 // counter var used to number cutpoints
gen long date`counter' = exposdate - 14 // sets cutpt for pre-exposed time
label var date`counter' "end of unexposed pre-vaccination period"
local counter=`counter'+1
gen long date`counter' = exposdate // sets cut pt vaccination date
label var date`counter' "end of pre-exposure period (day before vaccination)"
local counter=`counter'+1			
gen long date`counter' = exposdate + 14 // sets end of post-vaccination exclusion period
label var date`counter' "end of post-vaccination (1 to 14 days) exclusion"
local counter=`counter'+1
gen long date`counter' = exposdate + 28 // sets end of risk period 1 (15-28 days post-vaccination)
label var date`counter' "end of risk period 1 (15 to 28 days post-vaccination)"
local counter=`counter'+1
gen long date`counter' = exposdate + 59 // sets end of risk period 2 (29-59 days post-vaccination)
label var date`counter' "end of risk period 2 (29 to 59 days post-vaccination)"
local counter=`counter'+1
gen long date`counter' = exposdate + 90 // sets end of risk period 3 (60-90 days post-vaccination)
label var date`counter' "end of risk period 2 (60 to 90 days post-vaccination)"
local counter=`counter'+1
gen long date`counter' = exposdate + 120 // sets end of risk period 4 (91-120 days post-vaccination)
label var date`counter' "end of risk period 2 (29 to 59 days post-vaccination)"
local counter=`counter'+1
gen long date`counter' = enddate // sets cutpt for baseline time
label var date`counter' "end of unexposed post-vaccination period"

drop exposdate enddate
		
* 3.2 reshape
reshape long date, i(patid) j(type)
format date %td
label var date "date at cutpoint"
label var type "type of cutpoint, use with label var"
		
* 3.3 label as risk periods
gen label=2
label var label "label to identify type of cutpt"
label define lablelbl 1 "startend" 2 "period" 3 "season"
label values label lablelbl
		
/*
1=end unexposed (prior vaccination)
2=end pre-exposed
3=end post-vaccination
4=end risk1
5=end risk2
6=end risk3
7=end risk4
8=end unexposed (post vaccination)
*/

* create exgr var
recode type 1=0 8=0 2=21 3=22 4=1 5=2 6=3 7=4, gen(exgr)
		
label define exgr 0 "unexp" 21 "prexp" 22 "ptexp" 1 "risk1" 2 "risk2" 3 "risk3" 4 "risk4"
label values exgr exgr
label var exgr "exposure: baseline, pre-exp, post-exp, risk periods post-vacc"


sort patid date
order patid date type exgr
append using "$datadir\intermediate\dates"
save "$datadir\intermediate\dates", replace
restore
	

/******************************************************************************
#4. Generate season
******************************************************************************/	
preserve
keep patid // only keep useful vars	
	
* 4.1 season in main analysis - first day of each season: warmer (Apr-Sep) 
*& colder (Oct-Mar)
local counter=1
forvalues yr = 2008/2019 {
foreach month in 4 10 {
	gen str = "1/`month'/`yr'"	// generate year as string
	gen date`counter' = date(str, "DMY")
	label var date`counter' "date at start of `month' `yr'"
	format date`counter' %td
	drop str
	local counter=`counter'+1
	} // end foreach month
	} // end forvalues yr 

foreach var of varlist date* {
replace `var'=`var'-1
}	
	
* 4.2 reshape
reshape long date, i(patid) j(type)
label var date "date at cutpoint"
label var type "type of cutpoint, use with label var"
gen season = mod(type,2) 
label var season "season of year"
label define season 0 "warmer" 1 "colder" 
label values season season
		
* 4.3 label as risk periods
gen label=3
label var label "label to identify type of cutpt"
label define lablelbl 1 "startend" 2 "period" 3 "season" 
label values label lablelbl
		
* 4.4 append to dataset containing start and end cutpoints
order patid date type label 
append using "$datadir\intermediate\dates"
save "$datadir\intermediate\dates", replace
restore

/*******************************************************************************
*******************************************************************************
#B. MAKE static variables DATASET 
*******************************************************************************
*******************************************************************************/	
/*Age going in here though would normally be in dates section (only have 1 
year of data here)*/

/*******************************************************************************
#5. Generate age group cutpoints and reshape and save to cutpoint file
*******************************************************************************/	
preserve
keep patid indexdate dob // only keep useful vars
	
* 5.1 gen age
gen age=(indexdate-dob)/365
replace age=int(age)

gen ageband=age
recode ageband min/64=1 65/74=2 75/max=3
label define ageband 1 "40-64" 2 "65-74" 3 "75-84"
label values ageband ageband

save "$datadir\intermediate\vars", replace
restore

/*******************************************************************************
#6. Identify if flu vaccine match season
*******************************************************************************/	
preserve
keep patid indexdate

* 6.1 flag year as match or not
gen year=year(indexdate)
gen vaccmatch=0 if year==2009 | year==2014
replace vaccmatch=1 if vaccmatch!=0

* 6.2 label 
label var vaccmatch "Vaccine strains matched circulating strains"
label define yesno 0 "no" 1 "yes" 
label values vaccmatch yesno

* 6.3 merge to dataset containing cutpoint dates
keep patid vaccmatch
merge 1:1 patid using "$datadir\intermediate\vars", nogen
save "$datadir\intermediate\vars", replace
restore


/*******************************************************************************
#7. Identify ARI within 28 days of outcome
*******************************************************************************/	
preserve
keep patid eventdate // only keep useful vars
		
* 7.1 add in ARI diagnosis dates
merge 1:m patid using "$datadir\ARI", keep(match master) keepusing(ari aridate) nogen
		
* 7.2 Idenditfy ARI state include baseline zero state
gen days=eventdate-aridate
gen ari28days=1 if days<=28 & days>=0 & ari==1
replace ari28days=0 if ari28days!=1
label values ari28days yesno
label var ari28days "ARI in 28 days prior to event"
	
* 7.3 merge to dataset containing cutpoint dates
gsort patid -ari28days
keep patid ari28days
duplicates drop patid, force
merge 1:1 patid using "$datadir\intermediate\vars", nogen
save "$datadir\intermediate\vars", replace
restore
	
	
/*******************************************************************************
#8. Identify if vaccination was earlier or late in season
*******************************************************************************/	
preserve
keep patid exposdate // only keep useful vars
				
* 8.1 Idenditfy timing of vaccination (early = 01/09-15/11 or late = 16/11-31/03)
gen month=month(exposdate)
gen day=day(exposdate)
gen timing=1 if month>=11 
replace timing=0 if month<11
replace timing=0 if month==1 & day <16

* 8.2 label 
label var timing "Vaccination is before or after 15 nov"
label define timing 0 "before" 1 "after" 
label values timing timing
	
* 8.3 merge to dataset containing cutpoint dates
sort patid
keep patid timing
merge 1:1 patid using "$datadir\intermediate\vars", nogen
save "$datadir\intermediate\vars", replace
restore
	
	
/*******************************************************************************
#9. Identify associated hospital stay
*******************************************************************************/	
preserve
keep patid eventdate

* 9.1 Identify stays in dataset
merge 1:1 patid eventdate using "$definedir\earliest_mace", keep (master match) keepusing(hosp) nogen 
merge 1:m patid using "$datadir\linkeddata\hes_epi", keep(master match) keepusing(spno epistart) nogen
sort patid 
replace epistart=. if eventdate!=epistart
replace hosp=1 if eventdate==epistart & hosp==.
replace spno="" if hosp==.
sort patid eventdate epistart
duplicates drop patid, force
merge 1:m patid spno using "$datadir\linkeddata\hes_hosp", keep(master match) keepusing(admidate dischardate stay) nogen

gen assocstay=1 if hosp==1 & stay!=.
replace assocstay=0 if assocstay!=1
keep patid stay assocstay
gsort patid -assocstay
duplicates drop patid, force

* 9.2 label 
label var assocstay "if had a hospital stay"
label var stay "length of stay"
label define assocstay 0 "no stay" 1 "stay" 
label values assocstay assocstay
	
* 9.3 merge to dataset containing cutpoint dates
merge 1:1 patid using "$datadir\intermediate\vars", nogen
save "$datadir\intermediate\vars", replace
restore
*/
		
/*******************************************************************************
*******************************************************************************
#C. Make SCCS dataset
*******************************************************************************
*******************************************************************************/	

	
/*******************************************************************************
#10. Open cutpoint dates file 
*******************************************************************************/

use "$datadir\intermediate\dates", clear
gsort patid date -exgr // sort in this way as collapse uses first non-missing so need to have larger exgr first as some will have a risk period cut date on the same date as the end date which is set to baseline. ISSUE: including -exgr causes those with end of follow-up before all risk periods to be collapsed with baseline so later propagate of exgr fails to be correct, fix is below
	
	
/*******************************************************************************
#11. deal with records on the same day 
*******************************************************************************/
collapse (firstnm) label type season exgr, by(patid date)
*fix data for the above issue re those who end follow-up early but have baseline when should be risk period:
by patid: replace exgr=exgr[_n+1] if exgr==0 & exgr[_n+1]>0 & exgr[_n+1]!=. & type==8
sort patid date
label var label "label to identify type of cutpt"
label var type "type of cutpoint, use with label var"
label var exgr "infection risk periods"
label var season "season of year"
label var date "date of changes in state"
	
label values label lablelbl
label values exgr exgr
label values season season
	
* identify if there are any further records on the same day
duplicates report patid date // all good


/*******************************************************************************
#12. add individual based data 
*******************************************************************************/	
* add main dataset and further variables created
merge m:1 patid using "$datadir\intermediate\dataset", nogen
merge m:1 patid using "$datadir\intermediate\vars", nogen
	
gen long cutp=(date-dob)

	
/*******************************************************************************
#14. propagate season through patient's record in season var 
*******************************************************************************/	
* need to update season for intervals where data is missing
sort patid date	
count if season>=.
local nmiss = r(N)
local nchange = 1 // counter var
while `nchange'>0 {
	bysort patid: replace season = season[_n+1] if season>=.
	count if season>=.
	local nchange = `nmiss'-r(N)
	local nmiss = r(N)
	} /* end while `nchange'>0*/
	

/*******************************************************************************
#15. propagate exgr through patient's record in exgr var 
*******************************************************************************/	
* need to update any exposure values for intervals that happen between different
* risk periods - for example, season could have changed during a risk period 
* therefore need to make sure that the indvidual is appropriately exposed
* deal with missing values of exposure
sort patid date
count if exgr>=.
local nmiss = r(N)
local nchange = 1 // counter var
while `nchange'>0 {
	bysort patid: replace exgr = exgr[_n+1] if exgr>=.
	count if exgr>=.
	local nchange = `nmiss'-r(N)
	local nmiss = r(N)
	}/* end while `nchange'>0*/
replace exgr = 0 if exgr==.	
	
	
/*******************************************************************************
#16. Drop records before startdate and after enddate
*******************************************************************************/
drop if date<indexdate
drop if date>enddate
	
	
/*******************************************************************************
#17. Identify number of MACE events in each interval
*******************************************************************************/
* eventdate = age at MACE
gen long eventday=eventdate-dob
label var eventday "age in days at MACE"

* count the number of events in each interval
bysort patid: gen long nevents = 1 if eventday > cutp[_n-1]+0.5 & eventday <= cutp[_n]+0.5
collapse (sum) nevents, by(patid cutp date label type age ageband season exgr gender died diedinfu ari28days vaccmatch timing stay assocstay dob indexdate enddate exposdate eventdate hypertens qriskmain qriskdet) // create one record /px / day / cut point type
label var nevents "number of MACE events in interval"
sort patid date

	
/*******************************************************************************
#18. Count number of days within each interval
*******************************************************************************/

*replace date back to start of season now that variable propagatation is done
replace date=date+1 if label==3
replace cutp=cutp+1 if label==3

*intervals
replace cutp=cutp-1 if _n==1 // make cutp for index date, 1 day earlier so that interval correctly calculated
bysort patid: gen long interval = cutp[_n] - cutp[_n-1]
label var interval "duration of interval in days"
	

/*******************************************************************************
#19. Clean up:
- No longer need type or cutp
- can't do anything with zero intervals so drop
- missing intervals represent cut points for start of FU
- used to calculate first interval, no longer needed so drop
*******************************************************************************/
*fit issue of those with exactly 14 days between index and exposdate not having an interval
by patid: replace interval=1 if exgr[_n+1]==21 & cutp[_n+1]-cutp[_n]==14 & _n==1
*fit issue of those with exposure date on index
by patid: replace interval=1 if exgr==21 & interval==. & indexdate==exposdate & _n==1
drop type cutp
count if interval==0
count if interval==.
drop if interval==0 | interval==.

*Identify those with event on indexdate as current coding doesn't pick up
by patid: gen order=_n
replace nevents=1 if eventdate==indexdate & order==1
drop order

*Identify those with event on season change as doesn't identify
by patid: egen count=sum(nevents) 
by patid: replace nevents=1 if eventdate==date[_n-1] & label[_n-1]==3 & count==0
replace nevents=1 if eventdate==enddate & date==eventdate & count==0 
drop count

*drop patients who have no baseline time
unique patid
gen baseline=1 if exgr==0 
by patid: egen baselinecount=max(baseline)
drop if baselinecount==.

drop baseline baselinecount


*gen analysable sex variable
gen sex=1 if gender=="M"
replace sex=0 if gender=="F"
drop if gender=="I"
label define sex 0 "Women" 1 "Men"
label values sex sex
drop gender

*clean and label missed variables
replace died=0 if died==.
label values died yesno

label define hypertens 0 "No hypertension" 1 "Hypertension"
label values hypertens hypertens


/*******************************************************************************
#20. Generate loginterval and save dataset
*******************************************************************************/	
* create loginterval for analysis
gen loginterval = log(interval)
label var loginterval "log of interval duration"
	
* save
compress
save "$datadir\analysis", replace
