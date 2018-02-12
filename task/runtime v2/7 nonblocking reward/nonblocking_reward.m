if ~exist('eye_','var'), error('This demo requires eye signal input. Please set it up or try the simulation mode.'); end
hotkey('x', 'escape_screen(); assignin(''caller'',''continue_'',false);');
showcursor(false);  % remove the joystick cursor

dashboard(1,'CATCH WATER DROP');
dashboard(2,'Press ''x'' to quit.',[1 0 0]);

showcursor(false);  % remove the joystick cursor

mglsetproperty(TaskObject(1).ID,'looping',true);

drop1 = CatchWaterDrop(eye_);
drop1.Position = [-3 0; -3 3; 0 3; 3 3; 3 0; 3 -3; 0 -3; -3 -3];
tc1 = TimeCounter(drop1);
tc1.Duration = 10000;

scene1 = create_scene(tc1,1);
run_scene(scene1);

idle(0);

set_iti(1000);
