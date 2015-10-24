#ifdef MATLAB_MEX_FILE
#include <tmwtypes.h>
#else
#include "rtwtypes.h"
#endif

struct Estimated_values estimation(int T_orbit, double batt_E[], double P_solar[], double inc_I[], double load_I[], double batt_I[], double batt_V[], double lastPower);
