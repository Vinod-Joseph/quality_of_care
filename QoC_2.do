# PCA module — Structure & Process (clean Stata)


/********************************************************************
 PCA for QoC indices
 Blocks: S1–S32 (Structure) and P1–P24 (Process)
 Requires: State, District_New present
*********************************************************************/

version 17
set more off

/* --------------------------
   -------------------------- */
cap confirm variable State
cap confirm variable District_New
if _rc {
    di as err "State and/or District_New variables are missing."
    exit 198
}

/* List your item blocks */
global xlist  S1 S2 S3 S4 S5 S6 S7 S8 S9 S10 S11 S12 S13 S14 ///
              S15 S16 S17 S18 S19 S20 S21 S22 S23 S24 S25 S26 S27 S28 S29 S30 S31 S32

global xlist1 P1 P2 P3 P4 P5 P6 P7 P8 P9 P10 P11 P12 ///
              P13 P14 P15 P16 P17 P18 P19 P20 P21 P22 P23 P24

/* --------------------------
   1) Inspect & standardize
   -------------------------- */
noi describe $xlist
noi summarize $xlist
noi misstable summarize $xlist

noi describe $xlist1
noi summarize $xlist1
noi misstable summarize $xlist1

/* If items are on mixed scales, z‑standardize before PCA */
foreach v of global xlist {
    cap confirm variable z_`v'
    if _rc==0 drop z_`v'
    egen z_`v' = std(`v') if !missing(`v')
}
foreach v of global xlist1 {
    cap confirm variable z_`v'
    if _rc==0 drop z_`v'
    egen z_`v' = std(`v') if !missing(`v')
}

/* Create standardized blocks */
local zS : subinstr global xlist  "S" "z_S", all
local zP : subinstr global xlist1 "P" "z_P", all

/* --------------------------
   2) PCA — Structure block
   -------------------------- */
qui alpha $xlist
estimates store alpha_S

pca `zS'
screeplot, yline(1)
rotate, varimax blanks(.30)
estat loadings
predict pcS1, score   // first principal component
label var pcS1 "Structure score (PC1, z‑items)"

/* Diagnostics */
estat kmo
loadingplot
scoreplot

/* --------------------------
   3) PCA — Process block
   -------------------------- */
qui alpha $xlist1
estimates store alpha_P

pca `zP'
screeplot, yline(1)
rotate, varimax blanks(.30)
estat loadings
predict pcP1, score   // first principal component
label var pcP1 "Process score (PC1, z‑items)"

estat kmo
loadingplot
scoreplot

/* --------------------------
   4) Summaries by State/District
   -------------------------- */
levelsof State, local(states)
foreach s of local states {
    noi di as txt "State == `s'"
    quietly tabulate District_New if State==`s', summarize(pcS1) means nolabel
    quietly tabulate District_New if State==`s', summarize(pcP1) means nolabel
}

/* --------------------------
   5) Binary High/Low flags at 0 cut point (optional)
   -------------------------- */
recode pcS1 (min/0 = 0 "Low") (0/max = 1 "High"), gen(Structure)
recode pcP1 (min/0 = 0 "Low") (0/max = 1 "High"), gen(Process)
label var Structure "Structure: High(1)/Low(0), cut at 0"
label var Process   "Process: High(1)/Low(0), cut at 0"

/* --------------------------
   6) Save outputs
   -------------------------- */
cap mkdir results
cap mkdir results/tables
cap mkdir results/figures

save "results/qoc_pca_scores.dta", replace


