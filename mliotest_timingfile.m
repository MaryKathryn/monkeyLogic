mglactivategraphic([Screen.EyeTracer Screen.JoystickCursor Screen.TouchCursor ...
    Screen.ButtonLabel Screen.ButtonPressed Screen.ButtonReleased Screen.TTL(:)'],false);

mglsetcontrolscreenzoom(1);
mglsetscreencolor(3,[0 0 0]);
fontsize = 12;
cs = mglgetcontrolscreenrect;
DPI_ratio = (cs(4)-cs(2)) / 600;
gap = 10 * DPI_ratio;
ML_LineEyeTracer = strcmpi('line',mglgettype(Screen.EyeTracer));

eye_frame = [50 50 200 200] * DPI_ratio;
eye_half = eye_frame(3:4) / 2;
eye_center = eye_frame(1:2) + eye_half;
eye_dim_color = MLConfig.EyeTracerColor * 0.5;
mglsetorigin(mgladdbox(eye_dim_color,eye_frame(3:4),4),eye_frame(1:2)+eye_frame(3:4)/2);
mglsetproperty(mgladdtext('Eye XY',4),'origin',[eye_frame(1)+eye_frame(3)/2 eye_frame(2)-gap],'halign',2,'valign',3,'fontsize',fontsize,'color',eye_dim_color);
if DAQ.eye_present
    eye_device = DAQ.get_device('eye');
    switch class(eye_device)
        case 'analoginput'
            eyex = eye_device.EyeX.InputRange;
            eyey = eye_device.EyeY.InputRange;
        otherwise
            eyex = [-10 10];
            eyey = [-10 10];
    end
    eye_range = [eyex(2) -eyey(2)];
    mglsetproperty(mgladdtext(sprintf('%d',eyex(1)),4),'origin',[eye_frame(1) sum(eye_frame([2 4]))+gap],'halign',2,'valign',1,'fontsize',fontsize,'color',eye_dim_color);
    mglsetproperty(mgladdtext(sprintf('%d',eyex(2)),4),'origin',[sum(eye_frame([1 3])) sum(eye_frame([2 4]))+gap],'halign',2,'valign',1,'fontsize',fontsize,'color',eye_dim_color);
    mglsetproperty(mgladdtext(sprintf('%d',eyey(2)),4),'origin',[eye_frame(1)-gap eye_frame(2)],'halign',3,'valign',2,'fontsize',fontsize,'color',eye_dim_color);
    mglsetproperty(mgladdtext(sprintf('%d',eyey(1)),4),'origin',[eye_frame(1)-gap sum(eye_frame([2 4]))],'halign',3,'valign',2,'fontsize',fontsize,'color',eye_dim_color);
    if ML_LineEyeTracer
        eye_tracer = mgladdline(MLConfig.EyeTracerColor,round(Screen.RefreshRate/2),1,4);
    else
        eye_tracer = load_cursor('',MLConfig.EyeTracerShape,MLConfig.EyeTracerColor,MLConfig.EyeTracerSize,4);
    end
    mglactivategraphic(eye_tracer,DAQ.eye_present);
else
    mglsetproperty(mgladdtext('Eye signals not assigned',4),'origin',eye_frame(1:2) + eye_frame(3:4)/2,'halign',2,'valign',2,'fontsize',fontsize,'color',MLConfig.EyeTracerColor);
end

joy_frame = [300 50 200 200] * DPI_ratio;
joy_half = joy_frame(3:4) / 2;
joy_center = joy_frame(1:2) + joy_half;
joy_dim_color = MLConfig.JoystickCursorColor * 0.5;
mglsetorigin(mgladdbox(joy_dim_color,joy_frame(3:4),4),joy_frame(1:2)+joy_frame(3:4)/2);
mglsetproperty(mgladdtext('Joystick XY',4),'origin',[joy_frame(1)+joy_frame(3)/2 joy_frame(2)-gap],'halign',2,'valign',3,'fontsize',fontsize,'color',joy_dim_color);
if DAQ.joystick_present
    joy_device = DAQ.get_device('joystick');
    joyx = joy_device.JoystickX.InputRange;
    joyy = joy_device.JoystickY.InputRange;
    joy_range = [joyx(2) -joyy(2)];
    mglsetproperty(mgladdtext(sprintf('%d',joyx(1)),4),'origin',[joy_frame(1) sum(joy_frame([2 4]))+gap],'halign',2,'valign',1,'fontsize',fontsize,'color',joy_dim_color);
    mglsetproperty(mgladdtext(sprintf('%d',joyx(2)),4),'origin',[sum(joy_frame([1 3])) sum(joy_frame([2 4]))+gap],'halign',2,'valign',1,'fontsize',fontsize,'color',joy_dim_color);
    mglsetproperty(mgladdtext(sprintf('%d',joyy(2)),4),'origin',[joy_frame(1)-gap joy_frame(2)],'halign',3,'valign',2,'fontsize',fontsize,'color',joy_dim_color);
    mglsetproperty(mgladdtext(sprintf('%d',joyy(1)),4),'origin',[joy_frame(1)-gap sum(joy_frame([2 4]))],'halign',3,'valign',2,'fontsize',fontsize,'color',joy_dim_color);
    joy_cursor = load_cursor(MLConfig.JoystickCursorImage,MLConfig.JoystickCursorShape,MLConfig.JoystickCursorColor,MLConfig.JoystickCursorSize,4);
    mglactivategraphic(joy_cursor,DAQ.joystick_present);
else
    mglsetproperty(mgladdtext('Joystick not assigned',4),'origin',joy_frame(1:2) + joy_frame(3:4)/2,'halign',2,'valign',2,'fontsize',fontsize,'color',MLConfig.JoystickCursorColor);
end

if DAQ.mouse_present
    touch_cursor = load_cursor(MLConfig.TouchCursorImage,MLConfig.TouchCursorShape,MLConfig.TouchCursorColor,MLConfig.TouchCursorSize,10);
    mglactivategraphic(touch_cursor,DAQ.mouse_present);
end

general = DAQ.general_available;
ngeneral = length(general);
general_color = MLConfig.TouchCursorColor;
general_dim_color = general_color * 0.5;
mglsetproperty(mgladdtext('General Input',4),'origin',[650 40] * DPI_ratio,'halign',2,'valign',3,'fontsize',fontsize,'color',general_dim_color);
if 0 < ngeneral
    general_h = min(round(550 / (ngeneral + 1)),100);
    general_pos = zeros(ngeneral,4);
    for m=1:ngeneral
        general_pos(m,:) = [550 50+(m-1)*general_h 200 general_h] * DPI_ratio;
        mglsetorigin(mgladdbox(general_dim_color,general_pos(m,3:4),4),general_pos(m,1:2) + general_pos(m,3:4)/2);
        mglsetproperty(mgladdtext(sprintf('%d',general(m)),4),'origin',general_pos(m,1:2) + [-gap general_pos(m,4)/2],'halign',3,'valign',2,'fontsize',fontsize,'color',general_dim_color);
    end
    general_id = NaN(ngeneral,1);
    for m=1:ngeneral, general_id(m) = mgladdline(general_color,general_pos(m,3)*10,1,4); end
else
    mglsetproperty(mgladdtext('No general input assigned',4),'origin',[650 150] * DPI_ratio,'halign',2,'valign',2,'fontsize',fontsize,'color',general_color);
end

load('mlimagedata.mat','green_pressed','green_released','stimulation_triggered','stimulation_dimmed','ttl_triggered','ttl_dimmed');
ButtonsAvailable = DAQ.buttons_available;
by = 300 + 30;
nbutton = length(ButtonsAvailable);
button_color = [1 1 1];
button_dim_color = button_color * 0.5;
mglsetproperty(mgladdtext('Button',4),'origin',[50 by-10] * DPI_ratio,'fontsize',fontsize,'color',button_dim_color);
if DAQ.button_present
    ButtonLabel = NaN(1,nbutton);
    ButtonPressed = NaN(1,nbutton);
    ButtonReleased = NaN(1,nbutton);
    ngreenbutton = sum(ButtonsAvailable <= DAQ.nButton(1));
    for m=1:nbutton
        DAQ.button_threshold(ButtonsAvailable(m),[]);
        ButtonLabel(m) = mgladdtext(sprintf('%d',ButtonsAvailable(m)),4);
        mglsetproperty(ButtonLabel(m),'halign',2,'fontsize',fontsize,'color',button_dim_color);

        if DAQ.nButton(1) < ButtonsAvailable(m)
            bx = 140 + (m-1-ngreenbutton)*40;
            ButtonPressed(m) = mgladdbitmap(mglimresize(green_pressed,DPI_ratio),4);
            ButtonReleased(m) = mgladdbitmap(mglimresize(green_released,DPI_ratio),4);
            mglsetorigin([ButtonLabel(m) ButtonPressed(m) ButtonReleased(m)],[bx by+20; bx by+50; bx by+50] * DPI_ratio);
        else
            bx = 140 + (m-1)*40;
            ButtonPressed(m) = mgladdbitmap(mglimresize(green_pressed,DPI_ratio),4);
            ButtonReleased(m) = mgladdbitmap(mglimresize(green_released,DPI_ratio),4);
            mglsetorigin([ButtonLabel(m) ButtonPressed(m) ButtonReleased(m)],[bx by-30; bx by; bx by] * DPI_ratio);
        end
    end
else
    mglsetproperty(mgladdtext('No button assigned',4),'origin',[140 by] * DPI_ratio,'halign',1,'valign',2,'fontsize',fontsize,'color',button_color);
end

by = by + 150;
STMAvailable = DAQ.stimulation_available;
nstimulation = length(STMAvailable);
STM_color = [1 1 1];
STM_dim_color = STM_color * 0.5;
mglsetproperty(mgladdtext('STM',4),'origin',[50 by-10] * DPI_ratio,'fontsize',fontsize,'color',STM_dim_color);
if 0 < nstimulation
    STM = NaN(2,nstimulation);
    STM_pos = zeros(nstimulation,4);
    for m=1:nstimulation
        STM(1,m) = mgladdtext(sprintf('%d',STMAvailable(m)),4);
        STM(2,m) = mgladdbitmap(mglimresize(stimulation_dimmed,DPI_ratio),4);
        STM(3,m) = mgladdbitmap(mglimresize(stimulation_triggered,DPI_ratio),4);

        bx = 140 + (m-1)*40;
        mglsetproperty(STM(1,m),'halign',2,'fontsize',fontsize,'color',STM_dim_color);
        mglsetorigin(STM(:,m), [bx by-30; bx by; bx by] * DPI_ratio);
        STM_pos(m,:) = [bx-15 by-15 bx+15 by+15] * DPI_ratio;
    end
else
    mglsetproperty(mgladdtext('No stimulation assigned',4),'origin',[140 by] * DPI_ratio,'halign',1,'valign',2,'fontsize',fontsize,'color',STM_color);
end

by = by + 50;
TTLAvailable = DAQ.ttl_available;
nttl = length(TTLAvailable);
TTL_color = [1 1 1];
TTL_dim_color = STM_color * 0.5;
mglsetproperty(mgladdtext('TTL',4),'origin',[50 by-10] * DPI_ratio,'fontsize',fontsize,'color',TTL_dim_color);
if 0 < nttl
    TTL = NaN(2,nttl);
    TTL_pos = zeros(nttl,4);
    for m=1:nttl
        TTL(1,m) = mgladdtext(sprintf('%d',TTLAvailable(m)),4);
        TTL(2,m) = mgladdbitmap(mglimresize(ttl_dimmed,DPI_ratio),4);
        TTL(3,m) = mgladdbitmap(mglimresize(ttl_triggered,DPI_ratio),4);

        bx = 140 + (m-1)*40;
        mglsetproperty(TTL(1,m),'halign',2,'fontsize',fontsize,'color',TTL_dim_color);
        mglsetorigin(TTL(:,m), [bx by-30; bx by; bx by] * DPI_ratio);
        TTL_pos(m,:) = [bx-15 by-15 bx+15 by+15] * DPI_ratio;
    end
else
    mglsetproperty(mgladdtext('No TTL assigned',4),'origin',[140 by] * DPI_ratio,'halign',1,'valign',2,'fontsize',fontsize,'color',TTL_color);
end

mglsetproperty(mgladdtext('ESC',4),'origin',[412 590] * DPI_ratio,'valign',3,'fontsize',fontsize,'color',[1 1 1]);
mglsetproperty(mgladdtext('Click the icons above to test STMs and TTLs. To quit, press ESC.',4),'origin',[10 590] * DPI_ratio,'valign',3,'fontsize',fontsize,'color',[0.5 0.5 0.5]);

esc_size = [40 20];
esc_center = [427 580*DPI_ratio];
esc_pos = [esc_center esc_center] + [-esc_size esc_size]/2;
% esc_id = mgladdbox([1 1 1],esc_size,4);
% mglsetorigin(esc_id,esc_center * DPI_ratio);

cs = mglgetcontrolscreenrect;
count = 0;
last_selected_STM = [];
last_selected_TTL = [];
kbdinit;
while true
    getsample(DAQ);
    
    if DAQ.eye_present
        eye = DAQ.Eye ./ eye_range .* eye_half + eye_center;
        if ML_LineEyeTracer
            mglsetproperty(eye_tracer,'addpoint',eye);
        else
            mglsetorigin(eye_tracer,eye);
        end
    end
    if DAQ.joystick_present
        mglsetorigin(joy_cursor,DAQ.Joystick ./ joy_range .* joy_half + joy_center);
    end
    if DAQ.mouse_present
        if any(DAQ.MouseButton)
            touch = DAQ.Mouse - Screen.SubjectScreenRect(1:2);
            mglsetorigin(touch_cursor,touch);
            mglactivategraphic(touch_cursor,true);
        else
            mglactivategraphic(touch_cursor,false);
        end
    end
    for m=1:ngeneral
        mglsetproperty(general_id(m),'addpoint',general_pos(m,1:2) + [count*DPI_ratio (DAQ.General(general(m))/11-1)*general_pos(m,4)/-2]);
    end
    if DAQ.button_present
        mglactivategraphic(ButtonPressed,DAQ.Button(ButtonsAvailable));
        mglactivategraphic(ButtonReleased,~DAQ.Button(ButtonsAvailable));
    end

    [xy,buttons] = getsample(ML_Mouse);
    xy = xy - cs(1:2);
    if 0 < nstimulation
        selected = find(STM_pos(:,1)<xy(1) & xy(1)<STM_pos(:,3) & STM_pos(:,2)<xy(2) & xy(2)<STM_pos(:,4),1);
        if ~isempty(selected) && isempty(last_selected_STM) && isempty(last_selected_TTL)
            mglsetproperty(STM(1,selected),'color',[1 1 1]);
            if any(buttons)
                ao = DAQ.Stimulation{STMAvailable(selected)};
                ao.TriggerType = 'Immediate';
                ao.SampleRate = 40;
                ch = ao.(sprintf('Stimulation%d',STMAvailable(selected))).Index;
                data = zeros(12,length(ao.Channel));
                data(:,ch) = [0 repmat([5 -5],1,5) 0]';
                putdata(ao,data);
                start(ao);
                mglactivategraphic(STM(2,selected),false);
                last_selected_STM = selected;
            end
        elseif ~any(buttons) && isempty(last_selected_STM)
            mglsetproperty(STM(1,:),'color',[0.5 0.5 0.5]);
        end
        if ~isempty(last_selected_STM) && ~any(buttons) && ~isrunning(DAQ.Stimulation{STMAvailable(last_selected_STM)})
            stop(DAQ.Stimulation{STMAvailable(last_selected_STM)});
            mglsetproperty(STM(1,last_selected_STM),'color',[0.5 0.5 0.5]);
            mglactivategraphic(STM(2,last_selected_STM),true);
            last_selected_STM = [];
        end
    end
    if 0 < nttl
        selected = find(TTL_pos(:,1)<xy(1) & xy(1)<TTL_pos(:,3) & TTL_pos(:,2)<xy(2) & xy(2)<TTL_pos(:,4),1);
        if ~isempty(selected) && isempty(last_selected_STM) && isempty(last_selected_TTL)
            mglsetproperty(TTL(1,selected),'color',[1 1 1]);
            if any(buttons)
                putvalue(DAQ.TTL{TTLAvailable(selected)},1);
                mglactivategraphic(TTL(2,selected),false);
                last_selected_TTL = selected;
            end
        elseif ~any(buttons)
            mglsetproperty(TTL(1,:),'color',[0.5 0.5 0.5]);
        end
        if ~isempty(last_selected_TTL) && ~any(buttons)
            putvalue(DAQ.TTL{TTLAvailable(last_selected_TTL)},0);
            mglsetproperty(TTL(1,last_selected_TTL),'color',[0.5 0.5 0.5]);
            mglactivategraphic(TTL(2,last_selected_TTL),true);
            last_selected_TTL = [];
        end
    end
    
    mglrendergraphic(0);
    mglpresent();
    
    if 0 < ngeneral
        count = count + 1;
        if 200<=count, count = 0; mglsetproperty(general_id,'clear'); end
    end

    kb = kbdgetkey;
    if ~isempty(kb)
        switch kb
            case 1
                for m=STMAvailable, stop(DAQ.Stimulation{m}); DAQ.Stimulation{m}.TriggerType = 'Manual'; end
                for m=TTLAvailable, putvalue(DAQ.TTL{m},0); end
                break
        end
    end
    if any(buttons) && (esc_pos(1)<xy(1) && xy(1)<esc_pos(3) && esc_pos(2)<xy(2) && xy(2)<esc_pos(4)), break, end
end
