PROC IMPORT OUT=WORK.Basic_Model 
            DATAFILE= "C:\Users\king.2615\Downloads\Master_Sheet.xlsx"
            DBMS=XLSX REPLACE;
			SHEET="Basic_Model";
            GETNAMES=YES;
RUN;
data Basic_PP; set Basic_Model; *creating a new dataset called prepayment data from basic model;
run;
/******************************************************************************
*  Here, we create one version of actual consumption data and append all the two scenario forecasts to 
* these actual. 
******************************************************************************/

*get actual data;
data work.actualPP;
	set work.Basic_PP ;
		where Scenario = "Actual"; *keeping only actual prepayment data from basic model;
run;
*create macros for each type;
%macro forecast_data(scen);

data work.&scen;
merge work.actualPP
	  work.Basic_PP(where=(Scenario="&scen"));
by Date Scenario;

run;

%mend forecast_data;

%forecast_data(Scenario1);
%forecast_data(Scenario2);
proc contents data=work.Basic_PP 
out=work.vars_pp(keep= varnum name)
noprint;
run;
proc sql noprint;
select 
	distinct name into:vars separated by ' '
from work.vars_pp
	where name not like 'Date'
	and name not like 'Scenario'
    and name not like 'PP_New'
    and name not like 'PP_Used'
    and name not like 'UsedBW_MOB'
    and name not like 'Used_B_W_LTV'
    and name not like 'Used_B_W_Orig_FICO'
    and name not like 'NewBW_MOB'
    and name not like 'New_B_W_LTV'
    and name not like 'New_B_W_Orig_FICO';
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

%transform(12,Scenario1); 
%transform(12,Scenario2);
run;
*create one table with the three growth scenarios for easy reference; *creating a quater and year variable;
data work.masterbase;
merge work.Scenario1
	  work.Scenario2;
by Scenario Date ; 
run;
* create monthly dummies - to account for seasonality;

data work.masterbase;
set work.masterbase;
format date mmddyy10.;
run;

data work.masterbase;
set work.masterbase;
month=month(date);
run;

data work.masterbase;
set work.masterbase;
Jan=(month=1);
Feb=(month=2);
Mar=(month=3);
Apr=(month=4);
May=(month=5);
June=(month=6);
July=(month=7);
Aug=(month=8);
Sept=(month=9);
Oct=(month=10);
Nov=(month=11);
Dec=(month=12);
run;

/************** Lagged Anylysis New ********************/
title 'Based Model Used Prepayment';
Proc reg data= masterbase plots=(criteria SBC);
model  PP_Used =  Feb Mar Apr May June July Aug Sept Oct Nov Dec
/*UsedBW_MOB*/
Used_B_W_LTV
/*Used_B_W_Orig_FICO*/


/*CONS_CONFIDENCE_US CONS_CONFIDENCE_US_a3*/ CONS_CONFIDENCE_US_a6 /*CONS_CONFIDENCE_US_a9*/


NET_CASH_FLOW_US   NET_CASH_FLOW_US_a3   /*NET_CASH_FLOW_US_a6   NET_CASH_FLOW_US_a9*/  


/*FHFA_AllTrans_HPI_US FHFA_AllTrans_HPI_US_a3 FHFA_AllTrans_HPI_US_a6 FHFA_AllTrans_HPI_US_a9*/ 


TBOND_5YR_US     TBOND_5YR_US_a3      /*TBOND_5YR_US_a6      TBOND_5YR_US_a9*/      


LT_VHL_SALES_US     /*LT_VHL_SALES_US_a3   LT_VHL_SALES_US_a6*/   LT_VHL_SALES_US_a9   


CREDIT_CHGOFF_US CREDIT_CHGOFF_US_a3  CREDIT_CHGOFF_US_a6  CREDIT_CHGOFF_US_a9
		
/vif selection=stepwise slstay=.10 slentry=.10 details=steps include=11;

run;
quit;
/* DIFFERENCE IN SIGNS*/
data masterbase;
set masterbase;
diff_LTVHL_3_9  = LT_VHL_SALES_US - LT_VHL_SALES_US_a9;
run;


/*refine the difference model based on vif; All the different differencing yielded the same result;*/
proc reg data= masterbase;
title 'Refined Regression';
model PP_Used = Feb Mar Apr May June July Aug Sept Oct Nov Dec CONS_CONFIDENCE_US_a6  diff_LTVHL_3_9 CREDIT_CHGOFF_US/vif;
run; quit;
*Final Model--Forecast Scenario 1; 
proc autoreg data=work.masterbase;
title 'Model with forecast for Scenario 1';
where Scenario in ('Actual','Scenario1');
model PP_Used = Feb Mar Apr May June July Aug Sept Oct Nov Dec
CONS_CONFIDENCE_US_a6
diff_LTVHL_3_9
CREDIT_CHGOFF_US
/covest=neweywest dw=12 dwprob godfrey=12 normal archtest=(qlm,lk) method=ml;

output out=pred_base1 (keep= date Scenario PP_Used pred_PP_Used) p=pred_PP_Used r=r_PP_Used;
run;
 

*Final Model--Forecast Scenario 2; 
proc autoreg data=work.masterbase;
title 'Model with forecast for Scenario 2';
where Scenario in ('Actual','Scenario2');
model PP_Used = Feb Mar Apr May June July Aug Sept Oct Nov Dec
CONS_CONFIDENCE_US_a6
diff_LTVHL_3_9
CREDIT_CHGOFF_US
/covest=neweywest dw=12 dwprob godfrey=12 normal archtest=(qlm,lk) method=ml;

output out=pred_base2 (keep= date Scenario PP_Used pred_PP_Used) p=pred_PP_Used r=r_PP_Used;
run;
 
/**********Exporting and storing predicted values *******/
PROC EXPORT DATA= work.pred_base1
            OUTFILE= "C:\Users\king.2615\Downloads\Final_Predictions.xlsx" 
            DBMS=XLSX replace;
     SHEET="Scenario1"; 
RUN;
PROC EXPORT DATA= work.pred_base2
            OUTFILE= "C:\Users\king.2615\Downloads\Final_Predictions.xlsx" 
            DBMS=XLSX replace;
     SHEET="Scenario2"; 
RUN;
