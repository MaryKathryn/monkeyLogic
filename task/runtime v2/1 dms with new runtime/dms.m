if ~exist('eye_','var'), error('This demo requires eye signal input. Please set it up or try the simulation mode.'); end

showcursor(false);  % remove the joystick cursor
bhv_code(10,'Fix Cue',20,'Sample',30,'Delay',40,'Go',50,'Reward');  % behavioral codes

% give names to the TaskObjects defined in the conditions file:
fixation_point = 1;
sample = 2;
target = 3;
distractor = 4;

% define time intervals (in ms):
wait_for_fix = 5000;
initial_fix = 500;
sample_time = 1000;
delay = 1000;
max_reaction_time = 2000;
hold_target_time = 500;

% fixation window (in degrees):
fix_radius = 2;
hold_radius = 2.5;

% scene 1: fixation
fix1 = SingleTarget(eye_);
fix1.Target = fixation_point;
fix1.Threshold = fix_radius;
wth1 = WaitThenHold(fix1);
wth1.WaitTime = wait_for_fix;
wth1.HoldTime = initial_fix;
scene1 = create_scene(wth1,fixation_point);

% scene 2: sample
fix2 = SingleTarget(eye_);
fix2.Target = sample;
fix2.Threshold = hold_radius;
wth2 = WaitThenHold(fix2);
wth2.WaitTime = 0;
wth2.HoldTime = sample_time;
scene2 = create_scene(wth2,[fixation_point sample]);

% scene 3: delay
wth3 = WaitThenHold(fix2);
wth3.WaitTime = 0;
wth3.HoldTime = delay;
scene3 = create_scene(wth3,fixation_point);

% scene 4: choice
mul4 = MultiTarget(eye_);
mul4.Target = [target distractor];
mul4.Threshold = fix_radius;
mul4.WaitTime = max_reaction_time;
mul4.HoldTime = hold_target_time;
mul4.TurnOffUnchosen = true;
scene4 = create_scene(mul4,[target distractor]);

% scene 5: clear the screen. equivalent to idle(0)
tc5 = TimeCounter(null_);
tc5.Duration = 0;
endscene = create_scene(tc5);

% TASK:
run_scene(scene1,10);
if ~wth1.Success
    run_scene(endscene);
    if wth1.Waiting
        trialerror(4); % no fixation
    else
        trialerror(3); % broke fixation
    end
    return
end

run_scene(scene2,20);
if ~wth2.Success
    run_scene(endscene);
    trialerror(3); % broke fixation
    return
end

run_scene(scene3,30);
if ~wth3.Success
    run_scene(endscene);
    trialerror(3); % broke fixation
    return
end

run_scene(scene4,40);
if ~mul4.Success
    run_scene(endscene);
    if mul4.Waiting
        trialerror(2); % no or late response (did not land on either the target or distractor)
    else
        trialerror(5);  % broke fixation
    end
    return
end

run_scene(endscene);

% reward
if target==mul4.ChosenTarget
    trialerror(0); % correct
    goodmonkey(100, 'juiceline',1, 'numreward',2, 'pausetime',500, 'eventmarker',50); % 100 ms of juice x 2
else
    trialerror(6); % chose the wrong (second) object among the options [target distractor]
    idle(700);
end
