#include <stdio.h>
#include "mex.h"
#include <matrix.h>

double sum_array(double a[], int num_elements);
double maximum(double a[], int num_elements);

//input separate arrays for Energy/Power/etc rather
//than one struct under "State"

//Use struct to pass back stuff
struct Estimated_values
{
	double Energy;
	double Power;
};

struct Estimated_values estimation(int T_orbit, double batt_E[], double P_solar[], double inc_I[], double load_I[], double batt_I[], double batt_V[], double lastPower);


void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
	//declare variables
	//const mwSize *dims;
	double *batt_E;
	double *P_solar;
	double *inc_I;
	double *load_I;
	double *batt_I;
	double *batt_V;
	double lastPower;
	int T_orbit;


	//inputs
	batt_E = mxGetPr(prhs[0]);
	P_solar = mxGetPr(prhs[1]);
	inc_I = mxGetPr(prhs[2]);
	load_I = mxGetPr(prhs[3]);
	batt_I = mxGetPr(prhs[4]);
	batt_V = mxGetPr(prhs[5]);
	lastPower = mxGetScalar(prhs[6]);
	T_orbit = mxGetScalar(prhs[7]);


	struct Estimated_values output;

	//program
	output = estimation(T_orbit, batt_E, P_solar, inc_I, load_I, batt_I, batt_V, lastPower);

	//output
	plhs[0] = mxCreateDoubleScalar(output.Energy);
	plhs[1] = mxCreateDoubleScalar(output.Power);
}

struct Estimated_values estimation(int T_orbit, double batt_E[], double P_solar[], double inc_I[], double load_I[], double batt_I[], double batt_V[], double lastPower)
{

	//Struct for output
	struct Estimated_values Output;


	//int T_orbit = 92;
	//int t_tick = 1;
	double P_wasted;
	
	//double wasted[T_orbit];

	double *wasted;
	//Using mxMalloc as runs better with matlab
	//wasted = (double *)mxMalloc(T_orbit * sizeof(double));
	wasted = (double *)malloc(T_orbit * sizeof(double));
	if (wasted == NULL)
	{
		/*Failed to allocate memory*/
	}

	double batt_eff = 0.85;
	double solar_eff = 0.92;
	double conv_eff = 0.955;

	double Vmax = 16.6;


	//Weight Coefficients
	//k1 Balance between measured, and derived value of power wasted
	double k1 = 0.95;
	//k2 Balance between measured, and derived value of battery energy
	double k2 = 0.8;
	//k3 Weight for the effect of battery energy measured vs estimated
	double k3 = 0.2;
	//k4 Weight for the effect of average battery measurement vs norm.
	double k4 = 0.25;
	//k5 Coefficent determining the normal battery operation level
	double k5 = 0.90 * 2.6 * 3600 * 16.1;
	//k6 Coefficent to control the responsivness based on under use
	double k6 = 0.9;
	//k7 Coefficient to control the reponsivness based on over use
	double k7 = 0.9;
	//k8 Controls the response to the accuracy of last power prediciton
	double k8 = 0.1;

	//Initializing tracking of energy - should make a determination on the
	//first pass of the filter and track from there, this would be a calc to determine capacity from voltage
	double curr_Energy = 2.6 * 3600 * 16.6;

	//this is ideal, will need to dynamically keep track of max battery capacity
	double Full_Charge = 2.6 * 3600 * 16.6;

	//-------------Update Filter------------------------
	//emulates updates every tick (orbit fraction)
	int i;
	for (i = 0; i < T_orbit; i++)
	{
		//Deriving solar voltage for power wasted,
		//this is a value that can be called directly from the satellite rather than derived
		double V_solar = P_solar[i] / inc_I[i];


		//Battery current is always positive data, determining whether or
		//not the battery is charging or discharging
		if (load_I[i] > inc_I[i])
		{
			batt_I[i] = batt_I[i] * -1;
		}

		//Battery current is the line to the battery, normally

		//Check solar power for wasted input to determine current state
		//currentDraw:  all current drawn by the system.Ideal case use -
		//current drawn by load + all reamining currentIn into battery

		double currentDraw = load_I[i] + batt_I[i];
		double currentIn = -1 * P_solar[i] * solar_eff / batt_V[i];

		if (V_solar >= 16 && currentDraw + currentIn < 0)
		{
			wasted[i] = batt_V[i] * -1 * (currentIn + currentDraw);
			if (i > 0)
			{
				P_solar[i] = P_solar[i - 1];
			}
		}
	}
	P_wasted = sum_array(wasted, sizeof(wasted)/sizeof(wasted[0]))/T_orbit;

	//-------------End of Update Filter-----------------



	//Get Average Energy and Power for last orbit
	double P_solar_avg = solar_eff*sum_array(P_solar, sizeof(P_solar) / sizeof(P_solar[0])) / T_orbit;
	double E_bat_meas_avg = sum_array(batt_E, sizeof(batt_E) / sizeof(batt_E[0])) / T_orbit;

	//--------------Battery Control----------------------
	//Energy control (Like power wasted for Energy)
	//Checking the discrepency between energies to find a Next orbit
	//modifier, P_est is being assumed as what is being used and not
	//what the other half of the program would return as used
	double E_dis = curr_Energy + (sum_array(P_solar, sizeof(P_solar) / sizeof(P_solar[0])) * 60 * solar_eff) - (lastPower * 60 * T_orbit / conv_eff) * batt_eff;
	double overdrawn_mod = 0;

	//Determines if energy was overspent and converts that
	//value into an orbital power correction.

	if (E_dis < Full_Charge)
	{
		overdrawn_mod = (E_dis - Full_Charge) / (T_orbit * 60);
	}


	//Updates current energy as well as imposes physical limits of the
	//battery on the calculated value.  Wasted amounts of energy are
	//accounted for in overdrawn_mod.
	curr_Energy = E_dis;
	if (curr_Energy > 155376)
	{
		//Physical limitation of 2.6 Ah in J
		curr_Energy = 155376;
	}
	else if (curr_Energy < 0);
	{
		curr_Energy = 0;
	}
	//-----------(end Battery Control)------------------
	//P_est update

	//Equation is counter to Kalman filter documentation, using mean
	//instead of max of solar power
	P_wasted = k1 * P_wasted + (1 - k1) * sum_array(P_solar, sizeof(P_solar) / sizeof(P_solar[0])) / (sizeof(P_solar)/sizeof(P_solar[0])) * solar_eff - lastPower;
	double E_bat_meas = batt_E[T_orbit - 1];

	double E_bat_est = k2 * E_bat_meas + (1 - k2) * (curr_Energy);

	//Last Orbit comparison for how close the prediction was
	double Accuracy_mod = P_solar_avg - lastPower;

	//Dividing energy estimates by T_orbit*60 so they become power as these are
	//energy estimates per orbit

	double P_est = P_solar_avg + k3 *(E_bat_meas - E_bat_est) / (T_orbit * 60) + k4 * (E_bat_meas_avg - k5) / (T_orbit * 60) + P_wasted * k6 + overdrawn_mod * k7 + Accuracy_mod * k8;


	//Correction for negative value
	if (P_est < 0)
	{
		P_est = -1*P_est;
	}

	Output.Energy = E_bat_est;
	Output.Power = P_est;

	free(wasted);
	//TEMPORARY CHANGE TO MATLAB EQUIVALENT
	//mxFree(wasted);


	return Output;
}


double sum_array(double a[], int num_elements)
{
	int i;
	double sum = 0;
	for (i = 0; i < num_elements; i++)
	{
		sum = sum + a[i];
	}
	return(sum);
}

double maximum(double a[], int num_elements)
{
	int i;
	double largest = a[0];
	for (i = 1; i < num_elements; i++)
	{
		if (a[i] > largest)
		{
			largest = a[i];
		}
	}

	return(largest);
}
