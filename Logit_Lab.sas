/* AEDE 6330 - Logit In-Class Lab */

/* Load the data on Wisconsin Fishing choices for 10 different lakes

The application is set up as a 10 site recreation demand model with five variables defined as follows:

	- price round trip travel cost between anglers’ homes and the ten sites
	- urban a dummy variable equal one if the site is in an urban area
	- walleye expected catch rate for walleye
	- salmon expected catch rate for salmon
	- panfish expected catch rate for panfish

Walleye, salmon, and panfish are quite different types of sport fish in WI, targeted by different 
types of angler and generally not jointly.
*/
PROC IMPORT OUT= WORK.SiteChoice
            DATAFILE= "C:\Users\buckeye\Downloads\Logit\WI_Lake.csv" 
            DBMS=CSV REPLACE;
     GETNAMES=YES;
     DATAROW=2; 
RUN;

/* ESTIMATE THE MODEL
The MDC procedure, unlike other regression procedures, does not include the intercept term
automatically. The dependent variable decision takes the value 1 when a specific alternative is chosen;
otherwise, it takes the value 0. Each individual is allowed to choose one and only one of the possible
alternatives. In other words, the variable "choice" takes the value 1 one time only for each individual. If each
individual has three elements (1, 2, and 3) in the choice set, the NCHOICE=3 option is specified.

It is very important to note the data structure required to estimate this model!  Make sure that an id variable, 
labeled ID in this example, clearly indicates all potential choices facing each individual.

Finally, the "type=clogit" command ensures we are running a logit command consistent with a RUM model
*/
PROC MDC data=WORK.SiteChoice;
	model choice = TCost Urban Walleye Salmon Panfish /
		nchoice=10
		optmethod=qn
		type=clogit;
	
	* Specify the id variable for each choice/person;	
	id ID;
RUN;
QUIT;

/******************************************/
/* Add alternative specific constants */
/******************************************/

/* First create an indicator for which alternative things are */
DATA WORK.travel_v1;
	set WORK.SiteChoice;
	alternative + 1;
  	by ID;
  	if first.ID then alternative = 1;
run;

/* Next, create a dummy variable for alternative 1 */
DATA WORK.travel_v2;
	set WORK.travel_v1;
	if alternative = 1 then alt1 = 1;
		else alt1 = 0;
run;
