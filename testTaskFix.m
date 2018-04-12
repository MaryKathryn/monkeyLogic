%testTask conditions file 

fixation_point_1 = 1;
%fixation_point_2 = 2;

fix_radius = 8;
saccade_time = 1000000000000;

toggleobject(fixation_point_1, 'eventmarker', 10, 'status','on');

showcursor(1) 

ontarget = eyejoytrack('acquirefix', [fixation_point_1], fix_radius, saccade_time); %******will probably need to increase 
if ~ontarget,
    trialerror(2); % no or late response (did not land on either the target or distractor)
    toggleobject([fixation_point_1])
    return
end

trialerror(0); % correct
goodmonkey(50, 3); % 50ms of juice x 3

