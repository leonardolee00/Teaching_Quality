*! version 1.1 Soledad Giardili 05Mar2015

  capture program drop kfwebs
  program kfwebs, rclass
	  version 11.2
	  syntax anything(id = "equation(s)" name=eqlist equalok) [if] [in] , ///
	  TESTvar(varlist numeric)           ///
	  Kvalues(numlist min=1 integer)     ///
	  alphas(numlist min=1)              ///
	  [hypadd(string)                    ///
	  method(string)                     ///
	  nmax(integer 50)                   ///
	  Reps(integer 1)                    ///
	  seed(string)                       ///
	  STRata(varlist)                    ///
	  CLuster(varlist)                   ///
	  Weight(varname)                    ///
	  save(string)                       ///
	  ]

          tempname betas critval results
	  tempvar  maux saux Ksettag Ksetval cval c_aux rejected rej rvar

         /*Identify sample*/
	  marksample touse
	  quietly count if `touse'
	  if `r(N)' == 0 {
	      error 2000
	  }

         /*Identify equations and depvars*/
	  tokenize `"`eqlist'"', parse("()")
          local depvars
          local i 0
          while "`*'" != "" {
	    if "`1'"!="" & "`1'"!=")" & "`1'"!="(" {
	      loc ++i
	      local eq`i' "`1'"
	      fvrevar `eq`i'', list
		  foreach var in `r(varlist)' {
	              confirm variable `var'
	          }
	      local dep`i': word 1 of `eq`i''
	      local depvars `depvars' `dep`i''
	      }
	  macro shift
	  }

         /*method*/
	  if "`method'" == "" {
	      local method "studentized"
	  }
	  quietly if "`method'" != "" {
	      local i : word count `method'
	      if ( `i' > 1 ) {
                  di in r "cannot specify more that one method: `method'"
		  exit 198
	      }
	      gen     `maux' = 0
	      replace `maux' = 1 if strpos("`method'", "basic")
	      replace `maux' = 1 if strpos("`method'", "studentized")
	      sum `maux'
	      if r(mean)!=1 {
	          di in r "method should be basic or studentized"
		  exit 198
		  }
	  }

         /*alphas*/
	  local i 1
	  tokenize `alphas'
	  while "`1'"~="" {
	  if `1'>=1 {
              local alpha`i' = `1'/100
              if `alpha`i''>=1 {
	          di in red "alpha out of range"
		  exit 198
	      }
	      }
	      else {
                  local alpha`i' = `1'
	      }
	      local ++i
	      macro shift
	      }
           local nalpha: word count `alphas'                 /*number of alphas specified*/

         /*Control for # of repetitions (minimum 1)*/
          if (`reps'<1) {
	      di as error "nrep() out of range"
	      error 198
          }

         /*Identify othervars in each equation, different from testvars*/
          local ndep: word count `depvars'
          local neq: word count `depvars'
          forvalues i = 1/`neq' {
	      tokenize `eq`i''
	      macro shift 1
	      local othervar`i' "`*'"
	          foreach var of local testvar {
	              local aux`i': subinstr local othervar`i' "`var'" ""
	              local othervar`i' `aux`i''
	          }
		  local aux`i' ""
          }

         /*Identify additional hypothesis, save number of additional hypothesis added in nhypadd*/
          tokenize "${_hypadd}", parse(";")
          local i 1
          while "`*'" != "" {
              if "`1'"!=";" {
	          local hypadd`i' "`1'"
	          local nhypadd = `i'
	          loc ++i
	      }
	      macro shift
	  }

         /*Number of hypothesis*/
	  local ntest: word count `testvar'
	  local nhyp = (`ndep'*`ntest')
          if length(`"`hypadd'"') > 0 {
              local nhyp = (`ndep'*`ntest')+(`ndep'*`nhypadd')  /*number of hypothesis*/
          }

         /*kvalues*/
	  local i 1
	  tokenize `kvalues'
	  while "`1'"~="" {
		local k`i' = `1'
		  if (`1'>`nhyp'|`1'<1) {
		      di as error "kvalue() out of range"
		      error 198
		  }
	      local ++i
	      macro shift
	  }
          local nkval: word count `kvalues'                 /*number of k specified*/

	 /*set the seed*/
	  if "`seed'" != "" {
	      set seed `seed'
	  }
	  *local seed `c(seed)'

         /*cluster */
          if "`cluster'" != "" {
	      confirm variable `cluster'
	      local options ", cluster(`cluster')"
	  }

         /*strata */
          if "`strata'" != "" {
	      confirm variable `strata'
	  }

         /*Hypothesis names*/
	  local hypname ""
	  foreach y of local depvars {
	      foreach x of local testvar {
	          local hypname `hypname' `y'_`x'                                /*more than 32 character of length*/
	      }
	      if length(`"`hypadd'"') > 0 {
		  forvalues h=1/`nhypadd' {
		      local hypname `hypname' `y'_`hypadd`h''
		  }
	      }
	  }

         /*Identify path to save bootstrat results*/
          if length(`"`save'"') > 0 {
	      _getfilename `"`save'"'
	      local filename = r(filename)
	      local path     = reverse(subinstr(reverse(`"`save'"'),reverse(`"`filename'"'),"",1))
	          if strpos(`"`filename'"',".") > 0 {
	              di as err `"name datafile may not contain extension:"'
	              error 198
	          }
          }


// Original Regression(s) -----------------------------------------------------

          mat `betas'   = J(`nhyp',7,.)

	  local i 1
	  local rname ""
	  quietly forvalues n=1/`neq' {
	      xi: reg `dep`n'' `testvar' `othervar`n'' if `touse' `options'
	      foreach x of varlist `testvar' {
		  local beta`i' = _b["`x'"]                                        /*save betas to center bootstrap test below*/
	          mat `betas'[`i',1] = 0                                           /*iter = 0 indicating non bootstrap hypotheses*/
		  mat `betas'[`i',2] = `i'
		  mat `betas'[`i',3] = _b["`x'"]
		  mat `betas'[`i',4] = _se["`x'"]
		  local t = _b["`x'"]/_se["`x'"]
		  mat `betas'[`i',5] = `t'
		  local pvalue = 2*ttail(e(df_r),abs(`t'))
		  mat `betas'[`i',6] = `pvalue'
		  local pvalue`i' = `pvalue'                                       /*save in local for display*/

		  if "`method'"=="basic" {
		      local tstat   = abs(_b["`x'"])
		      }
		  if "`method'"=="studentized" {
		      local tstat   = abs(_b["`x'"]/_se["`x'"])
		      }

		  mat `betas'[`i',7] = `tstat'
		  local rname `rname' h`i'
		  local ++i  
	      }

	      if length(`"`hypadd'"') > 0 {
		forvalues h=1/`nhypadd' {
		    lincom `hypadd`h''
		    local beta`i' = `r(estimate)'                                  /*save betas to center bootstrap test below*/
		    mat `betas'[`i',1] = 0                                         /*iter = 0 indicating non bootstrap hypotheses*/
		    mat `betas'[`i',2] = `i'
		    mat `betas'[`i',3] = `r(estimate)'
		    mat `betas'[`i',4] = `r(se)'
                    local t = `r(estimate)'/`r(se)'
		    mat `betas'[`i',5] = `t'
		    local pvalue = 2*ttail(e(df_r),abs(`t'))
		    mat `betas'[`i',6] = `pvalue'
		    local pvalue`i' = `pvalue'                                     /*save in local for display*/

		    if "`method'"=="basic" {
			local tstat   = abs(`r(estimate)')
			}
		    if "`method'"=="studentized" {
			local tstat   = abs(`r(estimate)'/`r(se)')
			}

                    mat `betas'[`i',7] = `tstat'
		    local rname `rname' h`i'
		    local ++i
		  }
	      }

	  }

         /*Converting matrix to variables and save file where to add bootstrap test statistics*/
          mat rownames `betas' = `rname'
          mat colnames `betas' = iter order betas se t pvalue tstat
	  tempfile hypotheses0
	  quietly {
	      preserve
	      svmat2 `betas', rnames(hyp) names(col)
	      order hyp, before(betas)
	      gen hypname = ""
	      forvalues n=1/`nhyp' {
		  local aux: word `n' of `hypname'
		  replace hypname = "`aux'" if _n==`n'
	      }
	      order hypname, after(hyp)
	      keep iter-tstat
	      keep if tstat!=.

	      /*Step 1 of algorithm: Relabel hypotheses in descending order of the test statistics*/
	      set sortseed `seed'
	      gsort -tstat
	      gen rank = _n if tstat!=.

	      forvalues n=1/`nhyp' {
		  sum rank if order==`n'
		  local rank`n' = r(mean)
	      }

	      save `hypotheses0', replace
	      restore
	  }


// Bootstrapping --------------------------------------------------------------

	 /*Code to display on results window */
	  display in ye _newline(2) "Resampling: (% of `reps' reps)"  _newline(1) "[0%--------------------------50%---------------------------100%]"
	 /*generate percentiles of steps*/
		forvalues j=0(10)100 {
		   loc per`j'=round((`j'/100)*`reps')
		   }

         /*Appendix A.1-A.4 - Bootstrapping: computing individual test statistics
	  Computing tstat: null-value shifted distibution of the test statistic: 
	  equivalent to inverting bootstrap multiple confidence regions (p.412)*/
	  
	  quietly forvalues iter=1/`reps' {
	      preserve
	      local rand_seed = `seed'+`iter'
	      set seed `rand_seed'
	      bsample, strata(`strata') cluster(`cluster') weight(`weight') 
         
	     /*Bootstrap Regression(s)*/
	      mat `betas'   = J(`nhyp',7,.)
	      local i 1
	      local rname ""
	      forvalues n=1/`neq' {
		  xi: reg `dep`n'' `testvar' `othervar`n'' if `touse' `options'
		  foreach x of varlist `testvar' {
		      mat `betas'[`i',1] = `iter'                                  /*iter number for bootstrap*/
		      mat `betas'[`i',2] = `i'
		      mat `betas'[`i',3] = _b["`x'"]
		      mat `betas'[`i',4] = _se["`x'"]
		      local t = _b["`x'"]/_se["`x'"]
		      mat `betas'[`i',5] = `t'
		      local pvalue = 2*ttail(e(df_r),abs(`t'))
		      mat `betas'[`i',6] = `pvalue'

		      if "`method'"=="basic" {
			  local tstat   = abs(_b["`x'"]-`beta`i'')
			  }
		      if "`method'"=="studentized" {
			  local tstat   = abs(_b["`x'"]-`beta`i'')/_se["`x'"]
			  }

		      mat `betas'[`i',7] = `tstat'
		      local rname `rname' h`i'
		      local ++i  
		  }

		  if length(`"`hypadd'"') > 0 {
		    forvalues h=1/`nhypadd' {
			lincom `hypadd`h''
			mat `betas'[`i',1] = `iter'
			mat `betas'[`i',2] = `i'
			mat `betas'[`i',3] = `r(estimate)'
			mat `betas'[`i',4] = `r(se)'
			local t = `r(estimate)'/`r(se)'
			mat `betas'[`i',5] = `t'
			local pvalue = 2*ttail(e(df_r),abs(`t'))

			if "`method'"=="basic" {
			    local tstat   = abs(`r(estimate)'-`beta`i'')
			    }
			if "`method'"=="studentized" {
			    local tstat   = abs(`r(estimate)'-`beta`i'')/`r(se)'
			    }

			mat `betas'[`i',7] = `tstat'
			local rname `rname' h`i'
			local ++i
		      }
		  }
	      }

	     /*Converting matrix to variables and save file where to add bootstrap results*/
	      mat rownames `betas' = `rname'
	      mat colnames `betas' = iter order betas se t pvalue tstat
	      tempfile hypotheses`iter'
	      svmat2 `betas', rnames(hyp) names(col)
	      order hyp, before(betas)
	      gen hypname = ""
	      forvalues n=1/`nhyp' {
		  local aux: word `n' of `hypname'
		  replace hypname = "`aux'" if _n==`n'
	      }
	      order hypname, after(hyp)
	      keep iter-tstat
	      keep if tstat!=.
	      save `hypotheses`iter'', replace

	     /*More code for the display of the results*/
	      if `iter'==1 {
		  noisily di in gre _col(-1) _continue "["
	      }
	      if `iter'==`per10' | `iter'==`per20' | `iter'==`per30' | `iter'==`per40' |    ///
		 `iter'==`per50' | `iter'==`per60' | `iter'==`per70' | `iter'==`per80' |    ///
		 `iter'==`per90' | `iter'==`per100'  {
		   noisily di in gre _continue "     ."
	      }
	      if `iter'==`per100' {
		  noisily di in gre _continue "  ]" 
	      }

	      restore
	  }                                                                        /*end of resampling loop*/

         /*Append tempfiles*/
	  quietly {
	  
	  preserve

	  use "`hypotheses0'", clear
	  forvalues n=1/`reps' {
	      append using "`hypotheses`n''"
	  }
	  
	  /*Imposing ranking*/
	   bys order: egen aux=min(rank)
	   replace rank=aux if rank==.
	   drop aux
	   sort iter rank

          /*Saving bootstrap results*/
	   quietly if "`save'"!="" {
               save "`path'\`filename'.dta", replace
	   }
	   }


// Loop over alpha and k values -----------------------------------------------

	 /*Loop over alphas*/
	  forvalues aa=1/`nalpha' {
	      local level = 100*(1-`alpha`aa'')

	     /*Loop over kvalues*/
	      forvalues k=1/`nkval' {

		  local S = `nhyp'                                                 /*Total # of hypotheses*/
		  local NR = 0                                                     /*# of hypothesis rejected at (t-1)*/
		  local j 0
		  local Rj = 10000000                                              /*Some big number to start the while loop*/
		  mat `critval' = J(1,`S',.)                                       /*storing critical values*/

// Critical Values ------------------------------------------------------------

		/*Loop while Rj>=k & and `NR'!=`Rj'. Stop when no extra hypothesis is rejected
		  NOTE: if R1<k stop because plausible that all rejected hypothesis are true. If R1>=k 
		  compute a smaller joint regions in subsequent steps*/

		  quietly while (`Rj'>=`k`k'') & (`NR'!=`Rj') & (`Rj'!=`S') {

		      local j = `j' + 1

		    /*Algorithm Second step. Only for j=1 */
		      if `j'==1 {
			  local Kset = `S'                                         /*Determine set over which to find kmax-values*/
			  local kmaxind = `Kset'-`k`k''+1                          /*Location of the kmax value*/

			  gen `Ksettag' = 1 if iter!=0
			  sort iter `Ksettag' tstat
			  by iter: gen `Ksetval' = tstat if _n==`kmaxind' & `Ksettag'==1

			/*Computing the smallest (1-alpha) quantile of the sampling distribution*/
			  egen `cval'`j' = pctile(`Ksetval'), p(`level')

			/*Rejections*/
			  gen `rejected' = (tstat>`cval'`j') if iter==0
			  local NR = `Rj'
			  
			  count if `rejected'==1
			  local Rj   = r(N)                                        /*This is going to accumulated rejections across j iterations*/
			  local R`j' = r(N)                                        /*Number of rejection in j=1*/
			  gen `rej'`j' = (tstat>`cval'`j') if iter==0              /*=1 if rejected in j*/

			  drop `Ksetval' `Ksettag'
		      }


		      if `j'>1 {

		    /*Number of combinations need to compute each Ck,|.| if k>1. See eq.13 or 15. */
		      local jj = `j'-1
		      local ncomb = comb(`Rj',`k`k''-1)

		    /*Operative method (See remark 4.1): Computational shortcut implemented when ncomb is large
		      User define number Nmax*/
		      local kminus = `k`k''-1
		      if `ncomb'<=`nmax' {
			  local Nstar = `Rj'
			  local rankmin = 1
			  local rankmax = `R`jj''
		      }
	    
		      else {
			  local Nstar_aux = `Rj'
			  while comb(`Nstar_aux',`kminus')>`nmax' {
			      local Nstar_aux = `Nstar_aux' - 1
			  }
			  local Nstar = `Nstar_aux'
			  local rankmin = `Rj'-`Nstar'+1
			  local rankmax = `Rj'
		      }

		    /*Kset and kmax value index*/
		      local Kset    = `S'-`Rj'+(`k`k''-1)       /*Union {R_(j-1)+1,...,S} and (k-1). Determine set over which to find kmax values*/
		      local kmaxind = `Kset'-`k`k''+1           /*Location of the kmax value*/

		    /*Compute critical value according to k, Kset, kmaxind and ncomb*/

		      if `k`k''==1 {
			    gen `Ksettag' = 1 if iter!=0 & rank>`Rj'
			    sort iter `Ksettag' tstat
			    by iter: gen `Ksetval' = tstat if _n==`kmaxind' & `Ksettag'==1
			    egen `cval'`j' = pctile(`Ksetval'), p(`level')
			    drop `Ksettag' `Ksetval'
		      }

		      if `k`k''==2 {
			  levelsof rank if `rejected'==1 & (rank>=`rankmin' & rank<=`rankmax'), local(hrej)
			  foreach i of local hrej {
			      gen `Ksettag' = 1 if iter!=0 & (rank==`i' | rank>`Rj')
			      sort iter `Ksettag' tstat
			      by iter: gen `Ksetval' = tstat if _n==`kmaxind' & `Ksettag'==1
			      egen `c_aux'_`i' = pctile(`Ksetval'), p(`level')
			      drop `Ksettag' `Ksetval'
			  }
			  egen `cval'`j'=rowmax(`c_aux'_`rankmin'-`c_aux'_`rankmax')
			  cap drop `c_aux'_*
		      }

		      if `k`k''>=3 {
			  gen `rvar' = rank if `rejected'==1 & (rank>=`rankmin' & rank<=`rankmax')

			  kcomb `rvar' `kminus'                           //subroutine for combination

			  local row = rowsof(combval)
			  local col = colsof(combval)
			  forvalues r = 1/`row' {
			      local a = combval[`r',1]
			      local d "rank==`a'"
				  forvalues c = 2/`col' {
				      local a = combval[`r',`c']
				      local d "`d' | rank==`a'"
				      if `c' ==`col' { 
					  gen `Ksettag' = 1 if iter!=0 & (`d' | rank>`Rj')
					  sort iter `Ksettag' tstat
					  by iter: gen `Ksetval' = tstat if _n==`kmaxind' & `Ksettag'==1
					  egen `c_aux'_`r' = pctile(`Ksetval'), p(`level')
					  drop `Ksettag' `Ksetval'
				      }
				  }
			      }
			  egen `cval'`j'=rowmax(`c_aux'_1-`c_aux'_`row')
			  cap drop `c_aux'_*
			  cap drop `rvar'
		      }

		    /*Rejections*/
		      replace `rejected' = (tstat>`cval'`j') if iter==0 & `rejected'==0
		      gen `rej'`j' = (tstat>`cval'`j') if iter==0 & rank>`Rj'    /*=1 if rejected in j*/

		      local NR = `Rj'
		      count if `rejected'==1
		      local Rj = r(N)
		      local R`j' = (`Rj'-`NR')                            /*Number of rejection in j*/

		      }
		      *close j>1 loop

		      sum `cval'`j'                                       /*Storing critical values*/
		      mat `critval'[1,`j'] = r(mean)
		      local maxj = `j'

		      drop `cval'`j' `rej'`j'

		  }
		  * close while loop


// Display --------------------------------------------------------------------

	    /*This is the result table displayed after running the program*/
	     noisily {
	      di " "
	      di " "
	      di " "
	      di as text "Number of hypotheses = " as result `nhyp' _col(55) as text "alpha = " as result `alpha`aa''
	      di as text "Number of Reps       = " as result `reps' _col(55) as text "k     = " as result `k`k''
	      di as text "{hline 65}"
	      di as text " Hypothesis" _col(27) "betas" _col(36) "p-values" _col(47) "ranking" _col(57) "rejected"
	      di as text "{hline 65}"

	      local i = 1
	      foreach var of local depvars  {
		  di as text _col(2) "`var'"
		  foreach x of local testvar {
		      qui sum `rejected' if order==`i' & iter==0
		      local r`i'=r(mean)
		      di as text _col(3) " " abbrev("`x'",20) as result _col(24) %9.0g `beta`i'' as result _col(34) %9.4f `pvalue`i'' as result _col(42) %9.0f `rank`i'' as result _col(53) %9.0f `r`i''
		      local ++i 
		  }
		  if length(`"`hypadd'"') > 0 {
		  forvalues h=1/`nhypadd' {
		      qui sum `rejected' if order==`i' & iter==0
		      local r`i'=r(mean)
		      di as text _col(3) " " abbrev("`hypadd`h''",20) as result _col(24) %9.0g `beta`i'' as result _col(34) %9.4f `pvalue`i'' as result _col(42) %9.0f `rank`i'' as result _col(53) %9.0f `r`i''
		      local ++i 
		  }
		  }
	      }
	      di as text "{hline 65}"
	      di as text "H0: beta = 0"
	      }


// Store results and critical values  -----------------------------------------

	     /*Store critical values */
	      mat `critval'_k`k`k''_a`aa' = `critval'[1..1, 1..`maxj']
	      return matrix critval_k`k`k''_a`aa' = `critval'_k`k`k''_a`aa'

	     /*Store results */
	      local rownames
	      mat `results' = J(`nhyp',4,.)
	      local i = 1
	      foreach y of local depvars  {
		  foreach x of local testvar {
		      if (c(linesize) <= 80) local name = abbrev("`y'_`x'",12)
		      else local name = abbrev("`y'_`x'",32)
		      local rownames `rownames' `name'
		      mat `results'[`i',1] = `beta`i''
		      mat `results'[`i',2] = `pvalue`i''
		      mat `results'[`i',3] = `rank`i''
		      mat `results'[`i',4] = `r`i''
		      local ++i 
		  }
		  if length(`"`hypadd'"') > 0 {
		  forvalues h=1/`nhypadd' {
		      if (c(linesize) <= 80) local name = abbrev("`y'_`x'",12)
		      else local name = abbrev("`y'_`x'",32)
		      local rownames `rownames' `name'
		      mat `results'[`i',1] = `beta`i''
		      mat `results'[`i',2] = `pvalue`i''
		      mat `results'[`i',3] = `rank`i''
		      mat `results'[`i',4] = `r`i''
		      local ++i 
		  }
		  }
	      }

	      mat `results'_k`k`k''_a`aa' = `results'
	      mat colnames `results'_k`k`k''_a`aa' = beta pvalue ranking reject
	      mat rownames `results'_k`k`k''_a`aa' = `rownames'

	      return matrix res_k`k`k''_a`aa' = `results'_k`k`k''_a`aa'

// End of alpha k values loops  -----------------------------------------------

		  drop `rejected' 
	      }
	      * close k loop
	  }
	  * close alpha loop

	  restore
end 


// Auxiliary program ---------------------------------------------------------

/*subroutine to identify all possible combinations of drawing (k-1) indices 
  without replacement out of {1,...,R_(j-1)}. The total number of combination 
  must be n!/((n?k)! k! store in ncomb*/

  capture program drop kcomb
  program define kcomb
  args varname nc
      preserve
      keep if `varname'!=.

	if `nc'<2 {
	    di in re "nc() out of range"
	    exit 198
	    }

      local vlist ""
      forvalues n=1(1)`nc' {
	  gen `varname'_`n' = `varname'
	  local vlist `vlist' `varname'_`n'
      }

      qui fillin `varname'_*
      drop if _fillin==0
      drop _fillin

      tokenize `vlist'
      local ncminus =  `nc'-1
      local todrop2 "`1'>=`2'"
      forvalues n=2(1)`ncminus' {
	  local nn= `n'+1
	  local todrop "`varname'_`n'>=`varname'_`nn'"
	  local todrop2 "`todrop2' | `todrop'"
      }

      capture drop if `todrop2'
      mkmat `vlist', matrix(combval)

      restore
  end
