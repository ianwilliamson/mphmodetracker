% This is an example file for using MPH_ModeTracker_Run

freqs        = linspace(4E12,12E12,9);

% With the below sweep options, we are solving for the combinations:
% (g, r_fact) = (40nm, 0.3)
% (g, r_fact) = (50nm, 0.4)

clear sweep;
sweep.r_fact = [0.3,      0.4];
sweep.g      = [40E-9,  50E-9];

% The above two combinations are referred to as "parameter value sets".
% Below, where we call MPH_ModeTracker_Run, we specify 'num_pts' as 4. This
% means that the function will interpolate 4 intermediate parameter value
% sets. First, between whatever g and r_fact are in the saved mph file to
% get to 40nm and 0.3. Then once more from 40nm and 0.3 to 50nm and 0.4.
% The function solves for the mode's band at each parameter value set over
% the frequencies specified by freqs.

results=MPH_ModeTracker_Run(...
    sweep, freqs,...
    'mph', [pwd,'\rod_tri_coarse_track_8.mph'],...
    'savedat', mfilename(),...
    'eval', {'ky','neff'},...
    'num_pts', 4, ...
    'silent', 1, ...
    'port', 2037,...
    'freq_start',4E12 );