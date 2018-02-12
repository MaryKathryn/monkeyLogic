% This task requires that either an "eye" input or joystick (attached to the
% eye input channels) is available to perform the necessary responses.
%
% During a real experiment, a task such as this should make use of the
% "eventmarker" command to keep track of key actions and state changes (for
% instance, displaying or extinguishing an object, initiating a movement, etc).

if ~ML_eyepresent, error('This demo requires eye signal input. Please set it up or try the simulation mode.'); end

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

% TASK:

% initial fixation:
toggleobject(fixation_point, 'eventmarker',10);
ontarget = eyejoytrack('acquirefix', fixation_point, fix_radius, wait_for_fix);
if ~ontarget
    toggleobject(fixation_point);
    trialerror(4);  % no fixation
    return
end
ontarget = eyejoytrack('holdfix', fixation_point, hold_radius, initial_fix);
if ~ontarget
    toggleobject(fixation_point);
    trialerror(3);  % broke fixation
    return
end

% sample epoch
toggleobject(sample, 'eventmarker',20);  % turn on sample
ontarget = eyejoytrack('holdfix', fixation_point, hold_radius, sample_time);
if ~ontarget
    toggleobject([fixation_point sample]);
    trialerror(3);  % broke fixation
    return
end
toggleobject(sample, 'eventmarker',30);  % turn off sample

% delay epoch
ontarget = eyejoytrack('holdfix', fixation_point, hold_radius, delay);
if ~ontarget
    toggleobject(fixation_point);
    trialerror(3);  % broke fixation
    return
end

% choice presentation and response
toggleobject([fixation_point target distractor], 'eventmarker',40);  % simultaneously turns of fix point and displays target & distractor
chosen_target = eyejoytrack('acquirefix', [target distractor], fix_radius, max_reaction_time);
if ~chosen_target
    toggleobject([target distractor]);
    trialerror(2);  % no or late response (did not land on either the target or distractor)
    return
end

% hold the chosen target
if 1==chosen_target
    toggleobject(distractor);
    ontarget = eyejoytrack('holdfix', target, hold_radius, hold_target_time);
else
    toggleobject(target);
    ontarget = eyejoytrack('holdfix', distractor, hold_radius, hold_target_time);
end
toggleobject([target distractor],'status','off');
if ~ontarget
    trialerror(5);  % broke fixation
    return
end

% reward
if 1==chosen_target
    trialerror(0);  % correct
    goodmonkey(100, 'juiceline',1, 'numreward',2, 'pausetime',500, 'eventmarker',50); % 100 ms of juice x 2
else
    trialerror(6);  % chose the wrong (second) object among the options [target distractor]
    idle(700);
end
