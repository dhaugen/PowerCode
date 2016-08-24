#include <stdio.h>

/*	This structure contains diagnostic data from the satellite eps, it is stuctured
to allow for dynamic size as orbit which would normally define the size of the arrays
is not a set value*/

struct SystemPowerData {
	long P_solar;
	long batt_E;
	long inc_I;
	long load_I;
	long batt_I;
	long batt_V;
	int t_orbit;
	long lastPower;
};

struct SystemPowerData *GetEPSData();
long getNextPower();
long Estimation(struct SystemPowerData *diagnosticData);
void SavePower(long output);

long sum_array(long a[], int num_elements);
void dupeFile();

void main()
{
	dupeFile();

	for (int i = 0; i < 8648; i++) {
		getNextPower();
	}
}

long getNextPower()
{
	struct SystemPowerData *diagnosticData;

	diagnosticData = GetEPSData();

	long output = 0;

	//program
	output = Estimation(diagnosticData);

	SavePower(output);

	free(diagnosticData);

	return output;
}

long Estimation(struct SystemPowerData *diagnosticData)
{
	long *pWasted;
	pWasted = (long *)malloc(sizeof(long));
	if (pWasted == NULL)
	{
		// Add error log report
	}

	long *wasted;
	wasted = (long *)malloc(diagnosticData->t_orbit * sizeof(long));
	if (wasted == NULL)
	{
		// Add error log report
	}

	long batt_eff = 85;
	long solar_eff = 92;
	long conv_eff = 95;

	long Vmax = 16600;


	//Weight Coefficients
	//k1 Balance between measured, and derived value of power wasted
	long k1 = 95;
	//k2 Balance between measured, and derived value of battery energy
	long k2 = 80;
	//k3 Weight for the effect of battery energy measured vs estimated
	long k3 = 20;
	//k4 Weight for the effect of average battery measurement vs norm.
	long k4 = 25;
	//k5 Coefficent determining the normal battery operation level
	long k5 = .90 * 2600 * 3600 * 16100 / 1000;
	//k6 Coefficent to control the responsivness based on under use
	long k6 = 90;
	//k7 Coefficient to control the reponsivness based on over use
	long k7 = 90;
	//k8 Controls the response to the accuracy of last power prediciton
	long k8 = 10;

	//Initializing tracking of energy - should make a determination on the
	//first pass of the filter and track from there, this would be a calc to determine capacity from voltage

	//this is ideal, will need to dynamically keep track of max battery capacity
	long full_Charge = 2600 / 1000 * 3600 * 16600;

	// This is 2600 mAh * 60 mins * 60 seconds * mV = Energy (mJ)
	long curr_Energy = full_Charge;

	//-------------Update Filter------------------------
	// Calculates averages for the last orbit
	int i;
	for (i = 0; i < diagnosticData->t_orbit; i++)
	{
		/*Deriving solar voltage for power wasted, for now if the power intake is less than 20 mW the solar V is
		considered 0, this is a value that can be called directly from the satellite rather than derived */
		long V_solar = 0;
		if ((diagnosticData + i)->P_solar > 20) {
			V_solar = (diagnosticData + i)->P_solar * 1000 / (diagnosticData + i)->inc_I;
		}
		//Battery current is always positive data, determining whether or
		//not the battery is charging or discharging
		if ((diagnosticData + i)->load_I > (diagnosticData + i)->inc_I)
		{
			(diagnosticData + i)->batt_I = (diagnosticData + i)->batt_I * -1;
		}

		//Battery current is the line to the battery, this is the derivation of that value

		//Check solar power for wasted input to determine current state
		/*currentIn:	Derives the amount of current coming into the system*/
		/*expectedIn:	Derives the amount of current that should be coming into the system
		based on the state of the solar panels*/

		long currentIn = (diagnosticData + i)->P_solar * 1000 * solar_eff / (diagnosticData + i)->batt_V / 100;
		long expectedIn = 0;
		if (V_solar > 0) {
			expectedIn = (diagnosticData + i)->P_solar * 1000 * solar_eff / V_solar / 100;
		}

		if (V_solar >= 16000 && currentIn < expectedIn)
		{
			*(wasted + i) = (diagnosticData + i)->batt_V * (expectedIn - currentIn);
			if (i > 0)
			{
				(diagnosticData + i)->P_solar = (diagnosticData + i - 1)->P_solar;
			}
		}
		else {
			*(wasted + i) = 0;
		}
	}

	*pWasted = sum_array(wasted, (diagnosticData)->t_orbit) / diagnosticData->t_orbit;
	free(wasted);

	//-------------End of Update Filter-----------------

	//Get Average Energy and Power for last orbit
	long P_solar_avg = 0;
	long totalPower = 0;
	for (int i = 0; i < diagnosticData->t_orbit; i++) {
		totalPower += (diagnosticData + i)->P_solar;
	}
	P_solar_avg = totalPower * solar_eff / diagnosticData->t_orbit / 100;

	long E_bat_meas_avg = 0;
	for (int i = 0; i < diagnosticData->t_orbit; i++) {
		E_bat_meas_avg = E_bat_meas_avg + (diagnosticData + i)->batt_E / (diagnosticData + i)->t_orbit;
	}

	//--------------Battery Control----------------------
	//Energy control (Like power wasted for Energy)
	//Checking the discrepency between energies to find a Next orbit
	//modifier, P_est is being assumed as what is being used and not
	//what the other half of the program would return as used
	long E_dis = curr_Energy + (totalPower * (long)60 * solar_eff / 100) - diagnosticData->lastPower * 60
		* diagnosticData->t_orbit / conv_eff * 100 * batt_eff / 100;
	long overdrawn_mod = 0;

	//Determines if energy was overspent and converts that
	//value into an orbital power correction.

	if (E_dis < full_Charge)
	{
		overdrawn_mod = (E_dis - full_Charge) / (diagnosticData->t_orbit * 60);
	}

	//Updates current energy as well as imposes physical limits of the
	//battery on the calculated value.  Wasted amounts of energy are
	//accounted for in overdrawn_mod.
	curr_Energy = E_dis;
	if (curr_Energy > 155376000)
	{
		//Physical limitation of
		//2.6 Ah in Joules
		curr_Energy = 155376000;
	}
	if (curr_Energy < 0)
	{
		curr_Energy = 0;
	}
	//-----------(end Battery Control)------------------
	//P_est update

	//Equation is counter to Kalman filter documentation, using mean
	//instead of max of solar power
	*pWasted = k1 * *pWasted / 100 + (totalPower / diagnosticData->t_orbit * solar_eff / 100
		- diagnosticData->lastPower) * (100 - k1) / 100;
	long E_bat_meas = (diagnosticData + (diagnosticData->t_orbit - 1))->batt_E;

	long E_bat_est = E_bat_meas / 100 * k2 + (curr_Energy) / 100 * (100 - k2);

	//Last Orbit comparison for how close the prediction was
	long Accuracy_mod = P_solar_avg - diagnosticData->lastPower;

	//Dividing energy estimates by t_orbit*60 so they become power as these are
	//energy estimates per orbit

	long P_est = P_solar_avg + k3 *(E_bat_meas - E_bat_est) / (diagnosticData->t_orbit * 60) / 100 + k4 * (E_bat_meas_avg - k5)
		/ (diagnosticData->t_orbit * 60) / 100 + *pWasted * k6 / 100 + overdrawn_mod * k7 / 100 + Accuracy_mod * k8 / 100;

	long test1 = P_solar_avg;
	long test2 = k3 *(E_bat_meas - E_bat_est) / (diagnosticData->t_orbit * 60) / 100;
	long test3 = k4 * (E_bat_meas_avg - k5) / (diagnosticData->t_orbit * 60) / 100;
	long test4 = *pWasted * k6 / 100;
	long test5 = overdrawn_mod * k7 / 100;
	long test6 = Accuracy_mod * k8 / 100;

	//Correction for negative value
	if (P_est < 0)
	{
		P_est = -1 * P_est;
	}

	return P_est;
}

struct SystemPowerData *GetEPSData() {

	int t_orbit = 0;
	long lastPower = 0;
	int skipCount = 0;

	/*	The contents of the file are organized as
	t_orbit, lastPower\n
	P_solar, batt_E, inc_I, batt_I, batt_V, load_I\n  ** for t_orbit iterations **		*/

	FILE *fp;
	FILE *fpcount;

	fopen_s(&fpcount, "tracker.txt", "r");
	fscanf_s(fpcount, "%i", &skipCount);
	fclose(fpcount);

	fopen_s(&fp, "testPowerData.csv", "r");

	/*  Fast forwarding to the proper line in the file.
	Each orbit of test data is preceded with last power and orbit length information.
	The loop tracks where the header information is so that any length of orbit can be
	tested.  Cannot just seek the position due to variable orbit size.					*/
	char seeker;
	int headerLine = 1;
	int orbitDivisions = 0;

	for (int j = 0; j < skipCount;) {
		if (headerLine) {
			fscanf_s(fp, "%ld,%i\n", &lastPower, &t_orbit);
			headerLine = 0;
			orbitDivisions += t_orbit;
		}

		seeker = getc(fp);
		if (seeker == EOF) {
			break;
		}

		if (seeker == '\n') {
			j++;
		}

		if (j == orbitDivisions) {
			headerLine = 1;
		}
	}

	if (headerLine) {
		fscanf_s(fp, "%ld,%i\n", &lastPower, &t_orbit);
		headerLine = 0;
		orbitDivisions += t_orbit;
	}

	/*	This retrieves the requested orbital data over a size of the last t_orbit encountered after the
	function seeks to the current orbit.  This code structure is completely dependent on
	the structure of the test data outlined above.										*/

	struct SystemPowerData *readData;
	readData = (struct SystemPowerData*)malloc(sizeof(struct SystemPowerData) * t_orbit);
	int headerLocation = orbitDivisions - skipCount;
	int initialOrbit = t_orbit;

	for (int i = 0; i < initialOrbit; i++)
	{
		if (i == headerLocation) {
			fscanf_s(fp, "%ld,%i\n", &lastPower, &t_orbit);
			headerLocation = i + t_orbit;
		}
		fscanf_s(fp, "%ld,%ld,%ld,%ld,%ld,%ld\n", &(readData + i)->P_solar, &(readData + i)->batt_E,
			&(readData + i)->inc_I, &(readData + i)->batt_I, &(readData + i)->batt_V, &(readData + i)->load_I);
		(readData + i)->t_orbit = t_orbit;
		(readData + i)->lastPower = lastPower;
	}

	fopen_s(&fpcount, "tracker.txt", "w");
	fprintf_s(fpcount, "%i", skipCount + 1);
	fclose(fpcount);
	fclose(fp);

	return readData;
}

void SavePower(long output) {
	FILE *fp;
	fopen_s(&fp, "PowerPredictionTest.txt", "a");

	fprintf_s(fp, "%ld\n", output);

	fclose(fp);
}

long sum_array(long a[], int num_elements)
{
	int i;
	long sum = 0;
	for (i = 0; i < num_elements; i++)
	{
		sum = sum + a[i];
	}
	return(sum);
}

void dupeFile()
{
	FILE *orbitFile;
	fopen_s(&orbitFile, "tracker.txt", "w");
	fprintf_s(orbitFile, "%i", 0);
	fclose(orbitFile);

	/*  This code was to duplicate the Test file so that it can increment through the file
	and delete records as they were read to keep its place.  The method was inefficient,
	and was replaced with a file that keeps track of the orbit with a single integer.

	struct SystemPowerData *transferData;
	transferData = (struct SystemPowerData*)malloc(sizeof(struct SystemPowerData));

	FILE *masterfile;
	FILE *dupefile;

	fopen_s(&masterfile, "testPowerData.csv", "r");
	fopen_s(&dupefile, "internalPD.csv", "w");

	while (1) {
	fscanf_s(masterfile, "%ld,%i\n", &transferData->lastPower, &transferData->t_orbit);

	if (feof(masterfile)) {
	fclose(masterfile);
	fclose(dupefile);
	free(transferData);
	break;
	}

	fprintf_s(dupefile, "%ld,%i\n", transferData->lastPower, transferData->t_orbit);

	for (int i = 0; i < transferData->t_orbit; i++) {
	fscanf_s(masterfile, "%ld,%ld,%ld,%ld,%ld,%ld\n", &transferData->P_solar, &transferData->batt_E,
	&transferData->inc_I, &transferData->batt_I, &transferData->batt_V, &transferData->load_I);

	fprintf_s(dupefile, "%ld,%ld,%ld,%ld,%ld,%ld\n", transferData->P_solar, transferData->batt_E,
	transferData->inc_I, transferData->batt_I, transferData->batt_V, transferData->load_I);
	}
	}
	*/
}
