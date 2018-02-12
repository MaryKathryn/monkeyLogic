if ~exist('eye_','var'), error('This demo requires eye signal input. Please set it up or try the simulation mode.'); end
hotkey('x', 'escape_screen(); assignin(''caller'',''continue_'',false);');
showcursor(false);  % remove the joystick cursor

dashboard(1,'COMPLEX BEHAVIOR & DYNAMIC STIMULI',[1 0 0]);
dashboard(2,'1. Timer counts only while the fixation is held.');
dashboard(3,'2. Trial ends when the timer counts up to 7 or when the gaze is away for more than 4 sec.');

% give names to the TaskObjects defined in the conditions file:
fixation_point = 1;

% scene 1: fixation
fix1 = SingleTarget(eye_);
fix1.Target = fixation_point;
fix1.Threshold = 3;
tm1 = TimerDemo(fix1);

scene1 = create_scene(tm1,fixation_point);

run_scene(scene1);

if tm1.Success
    trialerror(0);  % correct
else
    trialerror(3);  % broke fixation
end

idle(0);  % clear screen

set_iti(500);
