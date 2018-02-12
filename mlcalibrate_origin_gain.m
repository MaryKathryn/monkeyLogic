function tform = mlcalibrate_origin_gain(EyeOrJoy,MLConfig)

daqcreated = false;
% if ~exist('EyeOrJoy','var'), EyeOrJoy = 1; end
% if ~exist('MLConfig','var')
%     MLConfig = mlconfig;
%     MLConfig.Touchscreen = false;
%     MLConfig.RewardPolarity = 1;
%     MLConfig.EyeTransform = cell(1,3);
%     MLConfig.EyeCalibration = 2;
%     MLConfig.JoystickTransform = cell(1,3);
%     MLConfig.JoystickCalibration = 2;
%     switch EyeOrJoy
%         case 1, entry = {'Eye X','nidaq','Dev1','AnalogInput',0,[]; 'Eye Y','nidaq','Dev1','AnalogInput',1,[]};
%         case 2, entry = {'Joystick X','nidaq','Dev1','AnalogInput',0,[]; 'Joystick Y','nidaq','Dev1','AnalogInput',1,[]};
%     end
%     entry = [entry; {'Reward','nidaq','Dev1','DigitalIO',0,{0,'out'}}];
%     MLConfig.IO = cell2struct(entry,{'SignalType','Adaptor','DevID','Subsystem','Channel','DIOInfo'},2);
%     MLConfig.MLPath.BaseDirectory = which('monkeylogic.m');
%     create(MLConfig.DAQ,MLConfig);
%     daqcreated = true;
% end

% remember the current settings
switch EyeOrJoy
    case 1, old_tform = MLConfig.EyeTransform{MLConfig.EyeCalibration};
    case 2, old_tform = MLConfig.JoystickTransform{MLConfig.JoystickCalibration};
end
CalFun = mlcalibrate(EyeOrJoy,MLConfig);
tform = copyfield(init_tform(),CalFun.get_transform_matrix());
mglscreenscreated = false(1,2);
mglcontrolscreeninfo = mglgetscreeninfo(2);
[mglobjectid,~,mglobjectstatus] = mglgetallobjects();

DAQ = MLConfig.DAQ;
Screen = MLConfig.Screen;
if ~mglsubjectscreenexists, create(Screen,MLConfig); mglscreenscreated(1) = true; end

% value ranges
operator_view_range = [5 300];
switch class(get_device(DAQ,EyeOrJoy))
    case 'analoginput'
        info = daqhwinfo(get_device(DAQ,EyeOrJoy));
        [~,i]=max(info.InputRanges(:,2),[],1);
        origin_range = info.InputRanges(i,:);
    otherwise, origin_range = [-10 10];
end
gain_range = [-20 20];
fixinterval_range = [0.5 100];

% validate input
tform.origin = min([max([tform.origin; repmat(origin_range(1),1,2)],[],1); repmat(origin_range(2),1,2)],[],1);
tform.gain = min([max([tform.gain; repmat(gain_range(1),1,2)],[],1); repmat(gain_range(2),1,2)],[],1);
if ~isfield(tform.RewardFuncArgs,'JuiceLine'), tform.RewardFuncArgs.JuiceLine = 1; end

% variables
hFig = [];
exit_code = 0;
fixpoint_id = [];
fixpoint_pos = [];
picked_target = [];
picked_target_id = [];
islinetracer = false;
ControlScreenRect = zeros(1,4);
tracer = [];
show_fixationpoint = false;
mouse = [];
mouse_created = false;
prev_eye_position = [];

% open the dialog
try
    init();
    run_scene();
    if ishandle(hFig), close(hFig); end
catch err
    if ishandle(hFig), close(hFig); end
    rethrow(err);
end
% end of the dialog

    % methods
    function tform = init_tform()
        tform.operator_view = 120;
        tform.origin = [0 0];
        tform.gain = [1 1];
        tform.rotation = 0;
        tform.rotation_t = eye(2);
        tform.rotation_rev_t = eye(2);
        tform.fiximage = '';
        tform.fixshape = 2;
        tform.fixcolor = [1 1 0];
        tform.fixsize = 0.6;
        tform.fixinterval = 5;

        if 1==EyeOrJoy
            tform.windowsize = 2;
            tform.waittime = 2000;
        else
            tform.windowsize = 0.5;
            tform.waittime = 30000;
        end
        tform.holdtime = 600;
        tform.jittertolerance = 20;
		r = MLConfig.RewardFuncArgs;
        tform.RewardFuncArgs = struct('JuiceLine',1,'Duration',100,'NumReward',1,'PauseTime',40,'TriggerVal',r.TriggerVal,'Custom',r.Custom);
    end

    function run_scene()
        frame_counter = 0;
        while 0==exit_code
            [xy,buttons] = getsample(mouse);
            if xy(1)<ControlScreenRect(1) || xy(2)<ControlScreenRect(2) || ControlScreenRect(3)<xy(1) || ControlScreenRect(4)<xy(2), buttons(:) = false; end
            switch EyeOrJoy
                case 1
                    if isempty(picked_target_id)
                        if any(buttons), picked_target = find(isinside(CalFun.control2pix(xy)),1); end
                        if ~isempty(picked_target), show_fixationpoint = true; end
                    else
                        show_fixationpoint = false;
                    end
                case 2
                    if any(buttons)
                        picked = find(isinside(CalFun.control2pix(xy)),1);
                        if ~isempty(picked)
                            picked_target = picked;
                            show_fixationpoint = true;
                        end
                    end
            end
            if show_fixationpoint
                if ~isempty(picked_target_id), mgldestroygraphic(picked_target_id); end
                picked_target_id = [load_cursor(tform.fiximage,tform.fixshape,tform.fixcolor,tform.fixsize*MLConfig.PixelsPerDegree(1), 1) ...
                    mgladdcircle([0 1 0],tform.windowsize*MLConfig.PixelsPerDegree(1)*2,10)];
                mglsetorigin(picked_target_id,fixpoint_pos(picked_target,:));
                waittimer = tic;
                waiting = true;
                frame_counter = 0;
                show_fixationpoint = false;
            end                
            
            peekfront(DAQ);
            if 1==EyeOrJoy, data = DAQ.Eye; else data = DAQ.Joystick; end
            if ~isempty(data)
                if ~isempty(picked_target)
                    good = all(sum((CalFun.sig2pix(data,[0 0])-repmat(fixpoint_pos(picked_target,:),size(data,1),1)).^2,2) < (tform.windowsize*MLConfig.PixelsPerDegree(1))^2);
                    done = false;
                    success = false;

                    if ~good &&  waiting, done = tform.waittime < toc(waittimer)*1000; end
                    if  good &&  waiting, waiting = false; holdtimer = tic; end
                    if ~good && ~waiting
                        switch EyeOrJoy
                            case 1, done = tform.jittertolerance < toc(holdtimer)*1000;
                            case 2, waiting = tform.jittertolerance < toc(holdtimer)*1000;
                        end
                    end
                    if  good && ~waiting, done = tform.holdtime < toc(holdtimer)*1000; success = done; end

                    if done
                        if success, DAQ.goodmonkey(tform.RewardFuncArgs.Duration,'juiceline',tform.RewardFuncArgs.JuiceLine); end
                        mgldestroygraphic(picked_target_id);
                        picked_target_id = [];
                        picked_target = [];
                    end
                end
                
                if islinetracer, mglsetproperty(tracer,'addpoint',CalFun.sig2pix(data,[0 0])); else mglsetorigin(tracer,CalFun.sig2pix(data(end,:),[0 0])); end
            end

            kb = kbdgetkey();
            if ~isempty(kb)
                switch kb
                    case 1,  exit_code = -1;  % esc
                    case 12, tform.RewardFuncArgs.Duration = max(0,tform.RewardFuncArgs.Duration-10);  % -
                    case 13, tform.RewardFuncArgs.Duration = tform.RewardFuncArgs.Duration + 10;  % =
                    case 19, DAQ.goodmonkey(tform.RewardFuncArgs.Duration,'juiceline',tform.RewardFuncArgs.JuiceLine);  % r
                    case 57, setorigin(); update_UI();  % space
                end
                if 1==EyeOrJoy
                    switch kb
                        case 22  % u
                            if ~isempty(prev_eye_position)
                                tform = copyfield(tform,CalFun.translate(-prev_eye_position(end,:)),{'origin'});
                                tform.origin = max(origin_range(1),min(origin_range(2),round(tform.origin*100)/100));
                                prev_eye_position(end,:) = [];
                                CalFun.set_transform_matrix(tform);
                                update_UI();
                            end
                        case 46  % c
                            if  ~isempty(data)
                                prev_eye_position(end+1,:) = CalFun.sig2deg(data(end,:),[0 0]); %#ok<AGROW>
                                tform = copyfield(tform,CalFun.translate(prev_eye_position(end,:)),{'origin'});
                                tform.origin = max(origin_range(1),min(origin_range(2),round(tform.origin*100)/100));
                                CalFun.set_transform_matrix(tform);
                                update_UI();
                            end
                    end
                end
            end
                
            mglrendergraphic(frame_counter);
            mglpresent();
            frame_counter = frame_counter + 1; 
            if 0==mod(frame_counter,2), drawnow; end
        end
    end

    function init()
        fontsize = 9;
        bgcolor = [0.9255 0.9137 0.8471];
        callbackfunc = @UIcallback;

        h = findobj('tag','mlmonitor');
        if isempty(h), h = findobj('tag','mlmainmenu'); end
        if isempty(h), pos = GetMonitorPosition(mglgetcommandwindowrect); else pos = get(h,'position'); end
        screen_pos = GetMonitorPosition(Pos2Rect(pos));
        
        fw = 850;
        fh = 600;
        fx = pos(1) + 0.5 * (pos(3) - fw);
        if fx < screen_pos(1), fx = screen_pos(1) + 8; end
        fy = min(pos(2) + 0.5 * (pos(4) - fh),sum(screen_pos([2 4])) - fh - 30);
        fig_pos = [fx fy fw fh];

        hFig = figure;
        set(hFig, 'position',fig_pos, 'numbertitle','off', 'name',[fi(1==EyeOrJoy,'Eye','Joystick') ' calibration: Origin & Gain'], 'units','pixel', 'menubar','none', 'resize','off', 'windowstyle','modal', 'color',bgcolor);
        
        set(hFig, 'closerequestfcn', @closeDlg);
        warning('off','MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame');
        jFrame = get(hFig, 'JavaFrame');
        jAxis = jFrame.getAxisComponent;
        if verLessThan('matlab','8.4')
            hAxis = handle(jAxis, 'CallbackProperties');
            set(hAxis,'AncestorMovedCallback',@on_move);
        else
            set(jAxis.getComponent(0),'AncestorMovedCallback',@on_move);
        end
        
        x0 = 605; y0 = 570;

        axes('parent',hFig, 'tag','mlcalibrate', 'units','pixel', 'position',[0 0 fh fh], 'color',MLConfig.SubjectScreenBackground, 'xtick',[], 'ytick',[]);
        
        uicontrol('parent',hFig, 'style','text', 'units','pixel', 'position',[x0 y0 65 22], 'string','Zoom (%) :', 'backgroundcolor',bgcolor, 'fontsize',fontsize, 'horizontalalignment','right');
        uicontrol('parent',hFig, 'style','edit', 'tag','operatorview1', 'units','pixel', 'position',[x0+70 y0+2 37 21], 'fontsize',fontsize, 'callback',callbackfunc);
        uicontrol('parent',hFig, 'style','slider', 'tag','operatorview2', 'min',operator_view_range(1), 'max',operator_view_range(2), 'sliderstep',[1 10]./(operator_view_range(2)-operator_view_range(1)), 'value',operator_view_range(1), 'units','pixel', 'position',[x0+115 y0+4 125 17], 'fontsize',fontsize, 'callback',callbackfunc);

        y0 = y0 - 35;
        uicontrol('parent',hFig, 'style','text', 'units','pixel', 'position',[x0 y0 65 22], 'string','Origin X :', 'backgroundcolor',bgcolor, 'fontsize',fontsize, 'horizontalalignment','right');
        uicontrol('parent',hFig, 'style','edit', 'tag','originx1', 'units','pixel', 'position',[x0+70 y0+2 37 21], 'fontsize',fontsize, 'callback',callbackfunc);
        uicontrol('parent',hFig, 'style','slider', 'tag','originx2', 'min',origin_range(1), 'max',origin_range(2), 'sliderstep',[0.01 0.1]./(origin_range(2)-origin_range(1)), 'value',origin_range(1), 'units','pixel', 'position',[x0+115 y0+4 125 17], 'fontsize',fontsize, 'callback',callbackfunc);

        y0 = y0 - 30;
        uicontrol('parent',hFig, 'style','text', 'units','pixel', 'position',[x0 y0 65 22], 'string','Origin Y :', 'backgroundcolor',bgcolor, 'fontsize',fontsize, 'horizontalalignment','right');
        uicontrol('parent',hFig, 'style','edit', 'tag','originy1', 'units','pixel', 'position',[x0+70 y0+2 37 21], 'fontsize',fontsize, 'callback',callbackfunc);
        uicontrol('parent',hFig, 'style','slider', 'tag','originy2', 'min',origin_range(1), 'max',origin_range(2), 'sliderstep',[0.01 0.1]./(origin_range(2)-origin_range(1)), 'value',origin_range(1), 'units','pixel', 'position',[x0+115 y0+4 125 17], 'fontsize',fontsize, 'callback',callbackfunc);

        y0 = y0 - 30;
        uicontrol('parent',hFig, 'style','text', 'units','pixel', 'position',[x0 y0 65 22], 'string','Gain X :', 'backgroundcolor',bgcolor, 'fontsize',fontsize, 'horizontalalignment','right');
        uicontrol('parent',hFig, 'style','edit', 'tag','gainx1', 'units','pixel', 'position',[x0+70 y0+2 37 21], 'fontsize',fontsize, 'callback',callbackfunc);
        uicontrol('parent',hFig, 'style','slider', 'tag','gainx2', 'min',gain_range(1), 'max',gain_range(2), 'sliderstep',[0.01 0.1]./(gain_range(2)-gain_range(1)), 'value',gain_range(1), 'units','pixel', 'position',[x0+115 y0+4 125 17], 'fontsize',fontsize, 'callback',callbackfunc);

        y0 = y0 - 30;
        uicontrol('parent',hFig, 'style','text', 'units','pixel', 'position',[x0 y0 65 22], 'string','Gain Y :', 'backgroundcolor',bgcolor, 'fontsize',fontsize, 'horizontalalignment','right');
        uicontrol('parent',hFig, 'style','edit', 'tag','gainy1', 'units','pixel', 'position',[x0+70 y0+2 37 21], 'fontsize',fontsize, 'callback',callbackfunc);
        uicontrol('parent',hFig, 'style','slider', 'tag','gainy2', 'min',gain_range(1), 'max',gain_range(2), 'sliderstep',[0.01 0.1]./(gain_range(2)-gain_range(1)), 'value',gain_range(1), 'units','pixel', 'position',[x0+115 y0+4 125 17], 'fontsize',fontsize, 'callback',callbackfunc);

        y0 = y0 - 30;
        uicontrol('parent',hFig, 'style','text', 'units','pixel', 'position',[x0 y0 65 22], 'string','Rotation :', 'backgroundcolor',bgcolor, 'fontsize',fontsize, 'horizontalalignment','right');
        uicontrol('parent',hFig, 'style','edit', 'tag','rotation1', 'units','pixel', 'position',[x0+70 y0+2 37 21], 'fontsize',fontsize, 'callback',callbackfunc);
        uicontrol('parent',hFig, 'style','slider', 'tag','rotation2', 'min',-180, 'max',180, 'sliderstep',[1 10]./360, 'value',0, 'units','pixel', 'position',[x0+115 y0+4 125 17], 'fontsize',fontsize, 'callback',callbackfunc);

        y0 = y0 - 30;
        uicontrol('parent',hFig, 'style','pushbutton', 'tag','showorigin', 'string','Show Center', 'units','pixel', 'position',[x0+13 y0+2 110 24], 'fontsize',fontsize, 'callback',callbackfunc);
        uicontrol('parent',hFig, 'style','pushbutton', 'tag','setorigin', 'string','Set Origin (Space)', 'units','pixel', 'position',[x0+130 y0+2 110 24], 'fontsize',fontsize, 'callback',callbackfunc);

        y0 = y0 - 45;
        uicontrol('parent',hFig, 'style','text', 'units','pixel', 'position',[x0 y0 85 22], 'string','Fixation point :', 'backgroundcolor',bgcolor, 'fontsize',fontsize, 'horizontalalignment','right');
        uicontrol('parent',hFig, 'style','pushbutton', 'tag','fiximage', 'units','pixel', 'position',[x0+90 y0+2 150 24], 'fontsize',fontsize, 'callback',callbackfunc);

        y0 = y0 - 30;
        uicontrol('parent',hFig, 'style','popupmenu', 'tag','fixshape', 'units','pixel', 'position',[x0+28 y0 70 24], 'string',{'Circle','Square'}, 'fontsize',fontsize, 'callback',callbackfunc);
        uicontrol('parent',hFig, 'style','pushbutton', 'tag','fixcolor', 'units','pixel', 'position',[x0+105 y0+2 64 24], 'string','Color', 'fontsize',fontsize, 'callback',callbackfunc);
        uicontrol('parent',hFig, 'style','edit', 'tag','fixsize', 'units','pixel', 'position',[x0+175 y0+4 37 21], 'fontsize',fontsize, 'callback',callbackfunc);
        uicontrol('parent',hFig, 'style','text', 'units','pixel', 'position',[x0+215 y0 110 22], 'string','deg', 'backgroundcolor',bgcolor, 'fontsize',fontsize, 'horizontalalignment','left');

        y0 = y0 - 30;
        uicontrol('parent',hFig, 'style','text', 'units','pixel', 'position',[x0+28 y0 110 22], 'string','at', 'backgroundcolor',bgcolor, 'fontsize',fontsize, 'horizontalalignment','left');
        uicontrol('parent',hFig, 'style','edit', 'tag','fixinterval', 'units','pixel', 'position',[x0+50 y0+3 37 21], 'fontsize',fontsize, 'callback',callbackfunc);
        uicontrol('parent',hFig, 'style','text', 'units','pixel', 'position',[x0+95 y0 100 22], 'string','deg intervals', 'backgroundcolor',bgcolor, 'fontsize',fontsize, 'horizontalalignment','left');

        y0 = y0 - 45;
        uicontrol('parent',hFig, 'style','text', 'units','pixel', 'position',[x0 y0 140 22], 'string','Fixation window radius :', 'backgroundcolor',bgcolor, 'fontsize',fontsize, 'horizontalalignment','right');
        uicontrol('parent',hFig, 'style','edit', 'tag','windowsize', 'units','pixel', 'position',[x0+145 y0+3 45 21], 'fontsize',fontsize, 'callback',callbackfunc);
        uicontrol('parent',hFig, 'style','text', 'units','pixel', 'position',[x0+195 y0 110 22], 'string','degrees', 'backgroundcolor',bgcolor, 'fontsize',fontsize, 'horizontalalignment','left');
        
        y0 = y0 - 30;
        uicontrol('parent',hFig, 'style','text', 'units','pixel', 'position',[x0 y0 140 22], 'string','Fixation wait time :', 'backgroundcolor',bgcolor, 'fontsize',fontsize, 'horizontalalignment','right');
        uicontrol('parent',hFig, 'style','edit', 'tag','waittime', 'units','pixel', 'position',[x0+145 y0+3 45 21], 'fontsize',fontsize, 'callback',callbackfunc);
        uicontrol('parent',hFig, 'style','text', 'units','pixel', 'position',[x0+195 y0 110 22], 'string','msec', 'backgroundcolor',bgcolor, 'fontsize',fontsize, 'horizontalalignment','left');

        y0 = y0 - 30;
        uicontrol('parent',hFig, 'style','text', 'units','pixel', 'position',[x0 y0 140 22], 'string','Fixation hold time :', 'backgroundcolor',bgcolor, 'fontsize',fontsize, 'horizontalalignment','right');
        uicontrol('parent',hFig, 'style','edit', 'tag','holdtime', 'units','pixel', 'position',[x0+145 y0+3 45 21], 'fontsize',fontsize, 'callback',callbackfunc);
        uicontrol('parent',hFig, 'style','text', 'units','pixel', 'position',[x0+195 y0 110 22], 'string','msec', 'backgroundcolor',bgcolor, 'fontsize',fontsize, 'horizontalalignment','left');

        y0 = y0 - 45;
        uicontrol('parent',hFig, 'style','pushbutton', 'tag','rewardoptions', 'units','pixel', 'position',[x0+10 y0+2 220 24], 'fontsize',fontsize, 'callback',callbackfunc);

        y0 = 10;
        uicontrol('parent',hFig, 'style','pushbutton', 'tag','savebutton', 'units','pixel', 'position',[x0+13 y0+2 110 24], 'string','Save', 'fontsize',fontsize, 'callback',callbackfunc);
        uicontrol('parent',hFig, 'style','pushbutton', 'tag','cancelbutton', 'units','pixel', 'position',[x0+130 y0+2 110 24], 'string','Cancel (ESC)', 'fontsize',fontsize, 'callback',callbackfunc);

        fig_pos(3) = fig_pos(4);
        if mglcontrolscreenexists()
            pause(0.3);
            mglactivategraphic(mglobjectid,false);
            mglsetcontrolscreenrect(Pos2Rect(fig_pos));
            mglsetcontrolscreenshow(true);
        else
            mglscreenscreated(2) = true;
            mglcreatecontrolscreen(Pos2Rect(fig_pos));
        end
        mglsetcontrolscreenzoom(tform.operator_view/100);
        update_controlscreen_geometry();
        update_calib_func();        
        update_fixpoint();
        
        switch EyeOrJoy
            case 1
                switch lower(MLConfig.EyeTracerShape)
                    case 'line', islinetracer = true; tracer = mgladdline(MLConfig.EyeTracerColor,50,1,10);
                    otherwise, tracer = load_cursor('', MLConfig.EyeTracerShape, MLConfig.EyeTracerColor, MLConfig.EyeTracerSize, 10);
                end
            case 2, tracer = load_cursor(MLConfig.JoystickCursorImage, MLConfig.JoystickCursorShape, MLConfig.JoystickCursorColor, MLConfig.JoystickCursorSize, 11);
        end

        r = tform.RewardFuncArgs;
        DAQ.goodmonkey(r.Duration,'eval',sprintf('ML_WarmingUp=true;NumReward=%d;PauseTime=%d;TriggerVal=%d;%s',r.NumReward,r.PauseTime,r.TriggerVal,r.Custom));

        mouse = DAQ.get_device('mouse');
        if isempty(mouse), mouse = pointingdevice('mouse',0); mouse_created = true; end
        stop(DAQ);
        start(DAQ);
        while 0==DAQ.MinSamplesAvailable, end

        update_UI();
        kbdinit;

        if DAQ.reward_present
            mglsetorigin(mgladdtext('R key: Manual reward',12), [10 10]);
            mglsetorigin(mgladdtext('+ key: Increase reward by 10 ms',12), [10 30]);
            mglsetorigin(mgladdtext('- key: Decrease reward by 10 ms',12), [10 50]);
        end
    end

    function UIcallback(hObject,~)
        obj_tag = get(hObject,'tag');
        switch lower(obj_tag)
            case 'operatorview1'
                val = round(str2double(get(gcbo,'string')));
                if operator_view_range(1)<=val && val<=operator_view_range(2), tform.operator_view = val; end
                mglsetcontrolscreenzoom(tform.operator_view/100);
                update_controlscreen_geometry();

            case 'operatorview2'
                val = round(get(gcbo,'value'));
                if operator_view_range(1)<=val && val<=operator_view_range(2), tform.operator_view = val; end
                mglsetcontrolscreenzoom(tform.operator_view/100);
                update_controlscreen_geometry();

            case {'originx1','originy1'}
                val = [str2double(get(findobj(hFig,'tag','originx1'),'string')) str2double(get(findobj(hFig,'tag','originy1'),'string'))];
                val = round(val*100)/100;
                if all(origin_range(1)<=val) && all(val<=origin_range(2)), tform.origin = val; end
                update_calib_func();

            case {'originx2','originy2'}
                val = [get(findobj(hFig,'tag','originx2'),'value') get(findobj(hFig,'tag','originy2'),'value')];
                val = round(val*100)/100;
                if all(origin_range(1)<=val) && all(val<=origin_range(2)), tform.origin = val; end
                update_calib_func();

            case {'gainx1','gainy1'}
                val = [str2double(get(findobj(hFig,'tag','gainx1'),'string')) str2double(get(findobj(hFig,'tag','gainy1'),'string'))];
                val = round(val*100)/100;
                if all(0~=val) && all(gain_range(1)<=val) && all(val<=gain_range(2)), tform.gain = val; end
                update_calib_func();

            case {'gainx2','gainy2'}
                val = [get(findobj(hFig,'tag','gainx2'),'value') get(findobj(hFig,'tag','gainy2'),'value')];
                val = round(val*100)/100;
                if all(0~=val) && all(gain_range(1)<=val) && all(val<=gain_range(2)), tform.gain = val; end
                update_calib_func();
                
            case 'rotation1'
                val = round(str2double(get(gcbo,'string'))*100)/100;
                if -180<=val && val<=180, tform.rotation = val; end
                update_calib_func();
                
            case 'rotation2'
                val = round(get(gcbo,'value')*100)/100;
                if -180<=val && val<=180, tform.rotation = val; end
                update_calib_func();
                
            case 'showorigin'
                picked_target = round(size(fixpoint_pos,1) / 2);
                show_fixationpoint = true;
                
            case 'setorigin'
                setorigin();
                
            case 'fiximage'
                mglsetcontrolscreenshow(false);
                pause(0.3); drawnow;
                [cursorfile,cursorpath] = uigetfile({'*.jpg;*.bmp;*.png;*.gif;*.avi;*.mpg','Image/Movie Files'; '*.*','All Files'}, 'Choose fixation point file');
                pause(0.3); drawnow;
                if (isscalar(cursorfile) && 0==cursorfile) || ~exist([cursorpath cursorfile],'file')
                    tform.fiximage = '';
                else
                    tform.fiximage = [cursorpath cursorfile];
                end
                mglsetcontrolscreenshow(true);
                update_fixpoint();
                
            case 'fixshape'
                tform.fixshape = get(gcbo,'value');
                update_fixpoint();
                
            case 'fixcolor'
                mglsetcontrolscreenshow(false);
                pause(0.3); drawnow;
                tform.fixcolor = uisetcolor(tform.fixcolor,'Pick up a color');
                pause(0.3); drawnow;
                mglsetcontrolscreenshow(true);
                update_fixpoint();
                
            case 'fixsize'
                val = str2double(get(gcbo,'string'));
                if 0<val, tform.fixsize = val; end
                update_fixpoint();
                
            case 'fixinterval'
                val = str2double(get(gcbo,'string'));
                if fixinterval_range(1)<=val && val<=fixinterval_range(2), tform.fixinterval = val; end
                update_fixpoint();
                
            case 'windowsize'
                val = round(str2double(get(gcbo,'string'))*100)/100;
                if 0<val, tform.windowsize = val; end
                
            case {'waittime','holdtime'}
                val = round(str2double(get(gcbo,'string')));
                if 0<val, tform.(obj_tag) = val; end
                
            case 'rewardoptions'
                mglsetcontrolscreenshow(false);
                w = 250 ; h = 235;
                xymouse = get(0, 'PointerLocation');
                x = xymouse(1) - w;
                y = xymouse(2);
                
                hDlg = figure;
                fontsize = 9;
                bgcolor = [0.9255 0.9137 0.8471];
                set(hDlg, 'position',[x y w h], 'menubar','none', 'numbertitle','off', 'name','Reward variables', 'color',bgcolor, 'windowstyle','modal');
                
                uicontrol('parent',hDlg, 'style','pushbutton', 'position',[w-160 10 70 25], 'string','Done', 'fontsize',fontsize, 'callback','uiresume(gcbf);');
                uicontrol('parent',hDlg, 'style','pushbutton', 'position',[w-80 10 70 25], 'string','Cancel', 'fontsize',fontsize, 'callback','close(gcbf);');
                uicontrol('parent',hDlg, 'style','text', 'position',[10 195 120 25], 'string','JuiceLine', 'backgroundcolor',bgcolor, 'fontsize',fontsize, 'fontweight','bold', 'horizontalalignment','left');
                uicontrol('parent',hDlg, 'style','text', 'position',[10 165 120 25], 'string','Duration (ms)', 'backgroundcolor',bgcolor, 'fontsize',fontsize, 'fontweight','bold', 'horizontalalignment','left');
                uicontrol('parent',hDlg, 'style','text', 'position',[10 135 120 25], 'string','Number of Pulses', 'backgroundcolor',bgcolor, 'fontsize',fontsize, 'fontweight','bold', 'horizontalalignment','left');
                uicontrol('parent',hDlg, 'style','text', 'position',[10 105 140 25], 'string','Time b/w Pulses (ms)', 'backgroundcolor',bgcolor, 'fontsize',fontsize, 'fontweight','bold', 'horizontalalignment','left');
                uicontrol('parent',hDlg, 'style','text', 'position',[10 75 120 25], 'string','Trigger Voltage', 'backgroundcolor',bgcolor, 'fontsize',fontsize, 'fontweight','bold', 'horizontalalignment','left');
                uicontrol('parent',hDlg, 'style','text', 'position',[10 45 120 25], 'string','Custom Variables', 'backgroundcolor',bgcolor, 'fontsize',fontsize, 'fontweight','bold', 'horizontalalignment','left');
                uicontrol('parent',hDlg, 'style','edit', 'position',[140 198 100 25], 'tag','RewardJuiceLine', 'string',num2str(tform.RewardFuncArgs.JuiceLine), 'fontsize',fontsize);
                uicontrol('parent',hDlg, 'style','edit', 'position',[140 168 100 25], 'tag','RewardDuration', 'string',num2str(tform.RewardFuncArgs.Duration), 'fontsize',fontsize);
                uicontrol('parent',hDlg, 'style','edit', 'position',[140 138 100 25], 'tag','RewardNumReward', 'string',num2str(tform.RewardFuncArgs.NumReward), 'fontsize',fontsize);
                uicontrol('parent',hDlg, 'style','edit', 'position',[140 108 100 25], 'tag','RewardPauseTime', 'string',num2str(tform.RewardFuncArgs.PauseTime), 'fontsize',fontsize);
                uicontrol('parent',hDlg, 'style','edit', 'position',[140 78 100 25], 'tag','RewardTriggerVal', 'string',num2str(tform.RewardFuncArgs.TriggerVal), 'fontsize',fontsize);
                uicontrol('parent',hDlg, 'style','edit', 'position',[120 48 120 25], 'tag','RewardCustom', 'string',tform.RewardFuncArgs.Custom, 'fontsize',fontsize);
                pause(0.3); drawnow; uiwait(hDlg); pause(0.3); drawnow;
                
                if ~ishandle(hDlg), mglsetcontrolscreenshow(true); return, end
                tform.RewardFuncArgs.JuiceLine = str2double(get(findobj(hDlg,'tag','RewardJuiceLine'),'string'));
                tform.RewardFuncArgs.Duration = str2double(get(findobj(hDlg,'tag','RewardDuration'),'string'));
                tform.RewardFuncArgs.NumReward = str2double(get(findobj(hDlg,'tag','RewardNumReward'),'string'));
                tform.RewardFuncArgs.PauseTime = str2double(get(findobj(hDlg,'tag','RewardPauseTime'),'string'));
                tform.RewardFuncArgs.TriggerVal = str2double(get(findobj(hDlg,'tag','RewardTriggerVal'),'string'));
                tform.RewardFuncArgs.Custom = get(findobj(hDlg,'tag','RewardCustom'),'string');
                close(hDlg);
                r = tform.RewardFuncArgs;
                DAQ.goodmonkey(r.Duration,'eval',sprintf('ML_WarmingUp=true;NumReward=%d;PauseTime=%d;TriggerVal=%d;%s',r.NumReward,r.PauseTime,r.TriggerVal,r.Custom));
                mglsetcontrolscreenshow(true);

            case 'savebutton', exit_code = 1; return;
            case 'cancelbutton', exit_code = -1; return;
        end
        update_UI();
    end

    function update_UI()
        set(findobj(hFig,'tag','operatorview1'), 'string',num2str(tform.operator_view));
        set(findobj(hFig,'tag','operatorview2'), 'value',tform.operator_view);
        set(findobj(hFig,'tag','originx1'), 'string',num2str(tform.origin(1)));
        set(findobj(hFig,'tag','originx2'), 'value',tform.origin(1));
        set(findobj(hFig,'tag','originy1'), 'string',num2str(tform.origin(2)))
        set(findobj(hFig,'tag','originy2'), 'value',tform.origin(2));
        set(findobj(hFig,'tag','gainx1'), 'string',num2str(tform.gain(1)));
        set(findobj(hFig,'tag','gainx2'), 'value',tform.gain(1));
        set(findobj(hFig,'tag','gainy1'), 'string',num2str(tform.gain(2)))
        set(findobj(hFig,'tag','gainy2'), 'value',tform.gain(2));
        set(findobj(hFig,'tag','rotation1'), 'string',num2str(tform.rotation));
        set(findobj(hFig,'tag','rotation2'), 'value',tform.rotation);
        if isempty(tform.fiximage)
            set(findobj(hFig,'tag','fiximage'), 'string','Select image/movie');
            enable = 'on';
        else
            [~,file,ext] = fileparts(tform.fiximage);
            set(findobj(hFig,'tag','fiximage'), 'string',[file ext]);
            enable = 'off';
        end
        set(findobj(hFig,'tag','fixshape'), 'enable',enable);
        set(findobj(hFig,'tag','fixcolor'), 'enable',enable);
        set(findobj(hFig,'tag','fixsize'),  'enable',enable);
        set(findobj(hFig,'tag','fixshape'), 'value',tform.fixshape);
        set(findobj(hFig,'tag','fixcolor'), 'backgroundcolor',tform.fixcolor, 'foregroundcolor',1-tform.fixcolor);
        set(findobj(hFig,'tag','fixsize'), 'string',num2str(tform.fixsize));
        set(findobj(hFig,'tag','fixinterval'), 'string',num2str(tform.fixinterval));
        set(findobj(hFig,'tag','windowsize'), 'string',num2str(tform.windowsize));
        set(findobj(hFig,'tag','waittime'), 'string',num2str(tform.waittime));
        set(findobj(hFig,'tag','holdtime'), 'string',num2str(tform.holdtime));
        set(findobj(hFig,'tag','rewardoptions'), 'string',fi(DAQ.reward_present,'Change Reward Options','Reward I/O Not Assigned!'), 'enable',fi(DAQ.reward_present,'on','off'));
    end

    function setorigin()
        peekdata(DAQ,min(100,MinSamplesAcquired(DAQ)));
        if 1==EyeOrJoy, data = mean(DAQ.Eye,1); else data = mean(DAQ.Joystick,1); end
        tform.origin = max(origin_range(1),min(origin_range(2),round(data*100)/100));
        update_calib_func();
    end

    function closeDlg(~,~)
        set(hFig, 'windowstyle','normal');
        if 1~=exit_code
            button = 'No';
            if isempty(old_tform) || any(tform.origin~=old_tform.origin) || any(tform.gain~=old_tform.gain) || tform.rotation~=old_tform.rotation
                mglsetcontrolscreenshow(false);
                options.Interpreter = 'tex';
                options.Default = 'Yes';
                qstring = ['\fontsize{10}Do you really want to discard the changes?' char(10) 'Click ''No'' to save them.'];
                button = questdlg(qstring,'Calibration has changed','Yes','No',options);
            end
            if strcmp(button,'Yes'), tform = old_tform; end
        end
        exit_code = -1;
        try
            stop(DAQ);
            if daqcreated, delete(DAQ); end
            if mouse_created, delete(mouse); end
            mgldestroygraphic(mlsetdiff(mglgetallobjects,mglobjectid));
            if mglscreenscreated(2)
                mgldestroycontrolscreen();
            else
                mglactivategraphic(mglobjectid,mglobjectstatus);
                mglsetcontrolscreenrect(mglcontrolscreeninfo.Rect);
                mglsetscreencolor(2,mglcontrolscreeninfo.Color);
                mglsetcontrolscreenzoom(mglcontrolscreeninfo.Zoom);
                mglsetcontrolscreenshow(mglcontrolscreeninfo.Show);
            end
            if mglscreenscreated(1), destroy(Screen); end
            mglclearscreen();
            mglpresent();
        catch
            % do nothing
        end
        closereq;
    end

    function on_move(~,~,~)
        pos = get(hFig,'position');
        pos(3) = pos(4);
        mglsetcontrolscreenrect(Pos2Rect(pos));
        update_controlscreen_geometry();
        drawnow;
    end

    function update_controlscreen_geometry()
        ControlScreenRect = CalFun.update_controlscreen_geometry();
    end

    function update_calib_func()
        tform.rotation_t = [cosd(tform.rotation) -sind(tform.rotation); sind(tform.rotation) cosd(tform.rotation)]';
        tform.rotation_rev_t = [cosd(-tform.rotation) -sind(-tform.rotation); sind(-tform.rotation) cosd(-tform.rotation)]';
        CalFun.set_transform_matrix(tform);
    end

    function update_fixpoint()
        if ~isempty(fixpoint_id), mgldestroygraphic(fixpoint_id); end
        
        deg = floor(Screen.SubjectScreenHalfSize / MLConfig.PixelsPerDegree(1) / tform.fixinterval) * tform.fixinterval;
        xdeg = -deg(1):tform.fixinterval:deg(1);
        ydeg = deg(2):-tform.fixinterval:-deg(2);
        xpos = xdeg * MLConfig.PixelsPerDegree(1) + Screen.SubjectScreenHalfSize(1);
        ypos = ydeg * MLConfig.PixelsPerDegree(2) + Screen.SubjectScreenHalfSize(2);
        nx = length(xpos);
        ny = length(ypos);
        nz = nx * ny;
        fixpoint_id = NaN(1,nz);
        fixpoint_pos = zeros(nz,2);
        
        idx = 0;
        imdata = load_cursor(tform.fiximage, tform.fixshape, tform.fixcolor, tform.fixsize*MLConfig.PixelsPerDegree(1));
        for m=1:ny
            for n=1:nx
                idx = idx + 1;
                fixpoint_id(idx) = mgladdbitmap(imdata, 2);
                fixpoint_pos(idx,:) = [xpos(n) ypos(m)];
                mglsetorigin(fixpoint_id(idx),fixpoint_pos(idx,:));
            end
        end
    end

    function idx = isinside(xy)
        halfsize = mglgetproperty(fixpoint_id(1),'size') / 2;
        idx = fixpoint_pos(:,1)-halfsize(1) <= xy(1) & xy(1) < fixpoint_pos(:,1)+halfsize(1) ...
            & fixpoint_pos(:,2)-halfsize(2) <= xy(2) & xy(2) < fixpoint_pos(:,2)+halfsize(2);
    end

    function dest = copyfield(dest,src,field)
        if isempty(src), src = struct; end
        if isempty(dest), dest = struct; end
        if ~exist('field','var'), field = intersect(fieldnames(dest),fieldnames(src)); end
        for m=1:length(field), dest.(field{m}) = src.(field{m}); end
    end

    function op = fi(tf,op1,op2)
        if tf, op = op1; else op = op2; end
    end
end
