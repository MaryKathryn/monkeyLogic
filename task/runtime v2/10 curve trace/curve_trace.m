if ~exist('eye_','var'), error('This demo requires eye input. Please enable it in the main menu or try the simulation mode.'); end
hotkey('x', 'escape_screen(); assignin(''caller'',''continue_'',false);');
showcursor(false);  % remove the joystick cursor

% choose patterns
switch mod(TrialRecord.CurrentCondition-1,6)
    case 0  % Lissajous curve
        str = 'Lissajous curve';
        t = linspace(0,2*pi,1000)';
        x = 6 * sin(3*t);
        y = 9 * sin(4*t)./1.5;
    case 1  % flower
        str = 'Flower';
        t = linspace(pi/2,3*pi/2,1000)';
        x = 6*cos(5*t).*cos(t);
        y = 6*cos(5*t).*sin(t);
    case 2  % heart
        str = 'Heart';
        t = linspace(2*pi,4*pi,500)';
        x = (12*sin(t).^3)/2;
        y = (10*cos(t)-8*cos(2*t)-2*cos(3*t)-cos(4*t))/3;
    case 3  % lemniscate of Bernoulli
        str = 'Lemniscate of Bernoulli';
        t = linspace(pi/2,5*pi/2,500)';
        a = 11;
        x = a.*cos(t)./(1+sin(t).^2)./1.5;
        y = (a.*sin(t).*cos(t))./(1+sin(t).^2); 
    case 4  % butterfly
        str = 'Butterfly';
        t = linspace(0,2*pi,1500)';
        x = (sin(t).*3.*((exp(cos(t))-2.*cos(4.*t)-(sin(t/12).^5))))./1.5;
        y = (cos(t).*3.*(exp(cos(t))-2.*cos(4.*t)-(sin(t/12).^5)))./1.5- 1.4366;
    case 5  % cycloid
        str = 'Cycloid';
        t = linspace(3*pi,9*pi,1500)';
        a = 7; b = 3; 
        x = ((a-b)*cos(t)+b*cos((a/b-1).*t)+1)/0.8; 
        y = (a-b)*sin(t)+b*sin((a/b-1).*t)/1.3;
end

% create scenes
trace1 = CurveTracer(eye_);
trace1.Target = 1;
trace1.Trajectory = [x y];
trace1.Step = 1;  % target position update interval, in # of frames
scene1 = create_scene(trace1,1);

% task
dashboard(1,'Curve Tracer',[0 1 0]);
dashboard(2,sprintf('Pattern: %s',str));
dashboard(3,'Press ''x'' to quit.',[1 0 0]);

run_scene(scene1);

idle(1000);
