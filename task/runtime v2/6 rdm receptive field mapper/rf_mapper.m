if ~exist('touch_','var'), error('This demo requires the touch input. Please enable it in the main menu or try the simulation mode.'); end
hotkey('x', 'escape_screen(); assignin(''caller'',''continue_'',false);');
showcursor(false);  % remove the joystick cursor

dashboard(4,'Move: Left click + Drag',[0 1 0]);
dashboard(5,'Resize: Right click + Drag',[0 1 0]);
dashboard(6,'Press ''x'' to quit.',[1 0 0]);

Coherence = 100;
NumDot = 100;
DotSize = 0.15;
DotColor = [1 1 1];
editable('Coherence','NumDot','DotSize','-color','DotColor');

rdm1 = RDM_RF_Mapper(touch_);
rdm1.Position = [0 0];
rdm1.Radius = 5;
rdm1.Coherence = Coherence;
rdm1.NumDot = NumDot;
rdm1.DotSize = DotSize;
rdm1.DotColor = DotColor;

scene1 = create_scene(rdm1);
run_scene(scene1);

idle(0);

bhv_variable('position',rdm1.Position);
bhv_variable('radius',rdm1.Radius);
bhv_variable('direction',fi(rdm1.Direction<0,rdm1.Direction+360,rdm1.Direction));
