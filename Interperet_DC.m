function [DDC] = Interperet_DC (P_est,varargin)

%% ============= INTRODUCTION AND VARIABLE PARAMETERS ===================== 

%% Description 
% This function takes in a duty cycle text file and gathers data from it.
%
% The output is a structure DDC which determines when components will be
% turned on.
%
% The first input is the estimated (recommended) power in watts.
% The second input is the name of a *.txt file which contains this data.

%% Assign constant parameters
% This is the highest available power that will be taken account of.
x_maxlim = 25; % W

% Default text files for duty cycle and primers
default_dutyCycleTextFile = 'Duty Cycle 1.txt';
default_primersTextFile = 'DC Primers 1.txt';

%% =============== INTERPERET DUTY CYCLE TEXT FILE ========================

%% Get the name of the file.
if isempty(varargin)
    % Set default text file name here.
    textFileName = default_dutyCycleTextFile;
else
    textFileName = varargin{1};
    if length(textFileName) < 4
        textFileName = [textFileName,'.txt'];
    elseif ~strcmpi(textFileName(end-3:end),'.txt')
        textFileName = [textFileName,'.txt'];
    end
end

%% Read and interperet file.

% Read file as whole string.
textFile = fileread(textFileName);

% Remove whitespace characters.
% Note: [char(13),char(10)] is equivalent to 'tab and enter'.
textFile = textFile(textFile ~= ' ');
textFile = textFile(textFile ~= char(13));
textFile = textFile(textFile ~= char(10));

% Remove note/description if present.
if textFile(1) == '{'
    textFile = textFile(find(textFile == '}')+1:end);
end

% Count number of lines. Number of lines = number of ';'.
num_of_lines = sum(textFile == ';');

% Create cell array fileLine which holds the individual lines of text.
fileLines = cell(1,num_of_lines);

% Add starting and ending reference points.
if textFile(1) ~= ';'
    textFile = [';',textFile];
end
if textFile(end) ~= ';'
    textFile = [textFile,';'];
end

% Separate textFile and populate fileLines.
idx = find(textFile == ';');
for n = 1:num_of_lines
    fileLines{n} = textFile(idx(n)+1:idx(n+1)-1);
end

% Go through components and extract data.
component = cell(1,num_of_lines);
for n = 1:num_of_lines
    % Take each file line and extract component name.
    idx1 = find(fileLines{n} == ':');
    component{n} = fileLines{n}(1:idx1-1);
    
    % Convert into comma-separated numbers in the form:
    % ,x1,y1,x2,y2,...
    fileLines{n} = fileLines{n}(idx1+1:end);
    fileLines{n} = strrep(fileLines{n},'),(',',');
    fileLines{n}(1) = ',';
    fileLines{n}(end) = ',';
    
    % Create an array 'values' which holds all values in order.
    idx2 = find(fileLines{n} == ',');
    values = zeros(1,numel(idx2)-1);
    for m = 1:numel(values)
        values(m) = str2double(fileLines{n}(idx2(m)+1:idx2(m+1)-1));
    end
    
    % Calculate number of data points.
    dataPoints = numel(idx2);
    dataPoints = (dataPoints - 1) / 2;
    
    % Define structures x and y such that the plot of component 'example'
    % is defined by the vectors x.example and y.example.
    % i.e.
    % plot(x.example,y.example);
    x.(component{n}) = zeros(1,dataPoints+1);
    y.(component{n}) = zeros(1,dataPoints+1);
    
    % Populate structures x and y.
    for m = 1:dataPoints
        x.(component{n})(m) = values(2*m-1);
        y.(component{n})(m) = values(2*m);
    end
    
    % Append to the end of x and y the absolute limit of the duty cycle.
    x.(component{n})(end) = x_maxlim;
    y.(component{n})(end) = y.(component{n})(end-1);
    
end

%% Get duty cycle value in % using the input P_est.
% Define structure 'DC' which will hold the duty cycle of each component 
% in percent.
for n = 1:numel(component)
    DC.(component{n}) = 0;
end

% Populate the structure 'DC'
for n = 1:numel(component)
    % Find the two values in x.(component) which surround P_est
    m = 1;
    while m < numel(x.(component{n}))
        if x.(component{n})(m) <= P_est && x.(component{n})(m+1) >= P_est
            break
        end
        m = m + 1;
        if m == numel(x.(component{n}))
            error(['Could not find points on duty cycle graph which surround P_est for component ''',component{n},'''.']);
        end
    end
    
    % Using linear interpolation and the point-slope form, find the duty
    % cycle for that component at that estimated power.
    %
    % y - y1 = m * (x - x1)
    % y - y1 = [(y2 - y1) / (x2 - x1)] * (x - x1)
    % y = [(y2 - y1) * (x - x1) / (x2 - x1)] + y1
    %       ^term1      ^term2     ^term3
    %      {______________________________}
    %                   ^term4  
    %
    % Where: - x is P_est
    %        - y is DC.(component{n})
    %        - x1 is x.(component{n})(m)
    %        - x2 is x.(component{n})(m+1) 
    %        - y1 is y.(component{n})(m)
    %        - y2 is y.(component{n})(m+1) 
    %
    term1 = y.(component{n})(m+1) - y.(component{n})(m);
    term2 = P_est - x.(component{n})(m);
    term3 = x.(component{n})(m+1) - x.(component{n})(m);
    term4 = term1 * term2 / term3;
    DC.(component{n}) = term4 + y.(component{n})(m);
    
end

%% ================= INTERPERET PRIMER TEXT FILE ==========================

%% Get the name of the file.
if isempty(varargin)
    % Set default text file name here.
    textFileName = default_primersTextFile;
else
    textFileName = varargin{2};
    if length(textFileName) < 4
        textFileName = [textFileName,'.txt'];
    elseif ~strcmpi(textFileName(end-3:end),'.txt')
        textFileName = [textFileName,'.txt'];
    end
end

%% Read and interperet file.

% Read file as whole string.
textFile = fileread(textFileName);

% Remove whitespace characters.
% Note: [char(13),char(10)] is equivalent to 'tab and enter'.
textFile = textFile(textFile ~= ' ');
textFile = textFile(textFile ~= char(13));
textFile = textFile(textFile ~= char(10));

% Remove note/description if present.
if textFile(1) == '{'
    textFile = textFile(find(textFile == '}')+1:end);
end

% Count number of lines. Number of lines = number of ';'.
num_of_lines = sum(textFile == ';');

% Create cell array fileLine which holds the individual lines of text.
fileLines = cell(1,num_of_lines);

% Add starting and ending reference points.
if textFile(1) ~= ';'
    textFile = [';',textFile];
end
if textFile(end) ~= ';'
    textFile = [textFile,';'];
end

% Separate textFile and populate fileLines.
idx = find(textFile == ';');
for n = 1:num_of_lines
    fileLines{n} = textFile(idx(n)+1:idx(n+1)-1);
end

% Go through components and extract data.
for n = 1:numel(component)
    % Remove component name. Assume that components match the list in the
    % duty cycle text file.
    idx1 = find(fileLines{n} == ':');
    fileLines{n} = fileLines{n}(idx1+1:end);
    
    % Add reference points.
    if fileLines{n}(1) ~= ','
        fileLines{n} = [',',fileLines{n}];
    end
    if fileLines{n}(end) ~= ','
        fileLines{n} = [fileLines{n},','];
    end
    
    % Find number of primers
    num_of_primers = numel(find(fileLines{n} == ','));
    num_of_primers = (num_of_primers - 1)/2;
    
    % Create structure primer, which will follow the format of the example:
    % ex. primer.loc.GPS = [0];
    %     primer.dir.GOS = {'right'}; <-- for single primers
    %     
    %     primer.loc.DFGM = [0,92];
    %     primer.dir.DFGM = {'right','left'} <-- for multiple primers
    %
    primer.loc.(component{n}) = zeros(1,num_of_primers);
    primer.dir.(component{n}) = cell(1,num_of_primers);
    
    % Separate fileLines into a cell array containing all elements in
    % string form, and in order.
    idx2 = find(fileLines{n} == ',');
    values = cell(1,numel(idx2)-1);
    for m = 1:numel(values)
        values{m} = fileLines{n}(idx2(m)+1:idx2(m+1)-1);
    end
    
    % Populate the structure 'primer'.
    for m = 1:num_of_primers
        primer.loc.(component{n})(m) = str2double(values{2*m-1});
        primer.dir.(component{n}){m} = values{2*m};
    end
end

%% =================== FORMAT OUTPUT STRUCTURE ============================

%% Set the default duty cycles (for all modes except for science mode.

% =========================================================================
% =========== Test Schedule - Off_Mode DDC (Dynamic Duty Cycle) ===========
% =========================================================================

DDC.Off_Mode = zeros(17,92);
% GPS
DDC.Off_Mode(1,:) = zeros(1,92);
% P31us
DDC.Off_Mode(2,:) = ones(1,92);
% Nanomind
DDC.Off_Mode(3,:) = zeros(1,92);
% Nanohub
DDC.Off_Mode(4,:) = zeros(1,92);
% UHF_Rx
DDC.Off_Mode(5,:) = ones(1,92);
% UHF_Tx
DDC.Off_Mode(6,:) = [[1 1 1 1 1] zeros(1,87)];
% Active_THCS
DDC.Off_Mode(7,:) = zeros(1,92);
% Magnetometer
DDC.Off_Mode(8,:) = zeros(1,92);
% MNLP_Operational
DDC.Off_Mode(9,:) = zeros(1,92);
% MNLP_Standby
DDC.Off_Mode(10,:) = zeros(1,92);
% SSADCS_ARE
DDC.Off_Mode(11,:) = zeros(1,92);
% SSADCS_AFSE
DDC.Off_Mode(12,:) = zeros(1,92);
% SSADCS_Detumble
DDC.Off_Mode(13,:) = zeros(1,92);
% SSADCS_YMC_Eclipse
DDC.Off_Mode(14,:) = zeros(1,92);
% SSADCS_YMC_Daylight
DDC.Off_Mode(15,:) = zeros(1,92);
% Teledyne Sensor
DDC.Off_Mode(16,:) = zeros(1,92);
% UofA_OBC
DDC.Off_Mode(16,:) = zeros(1,92);


% =========================================================================
% ===== Test Schedule - Detumbling_Mode DDC (Dynamic Duty Cycle) ==========
% =========================================================================

DDC.Detumbling_Mode = zeros(17,92);
% GPS
DDC.Detumbling_Mode(1,:) = zeros(1,92);
% P31us
DDC.Detumbling_Mode(2,:) = ones(1,92);
% Nanomind
DDC.Detumbling_Mode(3,:) = ones(1,92);
% Nanohub
DDC.Detumbling_Mode(4,:) = zeros(1,92);
% UHF_Rx
DDC.Detumbling_Mode(5,:) = ones(1,92);
% UHF_Tx
DDC.Detumbling_Mode(6,:) = [zeros(1,90) [1 1]];
% Active_THCS
DDC.Detumbling_Mode(7,:) = zeros(1,92);
% Magnetometer
DDC.Detumbling_Mode(8,:) = zeros(1,92);
% MNLP_Operational
DDC.Detumbling_Mode(9,:) = zeros(1,92);
% MNLP_Standby
DDC.Detumbling_Mode(10,:) = zeros(1,92);
% SSADCS_ARE
DDC.Detumbling_Mode(11,:) = zeros(1,92);
% SSADCS_AFSE
DDC.Detumbling_Mode(12,:) = [ones(1,30) zeros(1,62)];
% SSADCS_Detumble
DDC.Detumbling_Mode(13,:) = ones(1,92);
% SSADCS_YMC_Eclipse
DDC.Detumbling_Mode(14,:) = zeros(1,92);
% SSADCS_YMC_Daylight
DDC.Detumbling_Mode(15,:) = zeros(1,92);
% Teledyne Sensor
DDC.Detumbling_Mode(16,:) = zeros(1,92);
% UofA_OBC
DDC.Detumbling_Mode(17,:) = zeros(1,92);

% =========================================================================
% ========= Test Schedule - Safe_Mode DDC (Dynamic Duty Cycle) ============
% =========================================================================

DDC.Safe_Mode = zeros(17,92);
% GPS
DDC.Safe_Mode(1,:) = zeros(1,92);
% P31us
DDC.Safe_Mode(2,:) = ones(1,92);
% Nanomind
DDC.Safe_Mode(3,:) = ones(1,92);
% Nanohub
DDC.Safe_Mode(4,:) = zeros(1,92);
% UHF_Rx
DDC.Safe_Mode(5,:) = ones(1,92);
% UHF_Tx
DDC.Safe_Mode(6,:) = [zeros(1,60) [1 1] zeros(1,92-62)];
% Active_THCS
DDC.Safe_Mode(7,:) = [zeros(1,46) [1 1 1 1 1] zeros(1,92-51)];
% Magnetometer
DDC.Safe_Mode(8,:) = zeros(1,92);
% MNLP_Operational
DDC.Safe_Mode(9,:) = zeros(1,92);
% MNLP_Standby
DDC.Safe_Mode(10,:) = zeros(1,92);
% SSADCS_ARE
DDC.Safe_Mode(11,:) = zeros(1,92);
% SSADCS_AFSE
DDC.Safe_Mode(12,:) = zeros(1,92);
% SSADCS_Detumble
DDC.Safe_Mode(13,:) = zeros(1,92);
% SSADCS_YMC_Eclipse
DDC.Safe_Mode(14,:) = zeros(1,92);
% SSADCS_YMC_Daylight
DDC.Safe_Mode(15,:) = zeros(1,92);
% Teledyne Sensor
DDC.Safe_Mode(16,:) = zeros(1,92);
% UofA_OBC
DDC.Safe_Mode(17,:) = zeros(1,92);

%% Set Active Mission Mode using data from 'primer' and 'DC'
DDC.Active_Mission_Mode = zeros(17,92);
for n = 1:numel(component)
    input_DC = DC.(component{n});
    input_primer.loc = primer.loc.(component{n});
    input_primer.dir = primer.dir.(component{n});
    DDC.Active_Mission_Mode(n,:) = set_DDC(input_DC,input_primer);
end

end

function [DDC] = set_DDC(DC,primer)
% This function takes in duty cycle parameters and outputs a
% minute-by-minute schedule in the form of a 92 element boolean vector
%
% Inputs:
%  - DC , a double which represents the duty cycle, which is the percent of
%         time which this component should be on in an orbit.
%  - primer  , a structure with field names:
%    - *.loc , a double vector containing the starting point of the duty 
%              cycle in minutes.
%    - *.dir , a cell array which is the same size a *.loc, which
%              determines the direction of expansion of the duty cycle
%              band; elements in this array can take on the values:
%              "right", "left", and "outwards".
%

DDC = zeros(1,92);

if strcmpi(primer.dir,'right')
    % Boolean variable. If 1, increment right, if 0, increment left.
    bounce = 1;
    n = primer.loc;
    while 1
        % Set element n, located at primer.loc.
        DDC(n) = 1;
        
        % Check if DC from the vector and from the input matches.
        % If so, exit. (round up)
        if sum(DDC)/numel(DDC)*100 > DC
            break
        end
        
        % Catch. If the components are always on and it still does not
        % satisfy the DC, exit anyways.
        if sum(DDC) == numel(DDC)
            break
        end
        
        % Increment.
        if bounce
            n = n + 1;
        else 
            n = n - 1;
        end
        
        % Check for extremes and modify bounce.
        if n > numel(DDC)
            bounce = 0;
        elseif n < 1
            bounce = 1;
        end
    end
elseif strcmpi(primer.dir,'left')
    % Boolean variable. If 1, increment right, if 0, increment left.
    bounce = 0;
    n = primer.loc;
    while 1
        % Set element n, located at primer.loc.
        DDC(n) = 1;
        
        % Check if DC from the vector and from the input matches.
        % If so, exit. (round up)
        if sum(DDC)/numel(DDC)*100 > DC
            break
        end
        
        % Catch. If the components are always on and it still does not
        % satisfy the DC, exit anyways.
        if sum(DDC) == numel(DDC)
            break
        end
        
        % Increment.
        if bounce
            n = n + 1;
        else 
            n = n - 1;
        end
        
        % Check for extremes and modify bounce.
        if n > numel(DDC)
            bounce = 0;
        elseif n < 1
            bounce = 1;
        end
    end
elseif strcmpi(primer.dir,'outwards')
    % Boolean variable. If 1, increment right, if 0, increment left.
    % Priority is on right side of the band.
    bounce = 1;
    n = primer.loc;
    while 1
        % Check if next time increment is open. If not, bounce back.
        if DDC(n) == 0
            bounce = -1 * bounce + 1;
        end
        
        % Set element n, located at primer.loc.
        DDC(n) = 1;
        
        % Check if DC from the vector and from the input matches.
        % If so, exit. (round up)
        if sum(DDC)/numel(DDC)*100 > DC
            break
        end
        
        % Catch. If the components are always on and it still does not
        % satisfy the DC, exit anyways.
        if sum(DDC) == numel(DDC)
            break
        end
        
        % Increment.
        if bounce
            n = n + 1;
        else 
            n = n - 1;
        end
        
        % Check for extremes and modify bounce.
        if n > numel(DDC)
            bounce = 0;
        elseif n < 1
            bounce = 1;
        end
    end
end







end