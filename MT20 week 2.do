*** Coefficient stability plots ***

/*
Data can be downloaded from "Global Behaviors and Perceptions in the COVID-19 Pandemic" available at:

https://osf.io/3sn2k/

You need to download the following two files and copy them in the folder with the do-file:
GlobalBehaviorsPerceptions_Data_May21_2020.dta,
OxCGRT_latest_100520.dta

You can install speccurve using 
net install speccurve, from("https://raw.githubusercontent.com/martin-andresen/speccurve/master")

*/


use "GlobalBehaviorsPerceptions_Data_May21_2020.dta" , clear // 

*** Cleaning from the original paper (not relevant to specification curve command) ***
{
*** Recode country names for merging ***
replace CountryofLiving="United Kingdom" if CountryofLiving=="United Kingdom of Great Britain and Northern Ireland"
replace CountryofLiving="Russia" if CountryofLiving=="Russian Federation"
replace CountryofLiving="Iran" if CountryofLiving=="Iran, Islamic Republic of..."
replace CountryofLiving="Venezuela" if CountryofLiving=="Venezuela, Bolivarian Republic of..."
replace CountryofLiving="Macedonia" if CountryofLiving=="The former Yugoslav Republic of Macedonia"
replace CountryofLiving="Laos" if CountryofLiving=="Lao People's Democratic Republic"
replace CountryofLiving="Czechia" if CountryofLiving=="Czech Republic"
replace CountryofLiving="Vietnam" if CountryofLiving=="Viet Nam"


*Keep dates before April 7th
drop if date>mdy(4,7,2020)

* Drop countries with less than 200 observations
bysort country: gen num=_N
drop if num<200



*** Generate outcome
gen insuff_perceivedreaction = perceivedreaction>3 if perceivedreaction!=.
label variable insuff_perceivedreaction "Government reaction insufficient"

label var educ_bin "Education bracket"

*Code big5 personality items
recode personality_b5_2 personality_b5_4 personality_b5_6 personality_b5_8 personality_b5_10 (7=1) (6=2) (5=3) (4=4) (3=5) (2=6) (1=7)

gen pers_extra=(personality_b5_1+personality_b5_6)/2
gen pers_agree=(personality_b5_2+personality_b5_7)/2
gen pers_consc=(personality_b5_3+personality_b5_8)/2
gen pers_emost=(personality_b5_4+personality_b5_9)/2
gen pers_opnex=(personality_b5_5+personality_b5_10)/2

lab var pers_extra "Extraversion"
lab var pers_agree "Agreeableness"
lab var pers_consc "Conscientiousness"
lab var pers_emost "Emotional stability" // Reversed neuroticism
lab var pers_opnex "Openness to experiences"


* Merge in new data on gov't restrictions over time

merge m:1 iso2c date using "OxCGRT_latest_100520.dta"
keep if _merge==1 | _merge==3 
drop _merge


gen lockdown=(c6_stayathomerequirements>0)
label var lockdown "Lockdown (stay at home)"

*** Generate relative case data ***

gen covid_confirmed_pc = (covid_confirmed +1)/(sppoptotl /1000)
gen dchcovid_confirmed_pc = (covid_confirmed-l1covid_confirmed +1)/(sppoptotl /1000)
gen covid_deaths_pc = (covid_death +1) /(sppoptotl /1000)
gen dchcovid_deaths_pc = (covid_death-l1covid_death  +1) /(sppoptotl /1000)

foreach var in covid_confirmed_pc dchcovid_confirmed_pc covid_deaths_pc dchcovid_deaths_pc {
local lab: variable label `var'
egen mean`var' = mean(`var'), by(iso2c date)

label variable mean`var' "`lab'"
}

** Normalize control variables facilitate the interpretation of treatment effects **
center age educ_bin pers_extra pers_agree pers_consc pers_emost pers_opnex health meandchcovid_confirmed_pc meandchcovid_deaths_pc meancovid_deaths_pc, inplace standardize addtolabel("")

}



** Clear estimates **
estimates clear
eststo clear

*** Save regression results ***

foreach yvar in  insuff_perceivedreaction { // Dependent variables (one per graph, add more if needed)





	tokenize age educ_bin pers_extra pers_agree pers_consc pers_emost pers_opnex // Saves variable names in locals name 1 2 3 etc.

	loc no=0 //Specification number counter
	forvalues age=0/1 {
			forvalues educ_bin=0/1 {
				forvalues pers_extra=0/1 {
					forvalues pers_agree=0/1 {
						forvalues pers_consc=0/1 {
							forvalues pers_emost=0/1 {
								forvalues pers_opnex=0/1 {
									
** Create local with string of control variable names in specific specification **
									loc controls
									forvalues i=1/7 {
										if ```i'''==1 loc controls `controls' ``i'' // Add variable name created by tokensize.
									}
	
											loc ++no // count through specification numbers	
											reghdfe `yvar' lockdown `controls' gender health meandchcovid_confirmed_pc meandchcovid_deaths_pc meancovid_deaths_pc [aw=weight]	, absorb(iso2c date)  vce(cl iso2c) noconstant
											
											estadd scalar no=`no'
											estadd scalar countryfe=1
											estadd scalar datefe=1
											estadd scalar coviddaycountry=1
											estadd scalar gender=1
											estadd scalar health=1
											loc numc: word count `controls'
											estadd scalar numcontrols=`numc'
											eststo ols`no' // save specification with unique numbers
											
	
							}
						}
					}
				}
			}
		}
	}




speccurve , param(lockdown) controls(title(control variables)) main(ols97) panel(countryfe datefe) level(95) 

}
