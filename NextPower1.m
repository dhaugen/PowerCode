function [P_est testResults] = NextPower1(tState, lastPower)
    % Uploadable Variables
    % T_orbit, t_tick(unused atm), batt_eff, solar_eff, conv_eff, Vmax,
    % k1, k2, k3, k4 ,k5 ,k6 ,k7 ,k8

    T_orbit = 92;                   %Total orbit divisions
    % t_tick = 1;                   %Filter update rate (per min)
    batt_eff = 0.85;
    solar_eff = 0.92;
    conv_eff = 0.955;
    
    Vmax = 16.6;
    
    % Array method re organization from variable based to state based
    for m = 1:92
        State(m).P_solar = tState.P_solar(m+T_orbit);
        State(m).batt_E = tState.batt_E(m);
        State(m).inc_I = tState.inc_I(m);
        State(m).batt_I = tState.batt_I(m);
        State(m).batt_V = tState.batt_V(m);
        State(m).load_I = tState.load_I(m);
    end
    
    %Test Variables
    % testResults, powerStats
    powerStats = zeros(1,T_orbit);  %Returns Average energy per interval
    
    
    wasted = zeros(1,T_orbit);
    
    % Weight Coefficients
    % k1 Balance between measured, and derived value of power wasted
	  k1 = 0.95;
    % k2 Balance between measured, and derived value of battery energy
      k2 = 0.8;
    % k3 Weight for the effect of battery energy measured vs estimated
      k3 = 0.2;
    % k4 Weight for the effect of average battery measurement vs norm.
      k4 = 0.25;
    % k5 Coefficent determining the normal battery operation level
      k5 = 0.90 * 2.6 * 3600 * 16.1;
    % k6 Coefficent to control the responsivness based on under use
      k6 = 0.9;
    % k7 Coefficient to control the reponsivness based on over use
      k7 = 0.9;
    % k8 Controls the response to the accuracy of last power prediciton
      k8 = 0.1;

    stat1 = [];
    stat2 = [];
    stat3 = [];
    stat4 = [];
    stat5 = [];
    stat6 = [];
    stat7 = [];
    stat8 = [];
    
    % Initializing tracking of energy - should make a determination on the
    % first pass of the filter and track from there, this would be a calc
    % to determine capacity from voltage
    curr_Energy = 2.6 * 3600 * 16.6;
    
    %This is ideal, will need to dynamically keep track of max battery capacity
    Full_Charge = 2.6 * 3600 * 16.6;
    
    %-----------------------updateFilter()---------------------------------
    % emulates updates every tick (orbit fraction)
    for i = 1:T_orbit
        % Deriving solar voltage for power wasted, this is a value that can
        % be called directly from the satellite rather than derived
        V_solar = State(i).P_solar / State(i).inc_I;
        
        % Battery current is always positive data, determining wether or
        % not the battery is charging or discharging
        if State(i).load_I > State(i).inc_I
            State(i).batt_I = State(i).batt_I * -1;
        end

        % Battery current is the line to the battery, derived in sim,
        % called directly from the satellite in actual case.
        
        % Check solar power for wasted input to determine current state
        % currentDraw:  all current drawn by the system.  Ideal case use -
        % current drawn by load + all reamining currentIn into battery
        currentDraw = State(i).load_I + State(i).batt_I;
        % currentIn: can be directly called from system rather than
        % derived, value from system does not need efficiency modifier
        currentIn = -(State(i).P_solar .* solar_eff /...
            State(i).batt_V);

        if V_solar >= 16 && currentDraw + currentIn < 0
            wasted(i) = State(i).batt_V * -(currentIn + currentDraw);
            if i > 1
                State(i).P_solar = State(i-1).P_solar;
            end
        end
    end
    P_wasted = sum(wasted)/T_orbit;
    
    %----------------------End of updateFilter()-----------------------
    
    %Get Average Energy and Power for last orbit
    P_solar_avg = lastPower;
    for i = 1:length([State.P_solar])
        P_solar_avg = P_solar_avg * ((T_orbit-1)/T_orbit) + ...
            State(i).P_solar * solar_eff * 1/T_orbit;
        test = State(i).P_solar;
    end
    
    E_bat_meas_avg = sum([State.batt_E])/T_orbit;
    
    %---------------------- Battery Control ---------------------------
    % Energy control (Like power wasted for Energy)
    % Checking the discrepency between energies to find a Next orbit
    % modifier, P_est is being assumed as what is being used and not
    % what the other half of the program would return as used
    E_dis = curr_Energy + (sum([State.P_solar] * 60 * solar_eff) - ... 
        lastPower*60*T_orbit/conv_eff) * batt_eff;
    overdrawn_mod = 0;
    
    % Determines if energy was overspent and converts that
    % value into an orbital power correction.
    if E_dis < Full_Charge
        overdrawn_mod = (E_dis - Full_Charge)/(T_orbit * 60);
    end
    
    % Updates current energy as well as imposes physical limits of the
    % battery on the calculated value.  Wasted amounts of energy are
    % accounted for in overdrawn_mod.
    curr_Energy = E_dis;
    if curr_Energy > 155376
        % Physical limitation of 2.6 Ah in J
        curr_Energy = 155376;
    elseif curr_Energy < 0
        % Physical limitation of no energy
        curr_Energy = 0;
    end
    %------------------------------------------------------------------
    
    % P_est update
    % Equation is counter to Kalman filter documentation, using mean
    % instead of max of solar power
    P_wasted = k1 * P_wasted + (1 - k1) * (mean([State.P_solar])*solar_eff - ...
        lastPower);
    E_bat_meas = State(T_orbit).batt_E;
    E_bat_est = k2 * E_bat_meas + (1-k2) * curr_Energy;
    
    % Last Orbit comparison for how close the prediction was
    Accuracy_mod = P_solar_avg - lastPower;
    
    % Dividing energy estimates by T_orbit*60 so they become power as these are
    % energy estimates per orbit
    P_est = P_solar_avg + k3 * (E_bat_meas - E_bat_est)/(T_orbit*60) ...
        + k4 * (E_bat_meas_avg - k5)/(T_orbit*60) + k6* P_wasted + ...
        k7 * overdrawn_mod + k8 * Accuracy_mod;
    
    % Correction for negative value.
    if P_est < 0
        P_est = 0;
    end
    
    % ------------------------ Testing output --------------------------
    stat1 = [stat1 P_solar_avg];
    stat2 = [stat2 k3 * (E_bat_meas - E_bat_est)/(T_orbit*60)];
    stat3 = [stat3 k4 * (E_bat_meas - k5)/(T_orbit*60)];
    stat4 = [stat4 E_bat_meas/(T_orbit*60)];
    stat5 = [stat5 E_bat_est/(T_orbit*60)];
    stat6 = [stat6 k6 * P_wasted];
    stat7 = [stat7 k7 * overdrawn_mod];
    stat8 = [stat8 k8 * Accuracy_mod];
    
    testResults(1) = stat1;
    testResults(2) = stat2;
    testResults(3) = stat3;
    testResults(4) = stat6;
    testResults(5) = stat7;
    
    
    sprintf(strcat('P_solar_avg:             %f\nE_bat_meas - E_bat_est: %f\nE_bat_meas - Average:   %f\n', ...
        'E_bat_meas:              %f\nE_bat_est:               %f\nPower wasted:            %f\n', ...
        'Overdrawn Mod:           %f\nAccuracy Mod:            %f\nP_est:                   %f\n'), ...
        stat1(end),stat2(end),stat3(end),stat4(end),stat5(end),stat6(end),stat7(end),stat8(end),P_est)
    % ------------------------------------------------------------------
end