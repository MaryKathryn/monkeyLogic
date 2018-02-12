if ~exist('eye_','var'), error('This demo requires eye signal input. Please set it up or try the simulation mode.'); end
showcursor(false);  % remove the joystick cursor

% rdm variables
num_dot = 100;
dot_size = 0.15;
editable('num_dot','dot_size');

% give names to the TaskObjects defined in the conditions file:
fixation_point = 1;

coherence = ceil(rand(1)*100);
direction = rand(1)*360;
speed = 1 + rand(1)*19;

% scene 1: fixation
fix1 = SingleTarget(eye_);
fix1.Target = fixation_point;
fix1.Threshold = 3;
wth1 = WaitThenHold(fix1);
wth1.WaitTime = 5000;
wth1.HoldTime = 0;
scene1 = create_scene(wth1,fixation_point);

% scene 2: sample
fix2 = SingleTarget(eye_);
fix2.Target = fixation_point;
fix2.Threshold = 6;
wth2 = WaitThenHold(fix2);
wth2.WaitTime = 0;
wth2.HoldTime = 5000;
rdm2 = RandomDotMotion(wth2);
rdm2.NumDot = num_dot;
rdm2.DotSize = dot_size;
rdm2.DotColor = [1 1 1];
rdm2.Position = [0 0];
rdm2.Radius = 5;
rdm2.Coherence = coherence;
rdm2.Direction = direction;
rdm2.Speed = speed;
scene2 = create_scene(rdm2,fixation_point);

run_scene(scene1);
if ~wth1.Success
	idle(0);  % clear screen
    if wth1.Waiting
        trialerror(4);  % no fixation
    else
        trialerror(3);  % broke fixation
    end
    return
end

dashboard(1,sprintf('Coherence = %d',coherence));
dashboard(2,sprintf('Direction = %.1f deg',direction));
dashboard(3,sprintf('Speed = %.1f deg/sec',speed));

run_scene(scene2);
if wth2.Success
    trialerror(0);  % correct
else
    trialerror(3);  % broke fixation
end

dashboard(1,'');
dashboard(2,'');
dashboard(3,'');

idle(0);  % clear screen

set_iti(500);
