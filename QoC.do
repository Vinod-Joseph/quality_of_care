
/********************************************************************
 NFHs 4(2015–16) – QoC in sterilization services (public facilities)
 Paper: Quality of care in sterilization… (PLOS ONE, 2020)
*********************************************************************/

*---------------------------*
* 0) Housekeeping          *
*---------------------------*
clear all
set more off
version 17

*****************Sample Weight*************
gen wt= v005/1000000
la var wt "Sample Weight"
*******************************************

* Survey design (used for descriptives; NOT for melogit as per paper):
cap svyset v021 [pw=wt], strata(v022) singleunit(centered)


*-------------------------------------------*
* 1) Sample: sterilized women, public facility
*-------------------------------------------*

* Sterilized women
quietly tab v312 if !missing(v312)
keep if v312==6   // 6 = female sterilization

* Public facility (v326: place of sterilization)
/* v326 codes (NFHS‑4): 11=Govt/District/Municipal hospital; 12=Sub‑district/
   13=Govt medical college; 14=CHC; 15=PHC; 16=Sub‑center; 17=Camp; 18=Mobile
   19=Other public; 21+ private/NGO/missing.
*/
recode v326 ///
   (11/19 = 0 "public") ///
   (21/23 28 45 96 98 . = 1 "private/other"), gen(Facility_pub)
label var Facility_pub "Place of sterilization (public vs other)"
keep if Facility_pub==0

* District id (random effects level)
confirm variable sdistri
label var sdistri "District identifier (NFHS mapping)"


*-------------------------------------------*
* 2) Covariates
*-------------------------------------------*

* Residence
clonevar Residence = v025
label define RESI 1 "Urban" 2 "Rural"
label values Residence RESI
label var Residence "Place of residence"

* Religion
recode v130 (1=1 "Hindu") (2=2 "Muslim") (3=3 "Christian") (4/9=4 "Others"), gen(Religion)
label var Religion "Religion"

* Social group (India specific caste/tribe)
recode s116 (1=1 "Scheduled caste") (2=2 "Scheduled tribe") (3=3 "OBC") (4/max=4 "Others"), gen(Social)
label var Social "Caste/tribe"

* Wealth quintile
recode v190 (1=1 "Poorest") (2=2 "Poorer") (3=3 "Middle") (4=4 "Richer") (5=5 "Richest"), gen(Wealth)
label var Wealth "Wealth index (quintile)"

* Education
recode v106 (0=0 "No education") (1=1 "Primary") (2/3=2 "Secondary and above"), gen(Education)
label var Education "Education"

* Macro regions (check state codes for your round before use)
recode v024 ///
    (6 25 12/14 28 29 34 = 1 "North") ///
    (7 19 33               = 2 "Central") ///
    (5 15 26 35            = 3 "East") ///
    (3 4 21 22 23 24 30 32 = 4 "Northeast") ///
    (8 9 10 11 20          = 5 "West") ///
    (1 2 16 17 18 27 31 36 = 6 "South"), gen(Region)
label var Region "Macro region"

* Detailed public facility type
recode v326 (11 12 13 = 0 "GH/DH/MH") (14 = 1 "CHC") (15 16 = 2 "PHC/Sub‑centre") ///
               (17 18 19 = 3 "Camp/Mobile/Other public"), gen(Health_Facility)
label define HF 0 "GH/DH/MH" 1 "CHC" 2 "PHC/Sub‑centre" 3 "Camp/Mobile/Other"
label values Health_Facility HF
label var Health_Facility "Public facility type (NFHS‑4 codes)"

* Age at sterilization (derived robustly from dates)
* v317 = date of sterilization (CMC); v008 = interview date (CMC); v012 = age in years
capture drop age_at_steril
cap gen age_at_steril = floor(v012 - (v008 - v317)/12) if !missing(v317)
label var age_at_steril "Age at sterilization (years, derived)"

* Optional grouped version
cap drop Age_at_Sterilization
recode age_at_steril (min/24 = 1 "<25") (25/34 = 2 "25–34") (35/max = 3 "35–49"), gen(Age_at_Sterilization)
label var Age_at_Sterilization "Age at sterilization (groups)"


*-------------------------------------------*
* 3) Structure & Process (binary from scores)
*-------------------------------------------*

confirm variable Structure_Score
recode Structure_Score (min/0 = 0 "Low") (0/max = 1 "High"), gen(Structure)
label var Structure "Structure score (DLHS‑based) — High vs Low"

* If Process_Score already exists and you want a binary indicator as well:
cap confirm variable Process_Score
if _rc==0 {
    recode Process_Score (min/0 = 0 "Low") (0/max = 1 "High"), gen(Process)
    label var Process "Process score — High vs Low"
}


*-------------------------------------------*
* 4) QoC index (PCA) from five items (NFHS)
*-------------------------------------------*
/* Items:
   v3a01: told sterilization means no more children
   v3a02: told about side effects
   v3a04: told how to deal with side effects
   v3a05: told about other FP methods
   s334 : client rated care during/immediately after operation (higher is better)
*/

* Recode to 0/1 (1 indicates better information/experience)
recode v3a01 (0=0 "No") (nonmiss=1 "Yes"), gen(Inf_No_Children)
recode v3a02 (0=0 "No") (nonmiss=1 "Yes"), gen(Inf_Side_Effects)
recode v3a04 (0=0 "No") (nonmiss=1 "Yes"), gen(Inf_Deal_Side_Effects)
recode v3a05 (0=0 "No") (nonmiss=1 "Yes"), gen(Tld_other_FP)

* For s334, keep 1/2 = good/okay, 3/4 = bad (as per your original logic):
recode s334 (3/4 = 0 "Bad/All right no") (1/2 = 1 "Good/All right yes"), gen(Rate_Service)
label var Rate_Service "Rated care during/immediately after operation"

* PCA (listwise deletion on the five items)
local xlist Inf_No_Children Inf_Side_Effects Inf_Deal_Side_Effects Tld_other_FP Rate_Service
alpha `xlist'
pca   `xlist'
screeplot, yline(1)
rotate, varimax blanks(.30)
estat loadings
predict Quality_Score, score
label var Quality_Score "QoC index (1st PC score)"

* Binary QoC (cut at 0, as in paper): positive = High, negative = Low
recode Quality_Score (min/0 = 0 "Low") (0/max = 1 "High"), gen(Quality)
label var Quality "QoC (High vs Low)"

* For regression (Low=1), create Quality_Low
recode Quality (0=1 "Low") (1=0 "High"), gen(Quality_Low)
label var Quality_Low "QoC low (1) vs high (0)"


*-------------------------------------------*
* 5) Descriptives (weighted, surveyaware)
*-------------------------------------------*
svy: tab Quality Residence, col
svy: tab Quality Religion,  col
svy: tab Quality Social,    col
svy: tab Quality Wealth,    col
svy: tab Quality Education, col
svy: tab Quality Region,    col
svy: tab Quality Health_Facility, col


*-------------------------------------------*
* 6) Multilevel mixed effects logistic models
*    (district random intercept; unweighted)
*-------------------------------------------*

* References: Others (Social), Richest (Wealth), South (Region), GH/DH/MH (facility), High (Structure)
melogit Quality_Low || sdistri:, or
estat icc
estat ic

melogit Quality_Low ///
    i.Residence i.Religion ib(4).Social ib(5).Wealth i.Education ib(6).Region ///
  || sdistri:, or
estat icc
estat ic

melogit Quality_Low ///
    i.Health_Facility ib(1).Structure ///
  || sdistri:, or
estat icc
estat ic

melogit Quality_Low ///
    i.Residence i.Religion ib(4).Social ib(5).Wealth i.Education ib(6).Region ///
    i.Health_Facility ib(1).Structure ///
  || sdistri:, or
estat icc
estat ic


*-------------------------------------------*
* 7) Optional: regionwise summaries
*-------------------------------------------*
levelsof Region, local(rlevels)
foreach r of local rlevels {
    di as txt "Region == `r'"
    quietly tabulate sdistri if Region==`r', summarize(Quality_Score) nolabel
}


*-------------------------------------------*
* 8) Save key outputs
*-------------------------------------------*
cap mkdir results
cap mkdir results/logs
cap mkdir results/tables

save "results/nfhs4_qoc_public_clean.dta", replace
log close _all


