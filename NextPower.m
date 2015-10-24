function [AOAPE] = NextPower(State, lastAOAPE, orbit)

    % See the update function for required variables
    % Initialize Output, start with an expected power to minimized ripple
    % The orbit should be whole divisions of State to utilze all
    % information; however, it is not required to run

    T_orbit = orbit;					%Total orbit divisions
    t_tick = 1;                         %Filter update rate (per min)
    P_wasted = zeros(1,T_orbit);
    n = T_orbit;
    
    % Weight Coefficients
    % k1 Balance between measured, and derived value of power wasted
	  k1 = 0.95;
    % k2 Balance between measured, and derived value of battery energy
      k2 = 0.8;
    % k3 Weight for the effect of battery energy measured vs estimated
      k3 = 0.15;
    % k4 Weight for the effect of average battery measurement vs norm.
      k4 = 0.15;
    % k5 Coefficent determining the normal battery operation level
      k5 = 0.83 * 2.6 * 3600 * 16.1;
    % k6 Coefficent to control the responsivness based on previous output
      k6 = 0.5;
    % k7 Controls the response to accuracy of last power prediction
      k7 = 0.5;
      
    curr_Energy = 2.6 * 3600 * 16.6;

    %-----------------------updateFilter()-----------------------------
    for i = 1:T_orbit
        allState(i).P_solar     = State.P_solar(i);
        allState(i).batt_V      = State.batt_V(i);
        allState(i).batt_I      = State.batt_I(i);
        allState(i).load_I      = State.load_I(i);
        allState(i).energyIn    = State.energyIn(i);
        allState(i).energyOut   = State.energyOut(i);
        allState(i).inc_I       = State.inc_I(i);
        allState(i).temp        = State.temp(i);
    end
    %----------------------End of updateFilter()-----------------------
        
    % Testing output
    stat1 = [];
    stat2 = [];
    stat3 = [];
    stat4 = [];
    stat5 = [];
    stat6 = [];
    stat7 = [];
    stat8 = [];
    
    % Control Loop
    for orbit = 1:lower(length(State.batt_V)/T_orbit)-1
        %Get Average Energy and Power for last orbit
        P_solar_avg = sum([allState.P_solar])/T_orbit;
        charge = LGetChargeWRTVoltage(allState);
        E_bat_meas_avg = sum([charge])/T_orbit*3600 * allState(T_orbit).batt_V;
        
        %---------------------- Battery Control ---------------------------
        % Energy control (Like power wasted for Energy)
        % Checking the discrepency between energies to find a Next orbit
        % modifier, AOAPE is being assumed as what is being used and not
        % what the other half of the program would return as used
        E_dis = curr_Energy + sum([allState.energyIn]) - ... 
            sum([allState.energyOut]);
        NO_mod = 0;
        Full_Charge = 2.6 * 3600 * 16.6 * 0.96;     % 0.96 = 96% Charge
        % Determines how much energy was wasted/overspent and converts that
        % value into an orbital power correction.
        if E_dis >= Full_Charge
            NO_mod = (E_dis - curr_Energy)/(T_orbit * 60);
        elseif E_dis < Full_Charge
            NO_mod = (E_dis - Full_Charge)/(T_orbit * 60);
        end 
        
        % Updates current energy as well as imposes physical limits of the
        % battery on the calculated value.  Wasted amounts of energy are
        % accounted for in NO_mod.
        curr_Energy = E_dis;
        if curr_Energy > 155376
            % Physical limitation of 2.6 Ah in J
            curr_Energy = 155376;
        elseif curr_Energy < 0
            % Physical limitation of no energy
            curr_Energy = 0;
        end
        %------------------------------------------------------------------
        
        % AOAPE update
%         P_wasted = k1 * P_wasted + (1 - k1) * (allState(T_orbit).P_solar - ...
%             (allState(T_orbit).batt_V * (allState(T_orbit).load_I - ...
%             allState(T_orbit).inc_I* 0.91)));
        %             No correct data on solar panel voltage/current
        % From funcube, >12v is a good point to show that sunlight is
        % shining on the solar panels
        E_bat_meas = LGetChargeWRTVoltage(allState(T_orbit))*3600*...
            allState(T_orbit).batt_V;
        E_bat_est = k2 * E_bat_meas + (1-k2) * (curr_Energy + ... 
            sum([allState.energyIn]) - sum([allState.energyOut]));
        
        % Last Orbit comparison for how close the prediction was
        LO_mod = P_solar_avg - lastAOAPE;
        stat8 = [stat8 LO_mod];
        
        % Dividing energy estimates by T_orbit*60 so they become power as these are
        % energy estimates per orbit
        AOAPE = [AOAPE P_solar_avg + k3 * (E_bat_meas - E_bat_est)/(T_orbit*60) ...
            + k4 * (E_bat_meas_avg - k5)/(T_orbit*60) + NO_mod * k6 + LO_mod *k7];
        
        % Testing output
        stat1 = [stat1 P_solar_avg];
        stat2 = [stat2 k3 * (E_bat_meas - E_bat_est)/(T_orbit*60)];
        stat3 = [stat3 k4 * (E_bat_meas - k5)/(T_orbit*60)];
        
        stat4 = [stat4 E_bat_meas/(T_orbit*60)];
        stat5 = [stat5 E_bat_est/(T_orbit*60)];
        stat6 = [stat6 NO_mod];
        stat7 = [stat7 E_bat_meas_avg];
        
%         sprintf(strcat('P_solar_avg:             %f\nE_bat_meas - E_bat_est: %f\nE_bat_meas - Average:   %f\n', ...
%             'E_bat_meas:              %f\nE_bat_est:               %f\nNO_mod:                  %f\n', ...
%             'LO_mod:                  %f\nAOAPE:                   %f\n'), ...
%             stat1(end),stat2(end),stat3(end),stat4(end),stat5(end),stat6(end),stat8(end),AOAPE(end))

    end
end