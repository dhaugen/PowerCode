function [] = Variable_DDC_Plot_Input()
%% Configuration
global component;
global peakPower;
component = {'GPS','P31us','Nanomind','Nanohub','UHF_Rx','UHF_Tx','Active_THCS','Magnetometer','MNLP_Opterational','MNLP_Standby','SSADCS_ARE','SSADCS_AFSE','SSADCS_Detumble','SSADCS_YMC_Eclipse','SSADCS_YMC_Daylight','Teledyne','UofA_OBC'};
peakPower = 7.7488; % maximum power in watts, currently based on max in dawn-dusk


%% Housekeeping Variables
Boolean vector checking if component has been modified.
modBool = zeros(1,length(component));
% Storage for Vertices (255 verts max per component).
global vert;
vert = cell(1,length(component));
for n = 1:length(component)
    vert{n} = cell(1,255);
    vert{n}{1} = [0 0];
end

%% MAIN LOOP
firstRun = 1;
while 1
    % Get component to modify
    compSetting = component_menu(modBool);
    modBool(compSetting) = 1;
    
    % Open figure, prompt user to configure windows
    if firstRun
        prompt_window_config(peakPower,compSetting);
        firstRun = 0;
    end
    
    % Prompt for vertex entry option
    vertex_entry_menu(peakPower,compSetting);
    
    
end




end

function [compSetting] = component_menu(modBool)
global component;
validIn = 0;
firstLoop = 1;
helpCalled = 0;
while ~validIn || firstLoop
    % Initialization
    if firstLoop || helpCalled
        firstLoop = 0;
        validIn = 1;
    end
    
    % Display prompt
    clc;
    disp('Type ''help'' to get commands');
    disp(' ');
    
    disp('Components:');
    spacing = '  ';
    for m = 1:length(component)
        if m == 10
            spacing = ' ';
        end
        if modBool(m)
            disp([num2str(m),'.',spacing,'(',component{m},')']);
        else
            disp([num2str(m),'.',spacing,component{m}]);
        end
    end
    disp(' ');
    if ~validIn && ~helpCalled
        disp(['Invalid input. Last input: ',userIn]);
        disp(' ');
        validIn = 1;
    end
    if helpCalled
        helpCalled = 0;
    end
    
    userIn = input('Choose component: ','s');
    
    % Main menu loop
    compSetting = 0;
    while 1
        % Check if input = help
        if strcmpi(userIn,'help')
            clc;
            disp('=== HELP ====');
            disp(' ');
            disp('- If prompted for component, enter component name or number.');
            disp('- User input is case insensitive.');
            disp('- Please input duty cycle for all components.');
            disp('- Components which have been editted are printed within parenthases.');
            disp('- Enter ''EXIT'' in order to finish data input.');
            disp(' ');
            input('Press <ENTER> to continue.','s');
            helpCalled = 1;
        end
        
        % Check if plot all 
        % if strcmpi(userIn,'full plot')
        %    plot_vert_all();
        %    helpCalled = 1;
        % end
        
        
        % Check if input = component number
        if sum(isstrprop(userIn,'digit')) == length(userIn)
            userNum = str2double(userIn);
            if 1 <= userNum && userNum <= length(component)
                compSetting = userNum;
                break
            end
        end
        
        % Check if input = component name
        m = 1;
        exitCond = 0;
        while m <= length(component)
            if strcmpi(userIn,component{m})
                compSetting = m;
                exitCond = 1;
                break
            end
            m = m + 1;
        end
        if exitCond
            break
        end
        
        % If made this far, invalid input
        validIn = 0;
        break
    end
end


end

function [] = prompt_window_config(peakPower,compSetting)
global component;
clf; clc;
figure(1);
axis([0 ceil(peakPower) 0 105]);
hold on;
xlabel('Available Power (W)');
ylabel('Duty Cycle (%)');
compTitle = strrep(component{compSetting},'_','\_');
title(['Configuring ',compTitle]);
text1 = text(ceil(peakPower)/2,53,'Please dock figure or split screen for best view.','HorizontalAlignment','center','FontWeight','bold');
text2 = text(ceil(peakPower)/2,47,'Press any key to continue.','HorizontalAlignment','center','FontWeight','bold');
while 1
    buttonPress = getkeywait(100);
    if isnan(buttonPress)
        delete(text1);
        delete(text2);
        break
    end
    if buttonPress ~= -1
        delete(text1);
        delete(text2);
        break
    end
end
disp('%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%');
for n = 1:8
    disp('%                                     %');
end
disp('%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%');
text1 = text(ceil(peakPower)/2,53,'If needed, resize console until whole box is visible.','HorizontalAlignment','center','FontWeight','bold');
text2 = text(ceil(peakPower)/2,47,'Press any key to continue.','HorizontalAlignment','center','FontWeight','bold');
input('','s');
if buttonPress
    delete(text1);
    delete(text2);
end

plot(peakPower*[1 1],[0 100],'r');
text(peakPower - 0.1,35,'Peak Power','HorizontalAlignment','right','Color','r');

end

function [] = vertex_entry_menu(peakPower,compSetting)
global vert;
clc;
entryMode = 'keyboard';
while 1
    plot_vert_single(compSetting);
    disp(['Mode: ',entryMode]);
    disp(' ');
    disp('1. New vertex');
    disp('2. Delete vertex');
    disp('3. Move vertex');
    disp('4. Save and exit')
    disp(' ');
    disp('Press <space> to change mode of entry.');
    disp(' ');
    disp('Enter option: ');
    buttonPress = getkeywait(100);
    if buttonPress == ' '
        if strcmp(entryMode,'keyboard')
            entryMode = 'mouse';
        else
            entryMode = 'keyboard';
        end
    elseif buttonPress == '1'
        % "New vertex" has been selected
        if ~isempty(vert{compSetting}{end})
            clc;
            disp('Unable to continue.');
            disp('Max number of vertices (255) has been reached.');
            disp(' ');
            input('Press <enter> to continue.','s');
        else
            if strcmp(entryMode,'keyboard');
                % To enter new vertex with keyboard
                
            else
                % To enter new vertex with mouse
                clc;
                disp('Use mouse to select location of vertex.');
                [xval,yval] = ginput(1);
                % Compensate if cursor is out of range.
                if xval < 0 || xval > peakPower || yval < 0 || yval > 100
                    if xval < 0
                        xval = 0;
                    end
                    if yval < 0;
                        yval = 0;
                    end
                    if xval > peakPower
                        xval = peakPower;
                    end
                    if yval > 100
                        yval = 100;
                    end                    
                end
                % Update vert
                n = 1;
                while n <= length(vert{compSetting})
                    if isempty(vert{compSetting}{n})
                        vert{compSetting}{n} = [xval,yval];
                        break
                    end
                    n = n + 1;
                end
                % Update plot
                plot_vert_single(compSetting);
                input('?','s');                
            end
        end
        break
    elseif buttonPress == '2'
        break
    elseif buttonPress == '3'
        break
    elseif buttonPress == '4'
        break
    end
end
end

function [] = refresh_plot(compSetting)
global component;
global peakPower;

clf; clc;
axis([0 ceil(peakPower) 0 105]);
hold on;
xlabel('Available Power (W)');
ylabel('Duty Cycle (%)');
compTitle = strrep(component{compSetting},'_','\_');
title(['Configuring ',compTitle]);

plot(peakPower*[1 1],[0 100],'r');
text(peakPower - 0.1,35,'Peak Power','HorizontalAlignment','right','Color','r');

end

function [] = plot_vert_single(compSetting)
global vert;

refresh_plot(compSetting);

vecSize = 0;
n = 1;
while n <= length(vert{compSetting})
    if ~isempty(vert{compSetting}{n})
        vecSize = vecSize + 1;
    else
        break
    end
    n = n + 1;
end

% Assign x and y vectors
xvec = zeros(1,vecSize);
for n = 1:vecSize
    xvec(n) = vert{compSetting}{n}(1);
end
yvec = zeros(1,vecSize);
for n = 1:vecSize
    yvec(n) = vert{compSetting}{n}(2);
end

hold on;
plot(xvec,yvec);

end

function [] = plot_vert_all()
global component;
global vert;

refresh_plot(1);
title('Duty Cycles - All Components');

for compSetting = 1:length(component)
    

    vecSize = 0;
    n = 1;
    while n <= length(vert{compSetting})
        if ~isempty(vert{compSetting}{n})
            vecSize = vecSize + 1;
        else
            break
        end
        n = n + 1;
    end

    % Assign x and y vectors
    xvec = zeros(1,vecSize);
    for n = 1:vecSize
        xvec(n) = vert{compSetting}{n}(1);
    end
    yvec = zeros(1,vecSize);
    for n = 1:vecSize
        yvec(n) = vert{compSetting}{n}(2);
    end

    hold on;
    plot(xvec,yvec);
    hold on;

end

end








