****Jason Semprini - Medicaid Expansions and Private Insurance ‘Crowd-Out’ (1999-2019) - Published 5/22/2023****

clear all

set seed 123

***Set working directory***


use stata-state-1999-2019.dta

***create numeric state code (pseudo-statefips)***
egen statefips=group(state)

***Create binary, time-variant indicator for expansion in year t, for state s***
gen expand=0

***create expansion cohort id***
gen id=0

***create variable indicating expansion year***
gen first_tx=0

replace expand=1 if state=="New York" | state=="Vermont" | state=="Delaware"
replace id=1 if state=="New York" | state=="Vermont" | state=="Delaware"
replace first_tx=1999 if id==1

replace expand=1 if state=="Massachusetts" & year>2005
replace id=2 if  state=="Massachusetts" 
replace first_tx=2006 if id==2

replace expand=1 if state=="District of Columbia" & year>2010
replace expand=1 if state=="Washington" & year>2010
replace id=3 if state=="District of Columbia" | state=="Washington" 
replace first_tx=2011 if id==3

replace expand=1 if state=="California" & year>2011
replace id=4 if state=="California" 
replace first_tx=2012 if id==4


foreach x in Arizona Arkansas Colorado Connecticut Hawaii Illinois Iowa Kentucky Maryland Michigan Minnesota Nevada Ohio Oregon {
	replace expand=1 if state=="`x'" & year>=2014
	replace id=5 if state=="`x'"
}
replace expand=1 if state=="West Virginia" & year>=2014
replace expand=1 if state=="New Mexico" & year>=2014
replace expand=1 if state=="New Jersey" & year>=2014
replace expand=1 if state=="North Dakota" & year>=2014
replace expand=1 if state=="Rhode Island" & year>=2014
replace id=5 if state=="West Virginia" | state=="New Mexico" | state=="New Jersey" | state=="North Dakota" | state=="Rhode Island" 
replace first_tx=2014 if id==5


replace expand=1 if state=="Pennsylvania" & year>2014
replace expand=1 if state=="New Hampshire" & year>2014
replace expand=1 if state=="Indiana" & year>2014
replace id=6 if state=="Pennsylvania" | state=="New Hampshire" | state=="Indiana" 
replace first_tx=2015 if id==6

replace expand=1 if state=="Alaska" & year>2015
replace expand=1 if state=="Montana" & year>2015
replace id=7 if state=="Alaska" | state=="Montana"
replace first_tx=2016 if id==7


replace expand=1 if state=="Louisiana" & year>2016
replace id=8 if state=="Louisiana" 
replace first_tx=2017 if id==8


replace expand=1 if state=="Virginia" & year>2018
replace id=9 if state=="Virginia" 
replace first_tx=2019 if id==9


*wide*
reshape wide rate, i(state year statefips expand) j(coverage) string

rename (rateMedicaid rateMedicare ratePrivate ratePublic rateUninsured) (Medicaid Medicare Private Public Uninsured)

order state year statefips expand Uninsured Medicaid Medicare Public Private id


***plot means by expansion cohort***
foreach y in Private    {
	
reg `y' i.year#i.id
margins year#id
marginsplot, noci scheme(tab2) xline(2005.5 2010.5 2011.5 2013.5 2014.5 2015.5 2016.5 2018.5, lcolor(gray) lpattern(dashed)) xlab(, nogrid) ylab(, nogrid) legend( rows(1))  title("`y'")  xtitle("Years") ytitle("Rate")
graph save p1_`y'.gph , replace
graph export p1_`y'.png, replace
}

xtset statefips year


*1-naive twfe*
estimates clear
foreach y in Private{
	eststo: xtreg `y' i.expand i.year , vce(cluster statefips) fe
}



*2-Decomp*
*REQUIRES: ssc install bacondecomp
foreach y in Private{
	bacondecomp `y' expand, ddetail vce(cluster statefips) 
	estimates store bd_`y'
graph save bd_`y'.gph , replace
graph export bd_`y'.png, replace
}


***modern twfe***
*3-Chaisemartin*
*REQUIRES: ssc install did_multiplegt - can include controls
foreach y in Private{
	

	did_multiplegt `y' statefips year expand , robust_dynamic cluster(statefips) dynamic(5) placebo(5) save_results(Chaise_`y') breps(999)
	
	graph save chaisemartin_`y'.gph, replace
	graph export chaisemartin_`y'.png, replace
}


*4-Callaway-Santanna (
*REQUIRES ssc install csdid, drdid - can include controls*
**CANNOT CLUSTER SE's in default / can implement wild bootstrap and cluster SEs with additional packages***

foreach y in Private{
	eststo: csdid `y' expand , ivar(statefips) time(year) gvar(first_tx) method(reg) agg(simple)
	estat pretrend
	estadd scalar ptt=r(pchi2)

foreach x in  calendar group event{
	csdid `y' expand , ivar(statefips) time(year) gvar(first_tx) method(reg) agg(`x')
	csdid_plot, scheme(tab2)
	graph save cs_`y'`x'.gph , replace
	graph export cs_`y'`x'.png , replace
			
		}
}



*5-Matrix Completion (requires ssc install did_imputation)
replace first_tx=. if first_tx==0
foreach y in Private{
eststo: did_imputation `y' statefips year first_tx , cluster(statefips) autosample pretrend(5)

}

