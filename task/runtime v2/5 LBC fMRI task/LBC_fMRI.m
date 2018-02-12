if ~exist('eye_','var'), error('This demo requires eye signal input. Please set it up or try the simulation mode.'); end
hotkey('x', 'escape_screen(); assignin(''caller'',''continue_'',false);');
showcursor(false);   % remove the joystick cursor

dashboard(6,'Press ''x'' to quit.',[1 0 0]);

bhv_code(100,'Blank',101,'Image1',102,'Image2',103,'Image3',104,'Image4');
bhv_code(201,'Reward1',202,'Reward2',203,'Reward3');

fixation_point = 1;  % TaskObject #1
TR_button = 1;       % button number that the TR signal is assigned to

manager = LBC_ExpManager();

% chech if the TR button is defined
if exist('button_','var') && ismember(TR_button,button_.ButtonsAvailable)
    button_.invert(TR_button);         % TR pulses are inverted TTLs
    button_.label(TR_button,'TR');
    pc1 = PulseCounter(button_);
    pc1.Button = TR_button;
else  % if not, ignore TR
    pc1 = null_;  % NullTracker is always Success.
end    

TR_onset = OnsetDetector(pc1);
img1 = LBC_ImageChanger(TR_onset);
manager.ImageChanger = img1;

% ImageList is a n-by-4 cell matrix.
% The 1st column is image filenames.
% The 2nd column is image positions in visual angles.
% The 3rd column is image durations.
% The 4th column is eventmarkers.
img1.ImageList = { 'A.bmp', [5 5], 2000, 101; ...
    '', [], 2000, 100; ...
    'B.bmp', [5 -5], 2000, 102; ...
    '', [], 2000, 100; ...
    'C.bmp', [-5 -5], 2000, 103; ...
    '', [], 2000, 100; ...
    'D.bmp', [ -5 5], 2000, 104;
    '', [], 2000, 100; };

fp1 = SingleTarget(eye_);
fp1.Target = fixation_point;
fp1.Threshold = 3;                 % fixation window 3 degrees
fix1 = LBC_FixAnalyzer(fp1);
fix1.BlinkTime = 300;              % max duration of blinks
rwd1 = LBC_RewardScheduler(fix1);
manager.RewardScheduler = rwd1;

% Schedule is a n-by-4 numeric matrix.
% The 1st column is the minimum required fixation length to get into the schedule of that row.
% The 2nd column is the minimum interval to next reward.
% The 3rd column is the maximum interval to next reward.
% The 4th column is pulse durations.
% The 5th column is eventmarkers.
rwd1.Schedule = [0 3000 4000 100 201; ...
    10000 2000 3000 150 202; ...
    20000 800 1000 200 203];

scene1 = create_scene(manager,fixation_point);
run_scene(scene1);

set_iti(500);

bhv_variable('TR_onset_time',TR_onset.Time);
bhv_variable('fixation_proportion',manager.PropFixation);
