
clear all

/*******************************************************************************
#1. Open dataset
*******************************************************************************/

use "$datadir\analysis", clear
	
unique patid
		
/*******************************************************************************
#2. Create csv for output
*******************************************************************************/
	
	cap file close textfile 
	file open textfile using "$outputdir/analysis.csv", write replace
	file write textfile "sep=;" _n
	file write textfile "Risk period" ";" "All" ";" ";" "QRISK2" ";" ";" ";" ";" "Hypertension" _n
	file write textfile ";" ";" ";" "Raised risk" ";"  ";" "Low risk" ";" ";" "Raised risk" ";"  ";" "Low risk" _n
	file write textfile ";" "N events" ";" "IR (95% CI)" ";" "N events" ";" "IR (95% CI)" ";" "N events" ";" "IR (95% CI)" ";" "N events" ";" "IR (95% CI)" ";" "N events" ";" "IR (95% CI)" _n


/*******************************************************************************
#3. Number of events
*******************************************************************************/
	
	egen newid = group(patid)
	
	*Number of events
	foreach group in cohort qrisk1 qrisk0 hrisk1 hrisk0 {
		forvalues x=0/4 {
			if "`group'"=="cohort" unique newid if exgr==`x' & nevents==1 
			if "`group'"=="qrisk1" unique newid if exgr==`x' & nevents==1 & qriskmain==1
			if "`group'"=="qrisk0" unique newid if exgr==`x' & nevents==1 & qriskmain==0
			if "`group'"=="hrisk1" unique newid if exgr==`x' & nevents==1 & hypertens==1
			if "`group'"=="hrisk0" unique newid if exgr==`x' & nevents==1 & hypertens==0
			
			local exgr_`group'_`x'=r(sum) 
		}  // end forvalues of exgr	
		
		if "`group'"=="cohort" unique newid if exgr==21 & nevents==1 
		if "`group'"=="cohort" unique newid if exgr==22 & nevents==1 
			
/*******************************************************************************
#4. Season adjusted model
*******************************************************************************/		
	
		if "`group'"=="cohort" xi: xtpoisson nevents i.exgr i.season, fe i(newid) offset(loginterval) irr
		if "`group'"=="qrisk1" xi: xtpoisson nevents i.exgr i.season if qriskmain==1, fe i(newid) offset(loginterval) irr	
		if "`group'"=="qrisk0" xi: xtpoisson nevents i.exgr i.season if qriskmain==0, fe i(newid) offset(loginterval) irr	
		if "`group'"=="hrisk1" xi: xtpoisson nevents i.exgr i.season if hypertens==1, fe i(newid) offset(loginterval) irr	
		if "`group'"=="hrisk0" xi: xtpoisson nevents i.exgr i.season if hypertens==0, fe i(newid) offset(loginterval) irr
		forvalues x=1/4 {	
			local irr_`group'_`x'=exp(_b[_Iexgr_`x'])
			local ci1_`group'_`x'=exp(_b[_Iexgr_`x']-1.96*_se[_Iexgr_`x'])
			local ci2_`group'_`x'=exp(_b[_Iexgr_`x']+1.96*_se[_Iexgr_`x'])	
			} // end forvalues of exgr
		} // end foreach group
		
/*******************************************************************************
#7. Output results to csv
*******************************************************************************/
		
	*Create label for risk period to add to output
	local label1 "15-28 days"
	local label2 "29-59 days"
	local label3 "60-90 days"
	local label4 "91-120 days"
	
	*Output results
	forvalues x=1/4 {
		file write textfile "`label`x''" ";" (`exgr_cohort_`x'') ";" %5.2f (`irr_cohort_`x'') " (" %4.2f (`ci1_cohort_`x'') "-" %4.2f (`ci2_cohort_`x'') ")" ";" (`exgr_qrisk1_`x'') ";" %5.2f (`irr_qrisk1_`x'') " (" %4.2f (`ci1_qrisk1_`x'') "-" %4.2f (`ci2_qrisk1_`x'') ")" ";" (`exgr_qrisk0_`x'') ";" %5.2f (`irr_qrisk0_`x'') " (" %4.2f (`ci1_qrisk0_`x'') "-" %4.2f (`ci2_qrisk0_`x'') ")" ";" (`exgr_hrisk1_`x'') ";" %5.2f (`irr_hrisk1_`x'') " (" %4.2f (`ci1_hrisk1_`x'') "-" %4.2f (`ci2_hrisk1_`x'') ")" ";" (`exgr_hrisk0_`x'') ";" %5.2f (`irr_hrisk0_`x'') " (" %4.2f (`ci1_hrisk0_`x'') "-" %4.2f (`ci2_hrisk0_`x'') ")" _n 
	} // end forvalues 
	file write textfile "Baseline" ";" (`exgr_cohort_0') ";" "ref" ";" (`exgr_qrisk1_0') ";" "ref" ";" (`exgr_qrisk0_0') ";" "ref" ";" (`exgr_hrisk1_0') ";" "ref" ";" (`exgr_hrisk0_0') ";" "ref" _n /*baseline period*/
	
	
	capture file close textfile 	

/*******************************************************************************
>> end loops	
*******************************************************************************/	
	