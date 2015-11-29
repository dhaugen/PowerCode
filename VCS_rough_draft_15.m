%{
    Component List:
    - GPS.......................... Global Positioning System
    - P31us ----------------------- EPS
    - Nanomind ....................
    - Nanohub ---------------------
    - UHF_Rx ...................... Ultra High Frequency (Receiver)
    - UHF_Tx ---------------------- Ultra High Frequency (Transmitter)
    - Active_THCS ................. Battery Heater
    - Magnetometer ---------------- DFGM (Digital Fluxgate Magnetometer)
    - mNLP_Operational ........... Multi-Needle Langmuir Probe
    - mNLP_Standby ---------------- Multi-Needle Langmuir Probe
    - SSADCS_ARE ..................
    - SSADCS_AFSE -----------------
    - SSADCS_Detumble .............
    - SSADCS_YMC_Eclipse ----------
    - SSADCS_YMC_Daylight .........
    - Teledyne -------- Micro Dosimeter, Low Power Radiation Monitor

    Masses of Components:
    - GPS..........................
    - P31us -----------------------
    - Nanomind ....................
    - Nanohub ---------------------
    - UHF_Rx ......................
    - UHF_Tx ----------------------
    - Active_THCS .................
    - Magnetometer ----------------
    - mNLP_Operational ...........
    - mNLP_Standby ----------------
    - SSADCS_ARE ..................
    - SSADCS_AFSE -----------------
    - SSADCS_Detumble .............
    - SSADCS_YMC_Eclipse ----------
    - SSADCS_YMC_Daylight .........
    - Teledyne -------- 20g
%}

%% Changes in draft 14 (Sep 19, 2015)
%
% Merged with John's solar simulation code by Albert.
%


function [] = VCS_rough_draft_14()

%% ================= DEFINITION OF VARIABLES ==============================
% Initialize
clc;
close all;

% Constants
TRUE = 1;
FALSE = 0;

%% Field Name Cells for Component Characteristic Structure (convenient for looping)
global m; global b;
global s; %*defined later as data-containing structure for components
global component;
m = {'Off_Mode','Safe_Mode','Detumbling_Mode','Active_Mission_Mode','Attitude_Realignment_Mode'};    % modes
b = {'Battery','Regulator_5V','Regulator_3V3'};    % buses
component = {'GPS','P31us','Nanomind','Nanohub','UHF_Rx','UHF_Tx','Active_THCS','DFGM','mNLP_Operational','mNLP_Standby','SSADCS_ARE','SSADCS_AFSE','SSADCS_Detumble','SSADCS_YMC_Eclipse','SSADCS_YMC_Daylight','Teledyne','UofA_OBC'};

%% Obtaining Solar Power In Data from John's Simulation.
firstRun = TRUE;
triggerExit = FALSE;
while TRUE
    clc;
    disp(' ');
    disp('Available Solar Data: ');
    disp(' 1. Dawn-Dusk');
    disp(' 2. Noon-Midnight');
    disp(' 3. Choose inclination')
    disp(' ');
    if firstRun
        userIn = input('Enter option: ','s');
        firstRun = FALSE;
    else
        disp(['Previous entry ''',userIn,''' was invalid.']);
        userIn = input('Enter option (a number from 1 - 2): ','s');
    end
    if strcmpi(userIn,'1') || strcmpi(userIn,'Dawn-Dusk')
        Pin_loadObject = load('data_dawn_dusk.mat');
        time_elapsed = Pin_loadObject.time_elapsed_minutes;
        total = Pin_loadObject.total;
        triggerExit = TRUE;
    elseif strcmpi(userIn,'2') || strcmpi(userIn,'Noon-Midnight')
        Pin_loadObject = load('data_noon_midnight.mat');
        time_elapsed = Pin_loadObject.time_elapsed_minutes;
        total = Pin_loadObject.total;
        triggerExit = TRUE;
    elseif strcmpi(userIn,'3') || strcmpi(userIn,'Choose inclination')
        % Get angle of inclination from user.
        while 1
            clc;
            disp('Angle of incidence must be between 0 and 90 degrees.');
            disp('( 0 = noon-midnight , 90 = dawn-dusk )')
            disp(' ');
            userIn2_str = input('Enter angle: ','s');
            userIn2 = str2double(userIn2_str);
            if isnan(userIn2)
                disp(' ');
                disp(['''',userIn2_str,''' is not a valid input.']);
                disp(' ');
            elseif userIn2 < 0 || userIn2 > 90
                disp(' ');
                disp(['''',userIn2_str,''' is not a valid value for this angle.']);
                disp(' ');
            else
                triggerExit = TRUE;
                break
            end
        end
        % Extra orbital period is added as a precautionary measure.
        % Gets data for 100 orbits.
        [time_elapsed,total] = incident_solar_power(userIn2,92,101*92,1);
    end
    if triggerExit
        break
    end
end

% Linearly interpolate integer minute values for Pin.
Pin_perMinute = perMinute_approx(time_elapsed,total);
total = Pin_perMinute.total;
pause(0.75);

%% Electrical Systems Characteristics
global Vmax;    global Vnorm;
global Vsafe;   global Vcrit;

% Obtaining Data from Battery_Variable.mat File
BatteryCurves_loadObject = load('Battery_Variable.mat');
DOD = BatteryCurves_loadObject.DOD;
volts = BatteryCurves_loadObject.volts;
global coefficients;
ws = warning('off','all');  % Turn off warning
coefficients = polyfit(DOD,volts,10);
warning(ws);  % Turn it back on.



global Pin_total;
Pin_total = total;

Vmax  = 16.6;    %(volts)
Vnorm = 14.8;    %(volts)
Vsafe = 14.4;    %(volts)
Vcrit = 13.2;    %(volts)

global Photovoltaic_Boost_Converter_Efficiency;
global Regulator_Efficiency_5V;
global Regulator_Efficiency_3V3;
global Battery_Charge_Efficiency;
Photovoltaic_Boost_Converter_Efficiency = 0.92;
Regulator_Efficiency_5V = 0.96;
Regulator_Efficiency_3V3 = 0.95;
Battery_Charge_Efficiency = 0.85;

global V_bat; global V_bus1; global V_bus2;
V_bat = Vnorm;   %(volts)
V_bus1 = 5;     %(volts)
V_bus2 = 3.3;   %(volts)

%% Component Characteristics

% Current Drawn from Individual Buses (amps)
% Cell array b defined under "Field Names"

% Component                                 Battery         5V Reg.         3.3V Reg.
s.GPS.I                  =  struct(b{1},    0       ,b{2},  0       ,b{3},  0.30303     ); % novatel oem615 gps
s.P31us.I                =  struct(b{1},    0       ,b{2},  0       ,b{3},  0.037879    );
s.Nanomind.I             =  struct(b{1},    0       ,b{2},  0       ,b{3},  0.139       );
s.Nanohub.I              =  struct(b{1},    0       ,b{2},  0       ,b{3},  0.005       );
s.UHF_Rx.I               =  struct(b{1},    0       ,b{2},  0       ,b{3},  0.07        ); % new antenna values
s.UHF_Tx.I               =  struct(b{1},    0       ,b{2},  0       ,b{3},  1.515152    );
s.Active_THCS.I          =  struct(b{1},    0       ,b{2},  1.4     ,b{3},  0           ); % 15V across 14 ohm resistor. Pulls 7W from 5V reg. I = P/V
s.DFGM.I                 =  struct(b{1},    0       ,b{2},  0.08    ,b{3},  0           );
s.mNLP_Operational.I     =  struct(b{1},    0       ,b{2},  0.12    ,b{3},  0.075758    );
s.mNLP_Standby.I         =  struct(b{1},    0       ,b{2},  0.03    ,b{3},  0.054545    ); % new icd - issue 4
s.SSADCS_ARE.I           =  struct(b{1},    0       ,b{2},  0       ,b{3},  0.102       ); % surrey space
s.SSADCS_AFSE.I          =  struct(b{1},    0       ,b{2},  0.023   ,b{3},  0.102       );
s.SSADCS_Detumble.I      =  struct(b{1},    0       ,b{2},  0.036   ,b{3},  0.102       );
s.SSADCS_YMC_Eclipse.I   =  struct(b{1},    0.009   ,b{2},  0.01    ,b{3},  0.102       );
s.SSADCS_YMC_Daylight.I  =  struct(b{1},    0.009   ,b{2},  0.048   ,b{3},  0.102       );
s.Teledyne.I             =  struct(b{1},    0       ,b{2},  0       ,b{3},  0           );
s.UofA_OBC.I             =  struct(b{1},    0       ,b{2},  0       ,b{3},  0.139       );

%% Assumptions
Cmax = 2.6*60*Vnorm; %Obtaining the maximum capacity (watt-minutes)
Orbital_Period = 92; %(minutes) ; This value is only used to generate the
%graph boundaries (visuals only)

%% General Variables
global mode; % Defines mode of satelite.

x_res = 1;      %(minutes)
x_start = 1;    %(minutes)
% Get number of orbits in order to obtain x_end.
while 1
    x_end = input('Simulate for how many orbits (Max: 185)? ','s');     %(minutes)
    x_end = str2double(x_end);
    if isnan(x_end)
        disp(' ');
        disp('Invalid input');
        disp(' ');
    else
        break
    end
end

if x_end > 185
    disp('Requested simulation length extends beyond available data.');
    disp('Simlation shortened to 185 orbits.');
    x_end = 185;
end
x_end = x_end * Orbital_Period;

C_init = Cmax; % (watt-minutes)
P_est_init = 2.0; % Initial power estimate (KI filter) is set to 6.5W

%% ======= CALCULATIONS ==============================
% Generate initial duty cycle schedule
global DDC;
DDC = Interperet_DC(P_est_init);

% Creates time vector for graphing
X_t = (x_start : x_res : x_end);
if X_t(length(X_t)) < x_end
    X_t = [X_t, X_t(length(X_t) + x_res)];
end

% Calculates number of points on x-axis
Data_Points = numel(X_t);

% Creates voltage vector (V)
% Note: Impossible to determine battery voltage from capacity without
%       having any current draw/input. Therefore, Y_v(1) [initial voltage]
%       is ignored and is set to equal Y_v(2) [voltage at second time
%       step, or "tick". To find the line of code which does this, search
%       "FLAG_1".
Y_v = zeros(1,Data_Points);
DOD = 100 - (C_init/Cmax * 100);
Y_v(1) = determine_voltage(DOD);

% Sets initial mode based on initial battery voltage
mode = 'Active_Mission_Mode';
mode = determine_mode(Y_v(1),mode);

% Creates and assignsx initial value: current vector (A)
Y_i = zeros(1,Data_Points);
Y_i(1) = calculate_current(1,Y_v(1));

% Creates and assigns initial value: power vector (W)
Y_p = zeros(1,Data_Points);

% Creates and assigns initial value: capacity vector (watt-minutes)
Y_c = zeros(1,Data_Points);
Y_c(1) = C_init;

% Creates y-vector for P_est (output of Kalman Filter).
Y_P_est = zeros(1,Data_Points);

% Creates y-vector for power in from solar cells.
P_in = zeros(1,Data_Points);

% Creates y-vector for power needed by load.
P_out = zeros(1,Data_Points);


% Loops through time vector from (x_start) minutes to (x_end) minutes with
% intervals of (x_res) minutes. Assigns values for voltage, current, power,
% and capacity vectors, as well as the mode.

%% MAIN LOOP -------------------------------------
firstRun = TRUE;
lastPower = 2.0; % W
n = 2;
while n <= length(X_t) + 1
    if firstRun
        P_est = lastPower;
        for m = 1:92
            Y_P_est(m) = P_est;
        end
        firstRun = FALSE;
    else
        if ~rem(n-1,92)
            %%%%%% KALMAN FILTER
            % Get estimated power
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% P_est = total(n+1);
            try
                clear('inputArray');
                clear('subArray');
            catch         
            end
            
            % Information preparation for transfer to C coded filter
            % Values must be converted to x10^-3/x10^-6
            inputArray.P_solar = total(n-92:n-1);
            inputArray.batt_E = Y_c(n-92:n-1) * 60 / x_res;
            inputArray.inc_I = total(n-92:n-1) * 0.92 ./ Y_v(n-92:n-1);
            inputArray.batt_I = abs(Y_i(n-92:n-1) - inputArray.inc_I);
            inputArray.batt_V = Y_v(n-92:n-1);
            inputArray.load_I = Y_i(n-92:n-1);
            
            %Theodore - testing nextpower c code begins here. Above was old function,
            %commented out. This currently crashes Matlab.
            
            [~,P_est] = NextPower(inputArray.batt_E, inputArray.P_solar, inputArray.inc_I, inputArray.load_I, inputArray.batt_I, inputArray.batt_V, lastPower, Orbital_Period);
            disp(['P_est sent into Interperet_DC = ',num2str(P_est)]);%###
            disp(['n = ',num2str(n)]);
            disp(['P_est = ',num2str(P_est)]); %###
            %End testing c code here
            
            %             if 40 > (n-1)/92 && (n-1)/92 >= 20
            %                 P_est = P_est * 0.9;
            %             elseif 60 > (n-1)/92 && (n-1)/92 >= 40
            %                 P_est = P_est * 1.2;
            %             elseif (n-1)/92 >= 60
            %                 P_est = P_est * 1.7;
            %             end
            
            for m = n:n+91
                Y_P_est(m) = P_est;
            end
            lastPower = P_est;
        end
    end
    if n > length(X_t)
        break
    end
    %%%%%%
    %disp(['P_est sent into Interperet_DC = ',num2str(P_est)]);%###
    DDC = Interperet_DC(P_est);
    
    Y_c(n) = Y_c(n-1) + (net_power(n) * x_res);
    if Y_c(n) <= 0
        Y_c(n) = 0;
    elseif Y_c(n) >= Cmax
        Y_c(n) = Cmax;
    end
    
    DOD = 100 - (Y_c(n) / Cmax * 100);
    
    %Y_v(n) = determine_voltage(cap_in_Ah,discharge_rate);
    Y_v(n) = determine_voltage(DOD);
    mode = determine_mode(Y_v(n),mode);
    
    [Y_p(n) , P_in(n) , P_out(n)] = net_power(n);
    
    Y_i(n) = calculate_current(n, Y_v(n));
    
    if rem(n,500) == 0
        disp(' ');
        disp(' ');
        disp(['Progress: ',num2str(n/x_end*100),'%']);
    end
    
    %{
    disp(['Mode: ',mode]);
    disp(['V   : ',num2str(Y_v(n))]);
    disp(['C   : ',num2str(Y_c(n))]);
    disp(['DR  : ',num2str(discharge_rate)]);
    disp(' ');
    %}
    
    % TESTING PURPOSES (end)
    n = n + 1;
end

% Smooth out graph (FLAG_1)
Y_v(1) = Y_v(2);
Y_i(1) = Y_i(2);

%% END MAIN LOOP ---------------------------------

%% Display
while 1
    clc;
    disp('Graph options:');
    disp('1. Capacity');
    disp('2. Voltage');
    disp('3. Current');
    disp('4. Solar Power In and P_est');
    disp('5. Power used by load (W)');
    disp(' ');
    graphOption = input('What would you like to display?  ','s');
    if strcmp(graphOption,'1')
        % Display Capacity
        clf;
        Y_1 = ones(1,length(X_t))*2.6;
        Y_2 = Y_1*0.9;
        Y_c = Y_c/60/Vnorm;
        plot(X_t,Y_1,'r',X_t,Y_2,'g',X_t,Y_c,'b');
        legend('Maximum Capacity (2.6Ah)','10% DOD (2.34Ah)','Battery Capacity','location','southeast')
        ylabel('Capacity (Ah)');
        xlabel('Time Elapsed (minutes)');
        title('Capacity of Battery vs. Time Elapsed');
        axis([x_start,x_end,1,2.8]);
    elseif strcmp(graphOption,'2')
        % Display Voltage
        clf;
        Y_1 = ones(1,length(X_t))*Vmax;
        Y_2 = ones(1,length(X_t))*Vnorm;
        Y_3 = ones(1,length(X_t))*Vsafe;
        Y_4 = ones(1,length(X_t))*Vcrit;
        plot(X_t,Y_1,'g',X_t,Y_2,'g',X_t,Y_3,'y',X_t,Y_4,'r',X_t,Y_v,'b');
        text(x_start,Vmax,' Vmax','VerticalAlignment','bottom');
        text(x_start,Vnorm,' Vnorm','VerticalAlignment','bottom');
        text(x_start,Vsafe,' Vsafe','VerticalAlignment','bottom');
        text(x_start,Vcrit,' Vcrit','VerticalAlignment','bottom');
        ylabel('Voltage (V)');
        xlabel('Time Elapsed (minutes)');
        title('Battery Voltage vs. Time Elapsed');
        axis([x_start,x_end,13,17]);
    elseif strcmp(graphOption,'3')
        % Display Current
        clf;
        plot(X_t,Y_i,'b');
        ylabel('Output Current (A)');
        xlabel('Time Elapsed (minutes)');
        title('Load Current vs. Time Elapsed');
        axis([x_start,x_end,0,4]);
    elseif strcmp(graphOption,'4')
        % Display Solar Power In
        clf;
        hold on;
        plot(X_t,total(1:numel(X_t)));
        xlabel('Time Elapsed (minutes)');
        ylabel('Power (W)');
        title('Incoming Solar Power (before Boost Converters)');
        axis([x_start,x_end,0,8]);
        % Display P_est
        plot(X_t,Y_P_est(1:numel(X_t)));
        title('Predicted Power Estimate');
        legend('Solar Power In','P_e_s_t');
    elseif strcmp(graphOption,'5')
        % Display P_out
        clf;
        plot(X_t,P_out);
        axis([0 inf 0 10]);
        xlabel('Time Elapsed (minutes)');
        ylabel('Power Consumption (W)');
        title('Power Consumption');
    end
    disp(' ');
    input('Press <enter> to return to menu.','s');
    clc;
    disp('Simulation Complete');
end
end


function [mode] = determine_mode(V, mode,varargin)
% This function takes a voltage as an input variable, and changes the mode
% of the satellite accordingly.
%
% State machine:
%
%            V < Vcrit       V < Vsafe          V < Vmax
%           <-----------    <-----------      <-----------
%       CRITICAL        SAFE            NORMAL          FULL
%           ----------->    ----------->      ----------->
%            V > Vsafe       V > Vnorm          V > Vmax
%
global Vcrit;
global Vnorm;
global Vsafe;
global Vmax;

if length(varargin) == 2
    n = varargin(1);
    t = varargin(2);
end

if V < 0 || V > Vmax
    disp('Invalid voltage.');
    disp(['Voltage = ',num2str(V)]);
elseif strcmp(mode,'Off_Mode') == 1
    if V > Vsafe
        mode = 'Safe_Mode';
    end
elseif strcmp(mode,'Safe_Mode') == 1
    if V < Vcrit
        mode = 'Off_Mode';
    elseif V > Vnorm
        mode = 'Active_Mission_Mode';
    end
elseif strcmp(mode,'Active_Mission_Mode') == 1
    if V < Vsafe
        mode = 'Safe_Mode';
    end
else
    disp('Invalid mode in determine_mode()');
    disp(['mode = ',mode]);
    disp(['n = ',num2str(n)]);
    disp(['t = ',num2str(t)]);
end


%{
OLD FUNCTION
if V < 0
    disp('Error. Negative Voltage.');
    exit;
elseif V <= Vcrit
    mode = 'Off_Mode';
elseif V <= Vsafe
    mode = 'Safe_Mode';
elseif V <= Vmax
    mode = 'Active_Mission_Mode';
else
    disp(['Error. Invalid Voltage (V = ',num2str(V),'V > Vmax).']);
end
%}
end

function [V] = determine_voltage(DOD)
global coefficients;
global Vmax;

V = polyval(coefficients,DOD);
V = V / 4.2 * Vmax;

return

Vmax  = 16.6; % V
Vnorm = 14.8; % V
Vsafe = 14.4; % V
Vcrit = 13.2; % V

Cmax  = 2.6; % Ah
Cdata = 1.6; % Ah
x_factor = Cmax/Cdata;  % unitless

Vdata = 3.9;  % V
y_factor = Vmax/Vdata; % unitless

rate_x{1}  = x_factor * [1.1461,1.1406,1.1336,1.1281,1.1202,1.1085,1.0928,1.0787,1.0607,1.0426,1.0238,1.0019,0.9815,0.9548,0.9258,0.8733,0.8333,0.7933,0.7588,0.7196,0.6891,0.6134,0.5429,0.4715,0.4073,0.3481,0.3018,0.2524,0.1928,0.1537,0.1290,0.0976,0.0800,0.0655,0.0478,0.0333,0.0220,0.0110,0.0051];
rate_y{1}  = y_factor * [1.4188,1.5063,1.6,1.6625,1.7313,1.8062,1.8875,1.9438,1.9813,2.025,2.0562,2.0812,2.1125,2.1313,2.1563,2.1875,2.2062,2.2313,2.2563,2.2813,2.3,2.3656,2.4281,2.5031,2.5719,2.6437,2.7094,2.7687,2.85,2.9375,2.9906,3.0562,3.0781,3.1125,3.1688,3.2156,3.275,3.3469,3.4];
rate_x{2}  = x_factor * [1.228,1.2205,1.2114,1.2054,1.1979,1.1859,1.1739,1.1574,1.1364,1.1139,1.0659,1.0239,0.98343,0.94294,0.88446,0.82597,0.79298,0.7225,0.68051,0.61902,0.56654,0.51405,0.46306,0.41207,0.37008,0.33558,0.30859,0.2801,0.2486,0.21561,0.18111,0.16311,0.14361,0.10462,0.065622,0.0028134];
rate_y{2}  = y_factor * [1.4115,1.6136,1.8021,1.9098,2.0041,2.1252,2.2195,2.2867,2.3539,2.3806,2.4206,2.4607,2.4873,2.5139,2.5404,2.5668,2.58,2.6333,2.6464,2.6998,2.7398,2.7932,2.8332,2.9002,2.9402,2.9938,3.0071,3.0338,3.0874,3.1141,3.2081,3.2753,3.3021,3.3691,3.4227,3.6148];
rate_x{5}  = x_factor * [1.276,1.274,1.272,1.268,1.265,1.259,1.253,1.245,1.237,1.228,1.217,1.207,1.188,1.169,1.147,1.124,1.11,1.071,1.038,1.0111,0.97608,0.89512,0.82616,0.78819,0.72722,0.67925,0.63427,0.5873,0.54332,0.49834,0.45336,0.41438,0.3834,0.34642,0.31443,0.28245,0.25846,0.23447,0.21448,0.19848,0.1715,0.14651,0.11252,0.086535,0.056549,0.036557,0.017564,0.0045649];
rate_y{5}  = y_factor * [1.376,1.463,1.5825,1.7129,1.8215,1.941,2.0496,2.1691,2.2777,2.3645,2.4404,2.4946,2.527,2.5376,2.5591,2.5696,2.5803,2.645,2.6663,2.6876,2.7198,2.7513,2.783,2.8042,2.836,2.857,2.889,2.921,2.9639,3.0068,3.0605,3.1034,3.1356,3.1786,3.2108,3.2321,3.2644,3.3184,3.3833,3.4157,3.448,3.4694,3.5233,3.5772,3.6203,3.6527,3.6959,3.7609];
rate_x{10} = x_factor * [1.4278,1.4232,1.4187,1.4156,1.411,1.4065,1.3989,1.3897,1.3821,1.373,1.3638,1.3486,1.3227,1.2983,1.2678,1.2465,1.219,1.1947,1.1657,1.1322,1.0682,1.0149,0.97067,0.928,0.9021,0.85029,0.81067,0.75886,0.72381,0.68267,0.64,0.60343,0.55771,0.512,0.46781,0.42362,0.39619,0.36419,0.33219,0.29867,0.26514,0.23924,0.21486,0.20267,0.17219,0.13562,0.1021,0.07619,0.048762,0.021333,0.0030476];
rate_y{10} = y_factor * [1.5522,1.6946,1.837,1.9367,2.0222,2.1076,2.2073,2.307,2.3924,2.4636,2.5206,2.5918,2.6203,2.6203,2.6345,2.6345,2.6772,2.7057,2.7342,2.7627,2.7911,2.8054,2.8196,2.8339,2.8481,2.8623,2.8908,2.9051,2.9193,2.9478,2.9763,3.0047,3.0617,3.1187,3.1614,3.2041,3.2326,3.2753,3.2896,3.3038,3.3323,3.3892,3.432,3.4747,3.5032,3.5459,3.5886,3.6171,3.6598,3.7025,3.788];
rate_x{15} = x_factor * [1.5028,1.5013,1.4982,1.4952,1.4921,1.4874,1.4844,1.4797,1.4782,1.4705,1.4628,1.4551,1.4412,1.4288,1.418,1.3995,1.3779,1.3578,1.3053,1.2759,1.2373,1.2065,1.174,1.1493,1.1107,1.0675,1.015,0.9609,0.91303,0.86206,0.81573,0.78176,0.74161,0.70763,0.68292,0.65513,0.62578,0.60108,0.56401,0.54548,0.51769,0.47599,0.4204,0.38797,0.3401,0.29995,0.2598,0.2212,0.1934,0.15634,0.12546,0.088395,0.057513,0.02354,0.0019275];
rate_y{15} = y_factor * [1.3524,1.4712,1.6049,1.7238,1.8277,1.902,1.9763,2.0655,2.1101,2.1992,2.2884,2.3627,2.4817,2.5412,2.5859,2.6306,2.6308,2.631,2.6463,2.6911,2.7361,2.766,2.7812,2.7963,2.8115,2.8119,2.8272,2.8426,2.8579,2.8732,2.9033,2.9185,2.9337,2.9637,2.964,2.9939,3.0239,3.0538,3.0839,3.1138,3.1437,3.1887,3.2337,3.2637,3.2939,3.324,3.4134,3.4881,3.5032,3.5481,3.5929,3.6378,3.6975,3.7424,3.8317];

if (DR - 1) < 0.05 || (DR - 2) < 0.05 || (DR - 5) < 0.05 || (DR - 10) < 0.05 || (DR - 15) < 0.05
    % If DR is close enough to one of our data sets (DR = 1,2,5,10,15)
    
    % Corrections
    if (DR - 1) < 0.05
        DR = 1;
    elseif (DR - 2) < 0.05
        DR = 2;
    elseif (DR - 5) < 0.05
        DR = 5;
    elseif (DR - 10) < 0.05
        DR = 10;
    elseif (DR - 15) < 0.05
        DR = 15;
    end
    
    % If battery is full, V = maximum V for that curve.
    if C == 0
        V = rate_y{DR}(end);
        if V < 0
            V = 0;
        elseif V > Vmax
            V = Vmax;
        end
        return
    end
    
    % Otherwise, find x points which surround our C
    n = 1;
    while n <= length(rate_x{DR})
        if C > rate_x{DR}(n)
            break
        end
        n = n + 1;
        if n > length(rate_x{DR})
            V = rate_y{DR}(end);
            return
        end
    end
    
    % Linear approximation using point slope form of two
    % surrounding points.
    
    x1 = rate_x{DR}(n);
    x2 = rate_x{DR}(n+1);
    y1 = rate_y{DR}(n);
    y2 = rate_y{DR}(n+1);
    
    V = ((y2-y1)/(x2-x1))*(C-x1) + y1;
    if V < 0
        V = 0;
    elseif V > Vmax
        V = Vmax;
    end
    return
    
elseif DR > 1 && DR < 2
    % Linearly approximate for DR = 1
    n = 1;
    while n <= length(rate_x{1})
        if C > rate_x{1}(n)
            break
        end
        n = n + 1;
    end
    if n >= length(rate_x{1})
        V1 = rate_y{1}(end);
    else
        x1 = rate_x{1}(n);
        x2 = rate_x{1}(n+1);
        y1 = rate_y{1}(n);
        y2 = rate_y{1}(n+1);
        
        V1 = ((y2-y1)/(x2-x1))*(C-x1) + y1;
    end
    % Linearly approximate for DR = 2
    n = 1;
    while n <= length(rate_x{2})
        if C > rate_x{2}(n)
            break
        end
        n = n + 1;
    end
    if n >= length(rate_x{2})
        V2 = rate_y{2}(end);
    else
        x1 = rate_x{2}(n);
        x2 = rate_x{2}(n+1);
        y1 = rate_y{2}(n);
        y2 = rate_y{2}(n+1);
        
        V2 = ((y2-y1)/(x2-x1))*(C-x1) + y1;
    end
    % Linearly approximate wrt. DR
    V = ((V2-V1)/(2-1))*(DR-1) + V1;
    
elseif DR > 2 && DR < 5
    % Linearly approximate for DR = 2
    n = 1;
    while n <= length(rate_x{2})
        if C > rate_x{2}(n)
            break
        end
        n = n + 1;
    end
    if n >= length(rate_x{2})
        V1 = rate_y{2}(end);
    else
        x1 = rate_x{2}(n);
        x2 = rate_x{2}(n+1);
        y1 = rate_y{2}(n);
        y2 = rate_y{2}(n+1);
        
        V1 = ((y2-y1)/(x2-x1))*(C-x1) + y1;
    end
    
    % Linearly approximate for DR = 5
    n = 1;
    while n <= length(rate_x{5})
        if C > rate_x{5}(n)
            break
        end
        n = n + 1;
    end
    if n >= length(rate_x{5})
        V2 = rate_y{5}(end);
    else
        x1 = rate_x{5}(n);
        x2 = rate_x{5}(n+1);
        y1 = rate_y{5}(n);
        y2 = rate_y{5}(n+1);
        
        V2 = ((y2-y1)/(x2-x1))*(C-x1) + y1;
    end
    
    % Linearly approximate wrt. DR
    V = ((V2-V1)/(5-2))*(DR-2) + V1;
    
elseif DR > 5 && DR < 10
    % Linearly approximate for DR = 5
    n = 1;
    while n <= length(rate_x{5})
        if C > rate_x{5}(n)
            break
        end
        n = n + 1;
    end
    if n >= length(rate_x{5})
        V1 = rate_y{5}(end);
    else
        x1 = rate_x{5}(n);
        x2 = rate_x{5}(n+1);
        y1 = rate_y{5}(n);
        y2 = rate_y{5}(n+1);
        
        V1 = ((y2-y1)/(x2-x1))*(C-x1) + y1;
    end
    
    % Linearly approximate for DR = 10
    n = 1;
    while n <= length(rate_x{10})
        if C > rate_x{10}(n)
            break
        end
        n = n + 1;
    end
    if n >= length(rate_x{10})
        V2 = rate_y{10}(end);
    else
        x1 = rate_x{10}(n);
        x2 = rate_x{10}(n+1);
        y1 = rate_y{10}(n);
        y2 = rate_y{10}(n+1);
        
        V2 = ((y2-y1)/(x2-x1))*(C-x1) + y1;
    end
    
    % Linearly approximate wrt. DR
    V = ((V2-V1)/(10-5))*(DR-5) + V1;
    
elseif DR > 10 %&& DR < 15
    % Linearly approximate for DR = 10
    n = 1;
    while n <= length(rate_x{10})
        if C > rate_x{10}(n)
            break
        end
        n = n + 1;
    end
    if n >= length(rate_x{10})
        V1 = rate_y{10}(end);
    else
        x1 = rate_x{10}(n);
        x2 = rate_x{10}(n+1);
        y1 = rate_y{10}(n);
        y2 = rate_y{10}(n+1);
        
        V1 = ((y2-y1)/(x2-x1))*(C-x1) + y1;
    end
    
    % Linearly approximate for DR = 15
    n = 1;
    while n <= length(rate_x{15})
        if C > rate_x{15}(n)
            break
        end
        n = n + 1;
    end
    if n >= length(rate_x{15})
        V2 = rate_y{15}(end);
    else
        x1 = rate_x{15}(n);
        x2 = rate_x{15}(n+1);
        y1 = rate_y{15}(n);
        y2 = rate_y{15}(n+1);
        
        V2 = ((y2-y1)/(x2-x1))*(C-x1) + y1;
    end
    
    % Linearly approximate wrt. DR
    V = ((V2-V1)/(15-10))*(DR-10) + V1;
    
elseif DR < 0
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %
    %  Author: Albert Martino
    %  Data fitted by: Grace Yi
    %  Last Modified: January 23, 2015
    %  Original file: generate_CS_bat_charging_voltage_curve.m
    %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    %
    % Data for battery voltage was obtained from ClydeSpace battery
    % user manual, page 23. Data was compiled from multiple graphs.
    %
    % The ClydSpace Battery Manual can be found at:
    % OneDrive >> AlbertaSat - Power >> Component Datasheets >>
    % >> CS >> Clyde Space Battery User Manual
    %
    %
    % Major Assumption:
    %  - In the ClydeSpace graph, we can clearly see that when the
    %    battery is charging, the current is constant. From this
    %    we can infer that the x-axis (time) is directly proportional
    %    to the capacity of the battery.
    %  - i.e. The x-axis of the data goes from t_start to t_end. The
    %         numbers were then scaled so that it goes from 0% to
    %         100% time charged. This can be assumed to be equal to
    %         the percent of the battery's charge (its capacity).
    %
    
    x_axis = [0,20.04008016,20.04008016,40.08016032,40.08016032,60.12024048,60.12024048,80.16032064,100.2004008,160.3206413,240.4809619,380.761523,460.9218437,541.0821643,641.2825651,781.5631263,1022.044088,1262.52505,1503.006012,1683.366733,1823.647295,1923.847695,2104.208417,2184.368737,2184.368737,2244.488978,2304.609218,2424.849699,2585.170341,2745.490982,2945.891784,3106.212425,3286.573146,3486.973948,3647.294589,3807.61523,3967.935872,4128.256513,4248.496994,4368.737475,4549.098196,4769.539078,4969.93988,5130.260521,5330.661323,5531.062124,5811.623246,6052.104208,6212.42485,6492.985972,6693.386774,6933.867735,7134.268537,7334.669339,7575.150301,7815.631263,8056.112224,8256.513026,8496.993988,8777.55511,9018.036072,9218.436874,9458.917836,9699.398798,9939.87976,10100.2004,10300.6012];
    y_axis = [6.189374464,6.335047129,6.266495287,6.403598972,6.467866324,6.532133676,6.626392459,6.737789203,6.832047986,6.986289632,7.114824336,7.260497001,7.346186804,7.397600686,7.449014567,7.500428449,7.5218509,7.53041988,7.53898886,7.54327335,7.551842331,7.556126821,7.568980291,7.581833762,7.667523565,7.706083976,7.718937446,7.731790917,7.740359897,7.744644387,7.753213368,7.761782348,7.770351328,7.778920308,7.791773779,7.800342759,7.80891174,7.81748072,7.8260497,7.83461868,7.847472151,7.864610111,7.881748072,7.890317052,7.903170523,7.911739503,7.928877464,7.937446444,7.946015424,7.963153385,7.971722365,7.988860326,7.997429306,8.010282776,8.023136247,8.040274207,8.057412168,8.070265638,8.091688089,8.10882605,8.12167952,8.138817481,8.151670951,8.173093402,8.190231362,8.211653813,8.233076264];
    
    x1 = x_axis(1:24);
    x2 = x_axis(26:end);
    x_axis = [x1,x2];
    
    y1 = y_axis(1:24);
    y2 = y_axis(26:end);
    y_axis = [y1,y2];
    
    n = 25;
    while n <= length(x_axis)
        x_axis(n) = x_axis(n) + 2000;
        n = n + 1;
    end
    
    n = 1;
    while n <= length(x_axis);
        x_axis(n) = x_axis(n)/x_axis(end)*2.6;
        n = n + 1;
    end
    
    y_axis = y_axis/max(y_axis)*Vmax;
    
    %% End 'generate_CS_bat_charging_voltage_curve.m'
    
    n = 1;
    while n <= length(x_axis)
        if (100 - C) < x_axis(n)
            break
        end
        n = n + 1;
    end
    
    x1 = x_axis(n-1);
    x2 = x_axis(n);
    y1 = y_axis(n-1);
    y2 = y_axis(n);
    
    % Linearly approximate voltage based on the two surrounding
    % points.
    V = ((y2-y1)/(x2-x1))*(100-C-x1)+y2;
    
else
    % IF NOT WITHIN DR of 1 to 10
    disp(['Error: DR = ',num2str(DR),'.']);
    disp('Not within defined range of 1 <= DR <= 15');
end


%{
OLD FUNCTION
global CurveVolt;
global CurveCap;
V = 0;
n1 = 1;
while n1 <= length(CurveCap)
    if C >= CurveCap(n1);
        V = CurveVolt(n1);
        break
    else
        n1= n1+1;
    end
end
%}
end

function [I] = calculate_current(time, Y_v)
% This function calculates the total current drawn by the load using the
% DDC schedule and our minutes into a given orbit.
global Regulator_Efficiency_5V;
global Regulator_Efficiency_3V3;
global s;
global b;
global component;
global DDC;
global mode;
I = 0;
n = 1;
while n <= length(component)
    if DDC.(mode)(n,round(mins_into_orbit(time+1))) == 1
        I = I + s.(component{n}).I.(b{1});
        I = I + s.(component{n}).I.(b{2}) * 5 / Y_v / Regulator_Efficiency_5V;
        I = I + s.(component{n}).I.(b{3}) * 3.3 / Y_v / Regulator_Efficiency_3V3;
    end
    n = n + 1;
end
end

function [P_net,P_in,P_out] = net_power(time)
% This function calculates power in/out within (x_res) minutes, and

global Photovoltaic_Boost_Converter_Efficiency;
global Regulator_Efficiency_5V;
global Regulator_Efficiency_3V3;
global Battery_Charge_Efficiency;
global Pin_total;
global V_bat;
global V_bus1;
global V_bus2;
global s; global b;
global component;
global mode;
global DDC;

P_out = 0;
n = 1;
while n <= numel(component)
    duty_cycle = sum(DDC.(mode)(n,:))/numel(DDC.(mode)(n,:));
    Reg_Output_Power = s.(component{n}).I.(b{1}) * V_bat;
    Reg_Input_Power = Reg_Output_Power / Photovoltaic_Boost_Converter_Efficiency * duty_cycle;
    P_out = P_out + Reg_Input_Power;
    Reg_Output_Power = s.(component{n}).I.(b{2}) * V_bus1;
    Reg_Input_Power = Reg_Output_Power / Regulator_Efficiency_5V * duty_cycle;
    P_out = P_out + Reg_Input_Power;
    Reg_Output_Power = s.(component{n}).I.(b{3}) * V_bus2;
    Reg_Input_Power = Reg_Output_Power / Regulator_Efficiency_3V3 * duty_cycle;
    P_out = P_out + Reg_Input_Power;
    
    n = n + 1;
end

% This coefficient is here for simulation purposes.
% ex. if we want to simulate a sun providing twice the solar power, set
% coef = 2.
coef = 1;
P_in = coef * Pin_total(time) * Battery_Charge_Efficiency;

P_net = P_in - P_out;



end

function [mins] = mins_into_orbit(t)
mins = rem(t,92);
if mins == 0;
    mins = 92;
end
end

function [returnStruct] = perMinute_approx(time_elapsed,total)
%
% This function takes in a set of data, and uses linear approximation to
% return the same graph but with data points at every whole-number minute.
%
% Inputs:
%  - time_elapsed ...... Vector containing time values in minutes (x-axis).
%  - total ............. Vector containing power generated in watts
%                        at a given time (y-axis).
%
% Output:
%  - returnStruct ...... Structure containing modified time and power
%                        generated vectors where they are named
%                        returnStruct.time_elapsed and returnStruct.total
%                        respectively, with time in minutes and power in
%                        watts.
%
% Method used:
%
%  point-slope form:
%    y - y1 = m * (x - x1)
%    y - y1 = ((y2 - y1)/(x2 - x1)) * (x - x1)
%    y = ((y2 - y1)/(x2 - x1)) * (x - x1) + y1
%
%  Where y is the power at time x, and (x1,y1) and (x2,y2) are the two
%  points that surround a whole number minute x horrizontally.
%

% Can only use data within time restrictions (interpolation)
t_min = ceil(time_elapsed(1));
t_max = floor(time_elapsed(end));

returnStruct.time_elapsed = (t_min:1:t_max);
returnStruct.total = zeros(1,length(returnStruct.time_elapsed));

scanStart = 1;
n = 1;
while n <= length(returnStruct.time_elapsed)
    % Finding the surrounding points
    m = scanStart;
    while m <= length(time_elapsed)
        if time_elapsed(m) <= returnStruct.time_elapsed(n)
            if time_elapsed(m+1) >= returnStruct.time_elapsed(n)
                scanStart = m - 5;
                if scanStart < 1
                    scanStart = 1;
                end
                break
            end
        end
        m = m + 1;
    end
    
    x1 = time_elapsed(m);
    x2 = time_elapsed(m+1);
    y1 = total(m);
    y2 = total(m+1);
    
    % Using linear interpolation to evaluate the power whone-number time
    returnStruct.total(n) = ((y2 - y1)/(x2 - x1)) * (returnStruct.time_elapsed(n) - x1) + y1;
    
    % Progress
    if rem(n,250) == 0
        clc;
        disp(' ');
        disp(' ');
        disp('Performing per-minute approximations.');
        disp(' ');
        disp(['Progress: ',num2str(n/length(returnStruct.time_elapsed)*100),'%']);
    end
    
    n = n + 1;
end

clc;
disp(' ');
disp(' ');
disp('Performing per-minute approximations.');
disp(' ');
disp('Progress: 100%');
disp(' ');

end

function [doubled] = doubleSchedule(schedule)
doubled = zeros(1,2*length(schedule));
n = 1;
while n <= length(schedule)
    doubled(n*2-1) = schedule(n);
    doubled(n*2) = schedule(n);
    n = n + 1;
end
end
