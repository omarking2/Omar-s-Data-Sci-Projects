PROC IMPORT OUT=WORK.HMK_6120_2 /*name of sas filename*/
            DATAFILE= "C:\Users\king.2615\Downloads\HMK_6120_2.xlsx" /*name of original file imported*/
            DBMS=XLSX REPLACE;
     GETNAMES=YES;
RUN;
data fdic_data; set HMK_6120_2; *creating a new dataset called fdic_data from the imported dataset;
run;

/******************************************************************************
*  Here, we create one version of actual consumption data and append all the two scenario forecasts to 
* these actual. 
******************************************************************************/


*get actual data;
data work.actualfdic;
	set work.fdic_data ;
		where scenario = "actuals"; *keeping only actual fdic data;
run;
*create macros for each type;
%macro forecast_data(scen);

data work.&scen;
merge work.actualfdic
	  work.fdic_data(where=(scenario="&scen"));
by date_q scenario;

run;

%mend forecast_data;

%forecast_data(fbase);
%forecast_data(fadvr);
%forecast_data(fsevr);

proc contents data=work.actualfdic  
out=work.varsfdic(keep= varnum name)
noprint;
run;
*create macro of all available var names to be transformed, exclude vars we don't want to transform;
proc sql noprint;
select 
	distinct name into:vars separated by ' '
from work.varsfdic
	where name not like '_'
	and name not like 'date'
	and name not like 'scenario'
	and name not like 'VAR18'
    and name not like 'date_q';
quit;


*create a list of  all variables to be transformed;
%let all_vars = &vars;
%macro transform(number_of_lags,data_set);

data work.&data_set;
set work.&data_set;

 %let k = 0;
	%do %while(%scan(&all_vars, (&k + 1)) ne  ); * scanning list of variables, stop when the list is empty;
		%let variable = %scan(&all_vars, (&k + 1));  * transforming one variable at a time, variable k+1;

		*create lags;
			%do m = 1 %to &number_of_lags; 
				&variable._a&m = lag&m(&variable);

			*perform 1-qtr percent change transformation and lags;
				&variable._p1 = (&variable / lag(&variable)) - 1;
				&variable._p1a&m = lag&m(&variable._p1);

			*create 2-qtr percent change transformation;
				&variable._p2 = (&variable / lag2(&variable)) - 1;
				&variable._p2a&m = lag&m(&variable._p2);

			*create 4-qtr percent change transformation;
				&variable._p4 = (&variable / lag4(&variable)) - 1;
				&variable._p4a&m = lag&m(&variable._p4);

			*create 1-qtr difference transformation;
				&variable._d1 = dif(&variable);
				&variable._d1a&m = lag&m(&variable._d1);

			*create 2-qtr difference transformation;
				&variable._d2 = dif2(&variable);
				&variable._d2a&m = lag&m(&variable._d2);

			*create 4-qtr difference transformation;
				&variable._d4 = dif4(&variable);
				&variable._d4a&m = lag&m(&variable._d4);

			*create natural log transformation;
				&variable._o = log(&variable);
				&variable._oa&m = lag&m(&variable._o);

			*create 1-qtr difference and lags of 1-qtr difference of natural log;
				&variable._od1 = dif(&variable._o);
				&variable._od1a&m = lag&m(&variable._od1);
			%end;
		%let k = &k + 1; 
	%end;

run;

%mend transform; *end of the macro;

*calling "transform" macro to obtain the tranformed data;

%transform(4,fbase); 
%transform(4,fadvr);
%transform(4,fsevr);
run;

*create one table with the three growth scenarios for easy reference; *creating a quater and year variable;
data work.masterfdic;
merge work.fbase
      work.fadvr
	  work.fsevr;
by scenario date_q ;
qtr=substr(date_q,6,1);
yr=substr(date_q,1,4);
year = yr*1;


*create quarterly/seasonal dummies;
quarter1=(qtr=1);  quarter2=(qtr=2);  quarter3=(qtr=3); quarter4=(qtr=4); 
run;
******************************************************************************/
*  Here, we check for trends in the some of the dependent variables;
/******************************************************************************/

symbol1 interpol=spline value=dot color=vibg;                                                                                           
symbol2 interpol=spline value=dot color=depk;                                                                                           
symbol3 interpol=spline value=dot color=mob;                                                                                            
legend1 order=('First' 'Third') label=none frame;                                                                                       
axis1 label=none;    
 
Title "Checking for trends and seasonality in the data";   
proc sgplot data=work.masterfdic;
series x=date y=rgdp / markers markerattrs=(color=red symbol='asterisk') lineattrs=(color=red) legendlabel="rgdp" ;
series x=date y=rdi/ markers markerattrs=(color=blue symbol='circle') lineattrs=(color=blue) legendlabel="rdi" ;
yaxis label='RealGDP% and RealDisposableInc%';
run;
proc sgplot data=work.masterfdic;
series x=date y=ur / markers markerattrs=(color=red symbol='asterisk') lineattrs=(color=red) legendlabel="ur" ;
series x=date y=cpi / markers markerattrs=(color=cream symbol='plus') lineattrs=(color=cream) legendlabel="cpi" ;
yaxis label='Unemployment and Inflation';

run;
proc sgplot data=work.masterfdic;
series x=date y=treas_3m/ markers markerattrs=(color=blue symbol='circle') lineattrs=(color=blue) legendlabel="treas_3m" ;
series x=date y=treas_5y/ markers markerattrs=(color=green symbol='circlefilled') lineattrs=(color=green) legendlabel="treas_5y" ;
series x=date y=cpi / markers markerattrs=(color=red symbol='plus') lineattrs=(color=red) legendlabel="cpi" ;
yaxis label='Inflation and Treasury Rates';

run;
proc sgplot data=work.masterfdic;
series x=date y=treas_3m/ markers markerattrs=(color=red symbol='circle') lineattrs=(color=red) legendlabel="treas_3m" ;
series x=date y=treas_10y/ markers markerattrs=(color=blue symbol='circle') lineattrs=(color=blue) legendlabel="treas_10y" ;
series x=date y=treas_5y/ markers markerattrs=(color=black symbol='circlefilled') lineattrs=(color=black) legendlabel="treas_5y" ;
yaxis label='Can I omitt?';*will omitt 10year as it so closely related to 5y;

run;

proc sgplot data=work.masterfdic;

series x=date y=bbb/ markers markerattrs=(color=blue symbol='circle') lineattrs=(color=blue) legendlabel="bbb" ;
series x=date y=mort_rate/ markers markerattrs=(color=black symbol='circlefilled') lineattrs=(color=black) legendlabel="mort_rate" ;
yaxis label='Can I omitt?';*with the exception of 2010, where bbb saw high  spikes, mort_rate follow closely to bbb. Will keep bbb to keep the effect of that spike;

run;
Title "Trend in Levels of Interest Bearing Deposits"; 
proc sgplot data=work.masterfdic;
series x=date y=ideposits / markers markerattrs=(color=red symbol='asterisk') lineattrs=(color=red) legendlabel="ideposits" ;
reg y=ideposits x=date;
run;
Title "Trend in DIFFERENCES of Interest Bearing Deposits"; 
proc sgplot data=work.masterfdic; 
series x=date y=ideposits_d1/ markers markerattrs=(color=blue symbol='circle') lineattrs=(color=blue) legendlabel="ideposits_d1" ; 
reg y=ideposits_d1 x=date;
run;
Title "Trend in %CHANGE of Interest Bearing Deposits"; 
proc sgplot data=work.masterfdic; 
series x=date y=ideposits_p1/ markers markerattrs=(color=red symbol='circlefilled') lineattrs=(color=red) legendlabel="ideposits_p1" ; 
reg y=ideposits_p1 x=date;
run;


/******************************************************************************
* 					 ADF unit root tests 
******************************************************************************/

*test levels;
proc autoreg data=work.masterfdic;
title 'Test: Levels';
	model ideposits = /nomiss 
					  stationarity=(adf=(1 2 3 4));
	where scenario eq 'actuals';
run;

*test first-difference;* once accounting for the trend in data no unit root is present for differencing the data
proc autoreg data=work.masterfdic;
title 'Test: First Difference';
	model ideposits_d1 = /nomiss 
					  stationarity=(adf=(1 2 3 4));
	where scenario eq 'actuals';
run;

*test percent-change;
proc autoreg data=work.masterfdic;
title 'Test: Percent Change';
	model ideposits_p1 = /nomiss 
					  stationarity=(adf=(1 2 3 4));
	where scenario eq 'actuals';
run;

*test log-difference;
proc autoreg data=work.masterfdic;
title 'Test: Log-difference';
	model ideposits_od1 = /nomiss 
					  stationarity=(adf=(1 2 3 4));
	where scenario eq 'actuals';
run;


/******************************************************************************
*  					Test of seasonality
******************************************************************************/

proc x11 data=work.masterfdic(where=(scenario ='actuals'));
	title 'Seasonality Test';
	quarterly date=date;
	var ideposits; *level variable;
	tables d8; *summarises seasonality test results;
	output out=x11_output b1=original d11=adjusted;
run;

proc sgplot data=x11_output;
series x=date y=original / markers
markerattrs=(color=red symbol='asterisk')
lineattrs=(color=red)
legendlabel="original" ;
series x=date y=adjusted / markers
markerattrs=(color=blue symbol='circle')
lineattrs=(color=blue)
legendlabel="adjusted" ;
yaxis label='Original and Seasonally Adjusted Time Series';
run;
/******************************************************************************
* 						  Test for Normality
******************************************************************************/
ods graphics on;
title 'Normality Test'; 
proc TTEST data= work.masterfdic;
var ideposits;
run; * Based on the result, the level is not normaly distibuted. ;
proc TTEST data= work.masterfdic;
var ideposits_d1;
run; *Based on the result, the percent change is mostly normally distributed;
proc TTEST data= work.masterfdic;
var ideposits_p1;
run;*Based on the result, the percent change is normally distributed;

*Interest bearing deposits are not seasonal, so we include quarterly indicator vars in all models;

/******************************************************************************
* 						 Model Selection
******************************************************************************/

*Deleting observations with no data for vix;  


*Model selection for levels;
ods graphics on;
title 'Forward Selection with Seasonal Dummies Included';
proc reg data=work.masterfdic plots=(criteria sbc);*all lagged variables.;*eliminating vix bc of missvariables in dataset. 
title 'Forward Selection with Seasonal Dummies Included'; *omitted mort_rate as it is similar to bbb, omitted treas_10 as it is similar to omitted treas_5.;
model ideposits =  quarter1 quarter2 quarter3 year
			   bbb_a1 bbb_a2 bbb_a3 bbb_a4	
			   cpi_a1 cpi_a2 cpi_a3 cpi_a4
			   dow_a1 dow_a2 dow_a3 dow_a4
			   hpi_a1 hpi_a2 hpi_a3 hpi_a4
			   treas_3m_a1 treas_3m_a2 treas_3m_a3 treas_3m_a4
			   treas_5y_a1 treas_5y_a2 treas_5y_a3 treas_5y_a4
			   rdi_a1 rdi_a2 rdi_a3 rdi_a4
			   rgdp_a1 rgdp_a2 rgdp_a3 rgdp_a4
			   ur_a1 ur_a2 ur_a3 ur_a4
/vif selection=forward slentry=.1 details=steps include=3;
run; quit;

*Model selection for differences;
ods graphics on;
title 'Forward Selection with Diffrences/Quarter Dummies Included';
proc reg data=work.masterfdic plots=(criteria sbc);*all diffenced variables ;
model ideposits_d1  =  quarter1 quarter2 quarter3 year
			   bbb_d1 bbb_d1a1 bbb_d1a2 bbb_d1a3 bbb_d1a4	
			   cpi_d1 cpi_d1a1 cpi_d1a2 cpi_d1a3 cpi_d1a4
			   dow_d1 dow_d1a1 dow_d1a2 dow_d1a3 dow_d1a4
			   hpi_d1 hpi_d1a1 hpi_d1a2 hpi_d1a3 hpi_d1a4
			   treas_3m_d1 treas_3m_d1a1 treas_3m_d1a2 treas_3m_d1a3 treas_3m_d1a4
			   treas_5y_d1 treas_5y_d1a1 treas_5y_d1a2 treas_5y_d1a3 treas_5y_d1a4
			   rdi_d1 rdi_d1a1 rdi_d1a2 rdi_d1a3 rdi_d1a4
			   rgdp_d1 rgdp_d1a1 rgdp_d1a2 rgdp_d1a3 rgdp_d1a4
			   ur_d1 ur_d1a1 ur_d1a2 ur_d1a3 ur_d1a4
			   
/vif selection=forward slentry=.1 details=steps include=3;
run; quit;

*Model selection for percent change;
ods graphics on;
title 'Forward Selection with Percnet Change; Dummies Included';
proc reg data=work.masterfdic plots=(criteria sbc);*all percent change variables ;
model ideposits_p1 =  quarter1 quarter2 quarter3 year
			   bbb_p1 bbb_p1a1 bbb_p1a2 bbb_p1a3 bbb_p1a4	
			   cpi_p1 cpi_p1a1 cpi_p1a2 cpi_p1a3 cpi_p1a4
			   dow_p1 dow_p1a1 dow_p1a2 dow_p1a3 dow_p1a4
			   hpi_p1 hpi_p1a1 hpi_p1a2 hpi_p1a3 hpi_p1a4
			   treas_3m_p1 treas_3m_p1a1 treas_3m_p1a2 treas_3m_p1a3 treas_3m_p1a4
			   treas_5y_p1 treas_5y_p1a1 treas_5y_p1a2 treas_5y_p1a3 treas_5y_p1a4
			   rdi_p1 rdi_p1a1 rdi_p1a2 rdi_p1a3 rdi_p1a4
			   rgdp_p1 rgdp_p1a1 rgdp_p1a2 rgdp_p1a3 rgdp_p1a4
			   ur_p1 ur_p1a1 ur_p1a2 ur_p1a3 ur_p1a4
			   
/vif selection=forward slentry=.1 details=steps include=3;
run; quit;
*Model selection for differences;
ods graphics on;title 
'Forward Selection with AIC Diffrences/Quarter Dummies Included';
proc reg data=work.masterfdic plots=(criteria aic);*all diffenced  with AIC criteriavariables produced the estimates as SBC ;
model ideposits_d1  =  quarter1 quarter2 quarter3 year
			   bbb_d1 bbb_d1a1 bbb_d1a2 bbb_d1a3 bbb_d1a4	
			   cpi_d1 cpi_d1a1 cpi_d1a2 cpi_d1a3 cpi_d1a4
			   dow_d1 dow_d1a1 dow_d1a2 dow_d1a3 dow_d1a4
			   hpi_d1 hpi_d1a1 hpi_d1a2 hpi_d1a3 hpi_d1a4
			   treas_3m_d1 treas_3m_d1a1 treas_3m_d1a2 treas_3m_d1a3 treas_3m_d1a4
			   treas_5y_d1 treas_5y_d1a1 treas_5y_d1a2 treas_5y_d1a3 treas_5y_d1a4
			   rdi_d1 rdi_d1a1 rdi_d1a2 rdi_d1a3 rdi_d1a4
			   rgdp_d1 rgdp_d1a1 rgdp_d1a2 rgdp_d1a3 rgdp_d1a4
			   ur_d1 ur_d1a1 ur_d1a2 ur_d1a3 ur_d1a4
			   
/vif selection=forward slentry=.1 details=steps include=3;
run; quit;

*refine the difference model based on vif;
proc reg data=work.masterfdic;
title 'Refined Regression';
model ideposits_d1 = quarter1 quarter2 quarter3 year  cpi_d1 cpi_d1a1 cpi_d1a3 treas_5y_d1 rdi_d1a3 ur_d1a4/vif;
run; quit;


proc autoreg data=work.masterfdic;
title 'Forward Selection Differenced Variables Selected ';
where scenario in ('actuals','fbase');
model ideposits_d1 = quarter1 quarter2 quarter3 year  cpi_d1 cpi_d1a1 cpi_d1a3 treas_5y_d1 rdi_d1a3 ur_d1a4
/covest=neweywest dw=4 dwprob godfrey=4 normal archtest=(qlm,lk) method=ml; *Q,LM and Lee and King (lk) tests of arch errors;
output out=pred_fbase (keep=year date scenario ideposits ideposits_d1 rdi ur cpi treas_5y pred_ideposits_d1 r_ideposits_d1) p=pred_ideposits_d1 r=r_ideposits_d1;
run;
/**********Exporting and storing predicted values *******/
PROC EXPORT DATA= work.pred_fbase
            OUTFILE= "C:\Users\king.2615\Downloads\Predicted Interest Bearing Deposits.xlsx" 
            DBMS=XLSX replace;
     SHEET="Base"; 
RUN;

proc autoreg data=work.masterfdic;
title 'Forward Selection Differenced Variables Selected ';
where scenario in ('actuals','fbase');
model ideposits_d1 = quarter1 quarter2 quarter3 year  cpi_d1 cpi_d1a1 cpi_d1a3 treas_5y_d1 rdi_d1a3 ur_d1a4
/covest=neweywest dw=4 dwprob godfrey=4 normal archtest=(qlm,lk) method=ml; *Q,LM and Lee and King (lk) tests of arch errors;
output out=pred_fbase (keep=year date scenario ideposits ideposits_d1 rdi ur cpi treas_5y pred_ideposits_d1 r_ideposits_d1) p=pred_ideposits_d1 r=r_ideposits_d1;
run;
/**********Exporting and storing predicted values *******/
PROC EXPORT DATA= work.pred_fbase
            OUTFILE= "C:\Users\king.2615\Downloads\Predicted Interest Bearing Deposits.xlsx" 
            DBMS=XLSX replace;
     SHEET="Base"; 
RUN;
