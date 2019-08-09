PROC IMPORT OUT=WORK.Granular 
            DATAFILE= "C:\Users\king.2615\Downloads\Master_Sheet.xlsx"
            DBMS=XLSX REPLACE;
			SHEET="Granular_FICO_MOB";
            GETNAMES=YES;
RUN;
data Granular_PP; set Granular; *creating a new dataset called prepayment data from basic model;
run;
/******************************************************************************
*  Here, we create one version of actual consumption data and append all the two scenario forecasts to 
* these actual. 
******************************************************************************/

*get actual data;
data work.actualGranular;
	set work.Granular_PP ;
		where Scenario = "Actual"; *keeping only actual prepayment data from basic model;
run;
*create macros for each type;
%macro forecast_data(scen);

data work.&scen;
merge work.actualGranular
	  work.Granular_PP(where=(Scenario="&scen"));
by Date Scenario;

run;

%mend forecast_data;

%forecast_data(Actual);

proc contents data=work.Granular_PP 
out=work.vars_Granular(keep= varnum name)
noprint;
run;
proc sql noprint;
select 
	distinct name into:vars separated by ' '
from work.vars_Granular
	where name not like 'Date'
	and name not like 'Scenario'
    and name not like 'PP_Used'
    and name not like 'PP_New'
    and name not like 'PO_Rate_1_1'
    and name not like 'PO_Rate_1_2'
    and name not like 'PO_Rate_1_3'
    and name not like 'PO_Rate_1_4'
    and name not like 'PO_Rate_2_1'
    and name not like 'PO_Rate_2_2'
    and name not like 'PO_Rate_2_3'
    and name not like 'PO_Rate_2_4'
    and name not like 'PO_Rate_3_1'
    and name not like 'PO_Rate_3_2'
    and name not like 'PO_Rate_3_3'
    and name not like 'PO_Rate_3_4'
    and name not like 'PO_Rate_4_1'
    and name not like 'PO_Rate_4_2'
    and name not like 'PO_Rate_4_3'
    and name not like 'PO_Rate_4_4';
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

%transform(12,Actual); 
run;
*create one table with the three growth scenarios for easy reference; *creating a quater and year variable;
data work.mastergranular;
set work.Actual;
run;
* create monthly dummies - to account for seasonality;

data work.mastergranular;
set work.mastergranular;
format date mmddyy10.;
run;

data work.mastergranular;
set work.mastergranular;
month=month(date);
run;

data work.mastergranular;
set work.mastergranular;
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
/************** Lagged Anylysis USED ********************/
title 'Used PO_Rate_1_1';
Proc reg data= mastergranular plots=(criteria SBC);
model  PO_Rate_1_1 =  Feb Mar Apr May June July Aug Sept Oct Nov Dec


CONS_CONFIDENCE_US CONS_CONFIDENCE_US_a3 CONS_CONFIDENCE_US_a6 CONS_CONFIDENCE_US_a9


NET_CASH_FLOW_US   NET_CASH_FLOW_US_a3   NET_CASH_FLOW_US_a6   NET_CASH_FLOW_US_a9  


FHFA_AllTrans_HPI_US FHFA_AllTrans_HPI_US_a3 FHFA_AllTrans_HPI_US_a6 FHFA_AllTrans_HPI_US_a9 


TBOND_5YR_US     TBOND_5YR_US_a3      TBOND_5YR_US_a6      TBOND_5YR_US_a9      


LT_VHL_SALES_US     LT_VHL_SALES_US_a3   LT_VHL_SALES_US_a6   LT_VHL_SALES_US_a9   


CREDIT_CHGOFF_US CREDIT_CHGOFF_US_a3  CREDIT_CHGOFF_US_a6  CREDIT_CHGOFF_US_a9
 
/vif selection=stepwise slstay=.10 slentry=.10 details=steps include=11;

run;
quit;
/* DIFFERENCE IN SIGNS*/
data mastergranular;
set mastergranular;
diff_LTVHL_1_9  = LT_VHL_SALES_US - LT_VHL_SALES_US_a9 ;
run;
/*refine the difference model based on vif; All the different differencing yielded the same result;*/
proc reg data= mastergranular;
title 'Refined Regression';
model PO_Rate_1_1  = Feb Mar Apr May June July Aug Sept Oct Nov Dec  TBOND_5YR_US CREDIT_CHGOFF_US diff_LTVHL_1_9 /vif;
run; quit;



/************** Lagged Anylysis USED ********************/
title 'Used PO_Rate_1_2';
Proc reg data= mastergranular plots=(criteria SBC);
model  PO_Rate_1_2 =  Feb Mar Apr May June July Aug Sept Oct Nov Dec


CONS_CONFIDENCE_US /*CONS_CONFIDENCE_US_a3 CONS_CONFIDENCE_US_a6 CONS_CONFIDENCE_US_a9*/


NET_CASH_FLOW_US   NET_CASH_FLOW_US_a3   NET_CASH_FLOW_US_a6   NET_CASH_FLOW_US_a9  


/*FHFA_AllTrans_HPI_US FHFA_AllTrans_HPI_US_a3*/ FHFA_AllTrans_HPI_US_a6 FHFA_AllTrans_HPI_US_a9 


TBOND_5YR_US     TBOND_5YR_US_a3      TBOND_5YR_US_a6      TBOND_5YR_US_a9      


LT_VHL_SALES_US     LT_VHL_SALES_US_a3   LT_VHL_SALES_US_a6   /*LT_VHL_SALES_US_a9*/   


/*CREDIT_CHGOFF_US CREDIT_CHGOFF_US_a3*/  CREDIT_CHGOFF_US_a6  /*CREDIT_CHGOFF_US_a9*/
 
/vif selection=stepwise slstay=.10 slentry=.10 details=steps include=11;

run;
quit;

/************** Lagged Anylysis USED ********************/
title 'Used PO_Rate_1_3';
Proc reg data= mastergranular plots=(criteria SBC);
model  PO_Rate_1_3 =  Feb Mar Apr May June July Aug Sept Oct Nov Dec


CONS_CONFIDENCE_US /*CONS_CONFIDENCE_US_a3 CONS_CONFIDENCE_US_a6 CONS_CONFIDENCE_US_a9*/


NET_CASH_FLOW_US   NET_CASH_FLOW_US_a3   NET_CASH_FLOW_US_a6   NET_CASH_FLOW_US_a9  


FHFA_AllTrans_HPI_US FHFA_AllTrans_HPI_US_a3 /*FHFA_AllTrans_HPI_US_a6 FHFA_AllTrans_HPI_US_a9*/ 


/*TBOND_5YR_US*/      TBOND_5YR_US_a3      TBOND_5YR_US_a6      TBOND_5YR_US_a9      


/*LT_VHL_SALES_US     LT_VHL_SALES_US_a3  LT_VHL_SALES_US_a6   LT_VHL_SALES_US_a9*/    


/*CREDIT_CHGOFF_US CREDIT_CHGOFF_US_a3*/  CREDIT_CHGOFF_US_a6  CREDIT_CHGOFF_US_a9
 
/vif selection=stepwise slstay=.10 slentry=.10 details=steps include=11;

run;
quit;

/************** Lagged Anylysis USED ********************/
title 'Used PO_Rate_1_4';
Proc reg data= mastergranular plots=(criteria SBC);
model  PO_Rate_1_4 =  Feb Mar Apr May June July Aug Sept Oct Nov Dec


CONS_CONFIDENCE_US CONS_CONFIDENCE_US_a3 CONS_CONFIDENCE_US_a6 CONS_CONFIDENCE_US_a9


NET_CASH_FLOW_US   NET_CASH_FLOW_US_a3   NET_CASH_FLOW_US_a6   NET_CASH_FLOW_US_a9  


FHFA_AllTrans_HPI_US FHFA_AllTrans_HPI_US_a3 FHFA_AllTrans_HPI_US_a6 FHFA_AllTrans_HPI_US_a9 


TBOND_5YR_US     TBOND_5YR_US_a3      TBOND_5YR_US_a6      TBOND_5YR_US_a9      


LT_VHL_SALES_US     LT_VHL_SALES_US_a3   LT_VHL_SALES_US_a6   LT_VHL_SALES_US_a9   


CREDIT_CHGOFF_US CREDIT_CHGOFF_US_a3  CREDIT_CHGOFF_US_a6  CREDIT_CHGOFF_US_a9
 
/vif selection=stepwise slstay=.10 slentry=.10 details=steps include=11;

run;
quit;

/************** Lagged Anylysis USED ********************/
title 'Used PO_Rate_3_1';
Proc reg data= mastergranular plots=(criteria SBC);
model  PO_Rate_3_1 =  Feb Mar Apr May June July Aug Sept Oct Nov Dec


CONS_CONFIDENCE_US CONS_CONFIDENCE_US_a3 CONS_CONFIDENCE_US_a6 CONS_CONFIDENCE_US_a9


NET_CASH_FLOW_US   NET_CASH_FLOW_US_a3   NET_CASH_FLOW_US_a6   NET_CASH_FLOW_US_a9  


FHFA_AllTrans_HPI_US FHFA_AllTrans_HPI_US_a3 FHFA_AllTrans_HPI_US_a6 FHFA_AllTrans_HPI_US_a9 


TBOND_5YR_US     TBOND_5YR_US_a3      TBOND_5YR_US_a6      TBOND_5YR_US_a9      


LT_VHL_SALES_US     LT_VHL_SALES_US_a3   /*LT_VHL_SALES_US_a6   LT_VHL_SALES_US_a9*/    


CREDIT_CHGOFF_US CREDIT_CHGOFF_US_a3  CREDIT_CHGOFF_US_a6  CREDIT_CHGOFF_US_a9
 
/vif selection=stepwise slstay=.10 slentry=.10 details=steps include=11;

run;
quit;


/************** Lagged Anylysis USED ********************/
title 'Used PO_Rate_3_2';
Proc reg data= mastergranular plots=(criteria SBC);
model  PO_Rate_3_2 =  Feb Mar Apr May June July Aug Sept Oct Nov Dec


CONS_CONFIDENCE_US CONS_CONFIDENCE_US_a3 CONS_CONFIDENCE_US_a6 CONS_CONFIDENCE_US_a9


NET_CASH_FLOW_US   NET_CASH_FLOW_US_a3   NET_CASH_FLOW_US_a6   NET_CASH_FLOW_US_a9  


FHFA_AllTrans_HPI_US FHFA_AllTrans_HPI_US_a3 FHFA_AllTrans_HPI_US_a6 FHFA_AllTrans_HPI_US_a9 


TBOND_5YR_US     TBOND_5YR_US_a3      TBOND_5YR_US_a6      TBOND_5YR_US_a9      


LT_VHL_SALES_US     /*LT_VHL_SALES_US_a3*/   LT_VHL_SALES_US_a6   /*LT_VHL_SALES_US_a9*/   


/*CREDIT_CHGOFF_US*/ CREDIT_CHGOFF_US_a3  CREDIT_CHGOFF_US_a6  CREDIT_CHGOFF_US_a9
 
/vif selection=stepwise slstay=.10 slentry=.10 details=steps include=11;

run;
quit;
/* DIFFERENCE IN SIGNS*/
data mastergranular;
set mastergranular;
diff_tbond_3_9  = TBOND_5YR_US_a3 - TBOND_5YR_US_a9 ;
run;
/*refine the difference model based on vif; All the different differencing yielded the same result;*/
proc reg data= mastergranular;
title 'Refined Regression';
model PO_Rate_3_2  = Feb Mar Apr May June July Aug Sept Oct Nov Dec CONS_CONFIDENCE_US_a3 NET_CASH_FLOW_US_a9 FHFA_AllTrans_HPI_US diff_tbond_3_9/vif;
run; quit;


/************** Lagged Anylysis USED ********************/
title 'Used PO_Rate_3_3';
Proc reg data= mastergranular plots=(criteria SBC);
model  PO_Rate_3_3 =  Feb Mar Apr May June July Aug Sept Oct Nov Dec


CONS_CONFIDENCE_US /*CONS_CONFIDENCE_US_a3*/ CONS_CONFIDENCE_US_a6 /*CONS_CONFIDENCE_US_a9*/


NET_CASH_FLOW_US   NET_CASH_FLOW_US_a3   NET_CASH_FLOW_US_a6   NET_CASH_FLOW_US_a9  


/*FHFA_AllTrans_HPI_US*/ FHFA_AllTrans_HPI_US_a3 FHFA_AllTrans_HPI_US_a6 /*FHFA_AllTrans_HPI_US_a9*/ 


TBOND_5YR_US     TBOND_5YR_US_a3      TBOND_5YR_US_a6      TBOND_5YR_US_a9      


LT_VHL_SALES_US     LT_VHL_SALES_US_a3   /*LT_VHL_SALES_US_a6   LT_VHL_SALES_US_a9*/   


/*CREDIT_CHGOFF_US*/ /*CREDIT_CHGOFF_US_a3*/  CREDIT_CHGOFF_US_a6  /*CREDIT_CHGOFF_US_a9*/
 
/vif selection=stepwise slstay=.10 slentry=.10 details=steps include=11;

run;
quit;

/*refine the difference model based on vif; All the different differencing yielded the same result;*/
proc reg data= mastergranular;
title 'Refined Regression';
model PO_Rate_3_3  = Feb Mar Apr May June July Aug Sept Oct Nov Dec NET_CASH_FLOW_US_a9 FHFA_AllTrans_HPI_US_a6 diff_tbond_3_9 LT_VHL_SALES_US_a3/vif;
run; quit;


/************** Lagged Anylysis USED ********************/
title 'Used PO_Rate_3_4';
Proc reg data= mastergranular plots=(criteria SBC);
model  PO_Rate_3_4 =  Feb Mar Apr May June July Aug Sept Oct Nov Dec


CONS_CONFIDENCE_US CONS_CONFIDENCE_US_a3 /*CONS_CONFIDENCE_US_a6 CONS_CONFIDENCE_US_a9*/


NET_CASH_FLOW_US   NET_CASH_FLOW_US_a3   NET_CASH_FLOW_US_a6   NET_CASH_FLOW_US_a9  


FHFA_AllTrans_HPI_US /*FHFA_AllTrans_HPI_US_a3 FHFA_AllTrans_HPI_US_a6*/ FHFA_AllTrans_HPI_US_a9 


/*TBOND_5YR_US     TBOND_5YR_US_a3      TBOND_5YR_US_a6*/      TBOND_5YR_US_a9      


LT_VHL_SALES_US     LT_VHL_SALES_US_a3   /*LT_VHL_SALES_US_a6*/   LT_VHL_SALES_US_a9   


/*CREDIT_CHGOFF_US*/ CREDIT_CHGOFF_US_a3  CREDIT_CHGOFF_US_a6  CREDIT_CHGOFF_US_a9
 
/vif selection=stepwise slstay=.10 slentry=.10 details=steps include=11;

run;
quit;
/* DIFFERENCE IN SIGNS*/
data mastergranular;
set mastergranular;
diff_credit_3_9  = LT_VHL_SALES_US - LT_VHL_SALES_US_a9;
run;
/*refine the difference model based on vif; All the different differencing yielded the same result;*/
proc reg data= mastergranular;
title 'Refined Regression';
model PO_Rate_3_4  = Feb Mar Apr May June July Aug Sept Oct Nov Dec diff_credit_3_9/vif;
run; quit;
