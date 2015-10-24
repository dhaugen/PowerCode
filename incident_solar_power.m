%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%  This script takes in the number of panels per face, the wattage per
%  pannel, and the beta of an orbit, to produce total power
%
%  beta is given in degrees
%
%  z+ face is anti-ram
%  y- face is towards Earth
%  x+ face builds right handed coordinate system
%
%  John Grey, July 30, 2015
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% beta is the angle, from 0 to 90, which defines what type of orbit we are
% in (0 = beta for noon-midnight, 90 = beta for dawn-dusk)

% all times are in minutes

function [time_elapsed,power] = incident_solar_power(beta,orbit_period,end_time,time_step)


% script inputs
x_minus = 3;
x_plus = 3;
y_minus = 1;
y_plus = 3;
z_minus = 0;
z_plus = 0;
power_per_panel = 7.35/3; % watts

% define some variables
r = 6371; % radius of the earth in km
a = 6771; % semimajor axis of the orbit in km
time_elapsed = 0:time_step:end_time;
theta = rem(360 * time_elapsed / orbit_period,360);
x_power = [];
y_power = [];
z_power = [];


% calculate the angle where the satellite will enter eclipse
if a*sind(beta) < r
    psi = atand((a^2-r^2)/(r^2-a^2*(sind(beta))^2));
else
    psi = 90;
end

% decides which of the x faces is exposed to the sun
if beta < 90
    x_face = x_minus;
else
    x_face = x_plus;
end

% total power for the x faces
for a= theta
    if  a <= 180 + psi | a >= 360 - psi
        x_power = [x_power,sind(beta)*x_face*power_per_panel];
    else
        x_power = [x_power,0];
    end
end


% total power for the y faces
for a = theta
    if a < 180
        y_power = [y_power,sind(a)*y_plus*power_per_panel*abs(cosd(beta))];
    elseif  a < 180 + psi | a >= 360 - psi
        y_power = [y_power,abs(sind(a)*y_minus*power_per_panel)*abs(cosd(beta))];
    else
        y_power = [y_power,0];
    end
end

% total power for the z faces
for a = theta
    if a <90 | a > 360-psi
        z_power = [z_power,z_minus*abs(cosd(a))*cosd(beta)*power_per_panel];
    elseif a >90 & a<180 + psi
        z_power = [z_power,z_plus*abs(cosd(a))*cosd(beta)*power_per_panel];
    else
        z_power = [z_power,0];
    end
end

% sum the power for all faces
power = x_power+y_power+z_power;

% plot the power
% figure
% hold on
% xlabel('Theta (degrees)')
% ylabel('Power')
% plot(theta,power,'b')
% plot(theta,x_power,'g')
% plot(theta,y_power,'k')
% plot(theta,z_power,'r')
% legend('Total','X','Y','Z');
% hold off   
    
end

