function varargout = run_trial(MLConfig,datafile)
%
%   Jan 12, 2017    This file is renamed from 'monkeylogic.m' to 'run_trial.m'
%                   and completely re-written by Jaewon Hwang

varargout = cell(1);  % default output

MLPath = MLConfig.MLPath;
MLConditions = MLConfig.MLConditions;
DAQ = MLConfig.DAQ;
Screen = MLConfig.Screen;

TrialRecord = mltrialrecord(MLConfig);
if isempty(MLConfig.UserPlotFunction), TrialRecord.TaskInfo.UserPlotFunction = ''; else TrialRecord.TaskInfo.UserPlotFunction = fileread(MLConfig.UserPlotFunction); end

MLEditable = [];
if isempty(MLConfig.SubjectName), editable_by_subject = 'MLEditable'; else editable_by_subject = ['MLEditable_' lower(MLConfig.SubjectName)]; end

userplotfunc = get_function_handle(MLConfig.UserPlotFunction);
alertfunc = get_function_handle(MLPath.AlertFunction);
alert = ~isempty(alertfunc) && MLConfig.RemoteAlert;

if isempty(MLConfig.ControlScreenZoom), MLConfig.ControlScreenZoom = 90; end
ControlScreenZoomRange = [5 300];

hFig = [];
hReplica = [];
replica_pos = [];
hMessagebox = [];
hTimeline = [];
hUserplot = [];
performance_bar = [];
iti_timer = [];
InterTrialInterval = 0;
[~,condname] = fileparts(MLPath.ConditionsFile);
looping = true;

uiTotalCorrectTrials = 0;
uiPerformanceOverAll = zeros(10,1);
uiPerformanceThisBlock = zeros(10,1);
uiPerformanceThisCond = zeros(10,1);

exception1 = [];
exception2 = [];
try
    init();
    create_tracers(Screen,MLConfig);

    % need to embed timining files before calling pause_menu() to make [v] work
    if isuserloopfile(MLConditions)
        userloop_handle = get_function_handle(MLConditions.Conditions);
        [taskobject,timingfile,trialholder] = userloop_handle(MLConfig,TrialRecord);
        if ischar(timingfile), runtime = get_function_handle(embed_timingfile(MLConfig,timingfile,trialholder)); else runtime = timingfile; end
    else
        timingfile = MLConditions.UIVars.TimingFiles;
        ntimingfile = length(timingfile);
        runtime_handle = cell(ntimingfile,1);
        for m=1:ntimingfile, runtime_handle{m} = get_function_handle(embed_timingfile(MLConfig,timingfile{m})); end %#ok<*FXUP>
    end
    editable = whos('-file',MLPath.ConfigurationFile,editable_by_subject);
    if ~isempty(editable), editable = load(MLPath.ConfigurationFile,editable_by_subject); MLEditable = editable.(editable_by_subject); end
    TrialRecord.set_editable(MLEditable);

    if TrialRecord.Pause, pause_menu(); varargout{1} = MLConfig; end
    if TrialRecord.Quit || ~looping, if ishandle(hFig), close(hFig); end, return, end

    if TrialRecord.TestTrial
        TaskObject = mltaskobject(taskobject,MLConfig);
        TrialData = mltrialdata;
        TrialData.VariableChanges = copyfield(TrialData.VariableChanges,MLEditable,setdiff(fieldnames(MLEditable),'editable'));
        varargout{1} = runtime(MLConfig,TrialRecord,TaskObject,TrialData);
        close(hFig);
        return
    end
    
    TrialRecord.DataFile = datafile;
    MLConfig.export_to_file(datafile);
    if alert, alertfunc('task_start',MLConfig,TrialRecord); end
    TrialRecord.TaskInfo.StartTime = now;

    for trial=1:MLConfig.TotalNumberOfTrialsToRun
        if ~TrialRecord.SimulationMode && MLConfig.Touchscreen && 1<mglgetadaptercount, mglsetcursorpos(1); else mglsetcursorpos(-1); end
        
        if isuserloopfile(MLConditions)
            [taskobject,timingfile,trialholder] = userloop_handle(MLConfig,TrialRecord);  % keep in mind that the userloop function is called before the trial number counts up 
            BlockChange = TrialRecord.BlockChange;
            TrialRecord.new_trial();
            if ischar(timingfile), runtime = get_function_handle(embed_timingfile(MLConfig,timingfile,trialholder)); else runtime = timingfile; end
        elseif isconditionsfile(MLConditions)
            BlockChange = TrialRecord.BlockChange;
            TrialRecord.new_trial();
            taskobject = MLConditions.Conditions(TrialRecord.CurrentCondition).TaskObject;
            runtime = runtime_handle{MLConditions.UIVars.TimingFilesNo(TrialRecord.CurrentCondition)};
        end
        TaskObject = mltaskobject(taskobject,MLConfig,TrialRecord);

        TrialData = mltrialdata;
        TrialData.Trial = TrialRecord.CurrentTrialNumber;
        TrialData.Block = TrialRecord.CurrentBlock;
        TrialData.TrialWithinBlock = TrialRecord.CurrentTrialWithinBlock;
        TrialData.Condition = TrialRecord.CurrentCondition;
        TrialData.VariableChanges = copyfield(TrialData.VariableChanges,MLEditable,setdiff(fieldnames(MLEditable),'editable'));
        if isfield(TaskObject.Info,'Attribute'), TrialData.TaskObject = struct('Attribute',{TaskObject.Info.Attribute},'Size',TaskObject.Size); else TrialData.TaskObject = struct('Attribute',TaskObject.Info,'Size',TaskObject.Size); end

        if alert
            if BlockChange, alertfunc('block_start',MLConfig,TrialRecord); end
            alertfunc('trial_start',MLConfig,TrialRecord);
        end
        pretrial_uiupdate();

        runtime(MLConfig,TrialRecord,TaskObject,TrialData);

        if TrialRecord.Pause, iti_timer = []; else iti_timer = tic; end
        TrialData.export_to_file(datafile);
        TrialRecord.update_trial_result(TrialData);
 
        MLEditable = copyfield(MLEditable,TrialData.VariableChanges);
        InterTrialInterval = TrialData.InterTrialInterval;
        for m=1:length(TrialData.UserMessage), mlmessage(TrialData.UserMessage{m}{:}); end
        MLConfig.EyeTransform{MLConfig.EyeCalibration} = TrialData.NewEyeTransform;

        posttrial_uiupdate();
        if alert
            alertfunc('trial_end',MLConfig,TrialRecord);
            if TrialRecord.BlockChange, alertfunc('block_end',MLConfig,TrialRecord); end
        end

        if TrialRecord.Pause, pause_menu(); varargout{1} = MLConfig; end
        if TrialRecord.Quit || ~looping, break, end
    end
catch err
    exception1 = err;
end

try
    TrialRecord.export_to_file(datafile);
    if alert
        if ~isempty(exception1)
            alertfunc('task_aborted',MLConfig,TrialRecord);
        else
            alertfunc('task_end',MLConfig,TrialRecord);
        end
    end
catch err
    exception2 = err;
end

if ishandle(hFig), close(hFig); end
if ~isempty(exception1), rethrow(exception1); end
if ~isempty(exception2), rethrow(exception2); end


    function pretrial_uiupdate()
        set(hFig,'name',sprintf('[%s: %s]  Start: %s  (Elapsed: %s)',condname,MLConfig.SubjectName,datestr(TrialRecord.TaskInfo.StartTime,'yyyy-mm-dd HH:MM:SS'), ...
            datestr(now-TrialRecord.TaskInfo.StartTime,'HH:MM:SS')));

        set(findobj(hFig,'tag','TrialNo'),'string',num2str(TrialRecord.CurrentTrialNumber));
        set(findobj(hFig,'tag','BlockNo'),'string',num2str(TrialRecord.CurrentBlock));
        set(findobj(hFig,'tag','CondNo'),'string',num2str(TrialRecord.CurrentCondition));
        set(findobj(hFig,'tag','TrialsInThisBlock'),'string',num2str(TrialRecord.CurrentTrialWithinBlock));
        set(findobj(hFig,'tag','BlocksCompleted'),'string',num2str(TrialRecord.CurrentBlockCount-1));

        if 32<length(TrialRecord.TrialErrors), TrialErrorsInAllConds = sprintf('%d',TrialRecord.TrialErrors(end-31:end)); else TrialErrorsInAllConds = sprintf('%d',TrialRecord.TrialErrors); end
        set(findobj(hFig,'tag','TrialErrorsInAllConds1'),'string',TrialErrorsInAllConds);
        set(findobj(hFig,'tag','TrialErrorsInAllConds2'),'string','');
        
        count = TrialRecord.TrialErrors(TrialRecord.ConditionsPlayed==TrialRecord.CurrentCondition);
        if 32<length(count), TrialErrorsInThisCond = sprintf('%d',count(end-31:end)); else TrialErrorsInThisCond = sprintf('%d',count); end
        set(findobj(hFig,'tag','TrialErrorsInThisCond1'),'string',TrialErrorsInThisCond);
        set(findobj(hFig,'tag','TrialErrorsInThisCond2'),'string','');
      
        if size(uiPerformanceThisBlock,2)<TrialRecord.CurrentBlock, uiPerformanceThisBlock(end,TrialRecord.CurrentBlock) = 0; end
        if size(uiPerformanceThisCond,2)<TrialRecord.CurrentCondition, uiPerformanceThisCond(end,TrialRecord.CurrentCondition) = 0; end
        f = uiPerformanceOverAll; s = sum(f);
        set(findobj(hFig,'tag','PerformanceOverAll2'),'string',sprintf(fi(1==f(1)/s,'%.0f%%','%.1f%%'),fi(0==s,0,f(1)*100/s)));
        performance_bar_update('PerformanceOverAll',f);
        f = uiPerformanceThisBlock(:,TrialRecord.CurrentBlock); s = sum(f);
        set(findobj(hFig,'tag','PerformanceThisBlock2'),'string',sprintf(fi(1==f(1)/s,'%.0f%%','%.1f%%'),fi(0==s,0,f(1)*100/s)));
        performance_bar_update('PerformanceThisBlock',f);
        f = uiPerformanceThisCond(:,TrialRecord.CurrentCondition); s = sum(f);
        set(findobj(hFig,'tag','PerformanceThisCond2'),'string',sprintf(fi(1==f(1)/s,'%.0f%%','%.1f%%'),fi(0==s,0,f(1)*100/s)));
        performance_bar_update('PerformanceThisCond',f);

        if ~isempty(iti_timer)
            if toc(iti_timer)*1000 < InterTrialInterval
                while toc(iti_timer)*1000 < InterTrialInterval, end
            else
                mlmessage('Trial %d: Desired ITI exceeded (ITI ~= %d ms)',TrialData.Trial-1,round(toc(iti_timer)*1000),'w');
            end
        end
        drawnow;
    end
    function posttrial_uiupdate()
        TrialRecord.TaskInfo.EndTime = now;
        set(hFig,'name',sprintf('[%s: %s]  Start: %s  (Elapsed: %s)',condname,MLConfig.SubjectName,datestr(TrialRecord.TaskInfo.StartTime,'yyyy-mm-dd HH:MM:SS'), ...
            datestr(TrialRecord.TaskInfo.EndTime-TrialRecord.TaskInfo.StartTime,'HH:MM:SS')));

        if TrialRecord.BlockChange, set(findobj(hFig,'tag','BlocksCompleted'),'string',num2str(TrialRecord.CurrentBlockCount)); end
        if 0==TrialData.TrialError, uiTotalCorrectTrials = uiTotalCorrectTrials + 1; end
        set(findobj(hFig,'tag','TotalCorrectTrials'),'string',num2str(uiTotalCorrectTrials));
        switch TrialData.Ver
            case 1
                set(findobj(hFig,'tag','MaxLatency'),'string',sprintf('%.1f ms',TrialData.CycleRate(1)));
                set(findobj(hFig,'tag','CycleRate'),'string',sprintf('%d Hz',TrialData.CycleRate(2)));
            otherwise  % 2, 2.1
                set(findobj(hFig,'tag','MaxLatency'),'string',sprintf('%.2f ms',TrialData.CycleRate(1)));
                set(findobj(hFig,'tag','CycleRate'),'string',sprintf('%.2f ms',TrialData.CycleRate(2)));
        end
        set(findobj(hFig,'tag','TrialErrorsInAllConds2'),'string',num2str(TrialData.TrialError));
        set(findobj(hFig,'tag','TrialErrorsInThisCond2'),'string',num2str(TrialData.TrialError));
        
        % update performance bar
        row = TrialData.TrialError + 1;
        uiPerformanceOverAll(row) = uiPerformanceOverAll(row) + 1;
        uiPerformanceThisBlock(row,TrialData.Block) = uiPerformanceThisBlock(row,TrialData.Block) + 1;
        uiPerformanceThisCond(row,TrialData.Condition) = uiPerformanceThisCond(row,TrialData.Condition) + 1;
        f = uiPerformanceOverAll; s = sum(f);
        set(findobj(hFig,'tag','PerformanceOverAll2'),'string',sprintf(fi(1==f(1)/s,'%.0f%%','%.1f%%'),fi(0==s,0,f(1)*100/s)));
        performance_bar_update('PerformanceOverAll',f);
        f = uiPerformanceThisBlock(:,TrialData.Block); s = sum(f);
        set(findobj(hFig,'tag','PerformanceThisBlock2'),'string',sprintf(fi(1==f(1)/s,'%.0f%%','%.1f%%'),fi(0==s,0,f(1)*100/s)));
        performance_bar_update('PerformanceThisBlock',f);
        f = uiPerformanceThisCond(:,TrialData.Condition); s = sum(f);
        set(findobj(hFig,'tag','PerformanceThisCond2'),'string',sprintf(fi(1==f(1)/s,'%.0f%%','%.1f%%'),fi(0==s,0,f(1)*100/s)));
        performance_bar_update('PerformanceThisCond',f);

        % update timeline
        set(hFig,'CurrentAxes',hTimeline);
        delete(findobj(hTimeline,'tag','eventobj'));
        fontsize = 9;
        h = text(0.5,0.94,sprintf('Trial #%d, Cond #%d',TrialData.Trial,TrialData.Condition),'horizontalalignment','center');
        set(h,'tag','eventobj','color',[1 1 1],'fontsize',fontsize,'fontweight','bold');
        code = TrialData.BehavioralCodes.CodeNumbers;
        if MLConfig.NonStopRecording
            time = TrialData.BehavioralCodes.CodeTimes - TrialData.BehavioralCodes.CodeTimes(1);
        else
            time = TrialData.BehavioralCodes.CodeTimes;
        end
        ncode = length(code);
        maxtime = max(time);
        if 0<ncode && 0<maxtime
            tick = 0:1000:maxtime;
            y = 0.9 - 0.85 * tick / maxtime;
            x1 = 0.25 * ones(size(y));
            x2 = 0.28 * ones(size(y));
            h = line([x1; x2],[y; y]);
            set(h,'tag','eventobj','color',[1 0 0],'linewidth',2);

            y = 0.9 - 0.85 * time' / maxtime;
            x1 = 0.24 * ones(size(y));
            x2 = 0.29 * ones(size(y));
            h = line([x1; x2],[y; y]);
            set(h,'tag','eventobj','color',[1 1 1],'linewidth',1);
            
            BehavioralCodes = TrialRecord.TaskInfo.BehavioralCodes;
            if ~isempty(BehavioralCodes)
                [a,b] = ismember(code,BehavioralCodes.CodeNumbers);
                b(~a) = length(BehavioralCodes.CodeNames)+1;
                codenames = [BehavioralCodes.CodeNames; {''}];
                h = text(x2+0.03,y,codenames(b));
                set(h,'tag','eventobj','color',[1 1 1],'fontsize',fontsize,'fontweight','bold');
            end
            h = text(x1-0.03,y,num2str(round(time)));
            set(h,'tag','eventobj','color',[1 1 1],'fontsize',fontsize,'fontweight','bold','horizontalalignment','right');
        end

        % update userplot
        set(hFig,'CurrentAxes',hUserplot);
        if isempty(userplotfunc)
            hist(TrialRecord.ReactionTimes);
            xlabel('Time (msec)');
            ylabel('Number of trials');
            title('Reaction Times');
        else
            userplotfunc(TrialRecord);
        end
        
        drawnow;
    end
    function performance_bar_update(tag,rate)
        s = sum(rate); if 0==s, s=1; end
        h = findobj(hFig,'tag',tag);
        set(h,'units','pixel');
        sz = get(h,'position');
        if isscalar(rate), for m=1:10, set(performance_bar.(tag)(1,m),'visible','off'); end, return, end
        w = rate(:) / s * sz(3);
        left = [0; cumsum(w)];
        for m=1:10
            if 0<w(m)
                set(performance_bar.(tag)(1,m),'visible','on','position',[sz(1)+left(m) sz(2) w(m) sz(4)]);
            else
                set(performance_bar.(tag)(1,m),'visible','off');
            end
            if 11<w(m)
                set(performance_bar.(tag)(2,m),'visible','on','position',[sz(1)+left(m)+w(m)/2-5 sz(2)+1 10 16]);
            else
                set(performance_bar.(tag)(2,m),'visible','off');
            end
        end
    end

    function pause_menu()
        if 0~=TrialRecord.CurrentTrialNumber
            set(hFig,'name',sprintf('[%s: %s]  Start: %s  End: %s  (Elapsed: %s)',condname,MLConfig.SubjectName,datestr(TrialRecord.TaskInfo.StartTime,'yyyy-mm-dd HH:MM:SS'), ...
                datestr(TrialRecord.TaskInfo.EndTime,'yyyy-mm-dd HH:MM:SS'),datestr(TrialRecord.TaskInfo.EndTime-TrialRecord.TaskInfo.StartTime,'HH:MM:SS')));
            if alert, alertfunc('task_paused',MLConfig,TrialRecord); end
        end
        
        mglkeepsystemawake(false);
        mglsetcursorpos(-1);
        mglactivategraphic(mglgetallobjects,false);
        id = mgladdbox([0 0 0; 0 0 0],Screen.SubjectScreenFullSize,2);

        TrialRecord.Pause = false;
        hzoom = [findobj(hFig,'tag','operatorview1') findobj(hFig,'tag','operatorview2')];
        set(hzoom,'enable','on');
        
        ControlScreenRect = mglgetcontrolscreenrect;
        ControlScreenHalfSize = (ControlScreenRect(3:4) - ControlScreenRect(1:2)) / 2;
        
        fontsize = 20;
        fontface = 'Segoe UI';
        x = -150; y = -160;
        id(end+1) = mgladdtext('Paused',12);
        mglsetproperty(id(end),'font',fontface,fontsize,'bold','halign',2,'valign',2,'origin',ControlScreenHalfSize + [0 y] * Screen.DPI_ratio);

        fontsize = 16;
        y = y + 60;
        id(end+1) = mgladdtext(sprintf('Conditions: %s',condname),12);
        mglsetproperty(id(end),'font',fontface,fontsize,'bold','halign',1,'valign',2,'color',[0 1 0],'origin',ControlScreenHalfSize + [x y] * Screen.DPI_ratio);

        y = y + 30;
        id(end+1) = mgladdtext(sprintf('Subject: %s',MLConfig.SubjectName),12);
        mglsetproperty(id(end),'font',fontface,fontsize,'bold','halign',1,'valign',2,'color',[0 1 0],'origin',ControlScreenHalfSize + [x y] * Screen.DPI_ratio);

        y = y + 60;
        id(end+1) = mgladdtext(['[Space]: ' fi(0==TrialRecord.CurrentTrialNumber,'Start','Resume')],12);
        mglsetproperty(id(end),'font',fontface,fontsize,'bold','halign',1,'valign',2,'origin',ControlScreenHalfSize + [x y] * Screen.DPI_ratio);
        id(end+1) = mgladdtext('[Q]: Quit',12);
        mglsetproperty(id(end),'font',fontface,fontsize,'bold','halign',1,'valign',2,'origin',ControlScreenHalfSize + [x+200 y] * Screen.DPI_ratio);
        keycode = [57 16];
            
        y = y + 30;
        id(end+1) = mgladdtext('[B]: Select a new block',12);
        mglsetproperty(id(end),'font',fontface,fontsize,'bold','halign',1,'valign',2,'origin',ControlScreenHalfSize + [x y] * Screen.DPI_ratio);
        keycode(end+1) = 48;
        
        if MLConditions.isconditionsfile()
            y = y + 30;
            id(end+1) = mgladdtext('[X]: Alter behavioral-error handling',12);
            mglsetproperty(id(end),'font',fontface,fontsize,'bold','halign',1,'valign',2,'origin',ControlScreenHalfSize + [x y] * Screen.DPI_ratio);
            keycode(end+1) = 45;
        end

        if DAQ.eye_present() && 1<MLConfig.EyeCalibration
            y = y + 30;
            id(end+1) = mgladdtext('[E]: Recalibrate eye signals',12);
            mglsetproperty(id(end),'font',fontface,fontsize,'bold','halign',1,'valign',2,'origin',ControlScreenHalfSize + [x y] * Screen.DPI_ratio);
            keycode(end+1) = 18;
        end
        
        if DAQ.joystick_present() && 1<MLConfig.JoystickCalibration
            y = y + 30;
            id(end+1) = mgladdtext('[J]: Recalibrate joystick signals',12);
            mglsetproperty(id(end),'font',fontface,fontsize,'bold','halign',1,'valign',2,'origin',ControlScreenHalfSize + [x y] * Screen.DPI_ratio);
            keycode(end+1) = 36;
        end
        
        if ~isempty(MLEditable)
            y = y + 30;
            id(end+1) = mgladdtext('[V]: Edit timing file variables',12);
            mglsetproperty(id(end),'font',fontface,fontsize,'bold','halign',1,'valign',2,'origin',ControlScreenHalfSize + [x y] * Screen.DPI_ratio);
            keycode(end+1) = 47;
        end

        y = y + 30;
        id(end+1) = mgladdtext(['[S]: Simulation mode is ' fi(TrialRecord.SimulationMode,'ON','OFF')],12);
        mglsetproperty(id(end),'font',fontface,fontsize,'bold','halign',1,'valign',2,'origin',ControlScreenHalfSize + [x y] * Screen.DPI_ratio);
        keycode(end+1) = 31;

        menuitem = id(5:end);
        nmenuitem = length(menuitem);
        menuitem_pos = zeros(nmenuitem,4);
        for m=1:nmenuitem
            menuitem_pos(m,:) = mglgetproperty(menuitem(m),'rect');
        end
        
        if DAQ.mouse_present, ML_Mouse = DAQ.get_device('mouse'); else, ML_Mouse = pointingdevice; end
        click_down = false;
        selected = [];
        kbdinit;

        while looping
            k = []; [xy,buttons] = getsample(ML_Mouse);
            if any(buttons)
                click_down = true; 
            else
                if click_down, k = keycode(selected); else k = kbdgetkey; end
                click_down = false;
            end
            if ~click_down
                cs = mglgetcontrolscreenrect;
                xy = xy - cs(1:2);
                selected = find(menuitem_pos(:,1)<xy(1) & xy(1)<menuitem_pos(:,3) & menuitem_pos(:,2)<xy(2) & xy(2)<menuitem_pos(:,4),1);
                mglsetproperty(menuitem(1:end-1),'color',[1 1 1]);
                mglsetproperty(menuitem(end),'color',fi(TrialRecord.SimulationMode,[1 0 0],[1 1 1]));
                if ~isempty(selected), mglsetproperty(menuitem(selected),'color',[1 1 0]); end
            end
            
            if ~isempty(k)
                drawnow;
                switch k
                    case 57  % space
                        if 0~=TrialRecord.CurrentTrialNumber && alert, alertfunc('task_resumed',MLConfig,TrialRecord); end
                        break;
                    case 16, TrialRecord.Quit = true; break;  % q
                    case 48  % b
                        mglsetcontrolscreenshow(false);
                        pos = get(hFig,'position');
                        w = 155 ; h = 180;
                        xy = pos(1:2) + pos(3:4)/2 - [w h]/2;

                        hDlg = figure;
                        fontsize = 9;
                        bgcolor = [0.9255 0.9137 0.8471];
                        set(hDlg,'position',[xy w h],'menubar','none','numbertitle','off','name','Editable variables','color',bgcolor,'windowstyle','modal');

                        uicontrol('parent',hDlg,'style','pushbutton','position',[w-140 10 60 25],'string','Done','fontsize',fontsize,'callback','uiresume(gcbf);');
                        uicontrol('parent',hDlg,'style','pushbutton','position',[w-70 10 60 25],'string','Cancel','fontsize',fontsize,'callback','close(gcbf);');
                        uicontrol('parent',hDlg,'style','text','position',[0 149 155 22],'string','Next Block to Run','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold');
                        hlist = uicontrol('parent',hDlg,'style','listbox','position',[50 45 60 106],'min',1,'max',1,'string',num2cell(TrialRecord.BlocksToRun),'fontsize',fontsize);
                        pause(0.3); drawnow; uiwait(hDlg); pause(0.3); drawnow;

                        if ishandle(hDlg)
                            TrialRecord.next_block(TrialRecord.BlocksToRun(get(hlist,'value')));
                            close(hDlg);
                        end
                        mglsetcontrolscreenshow(true);
                    case 45  % x
                        if ~MLConditions.isconditionsfile(), continue, end
                        mglsetcontrolscreenshow(false);
                        pos = get(hFig,'position');
                        w = 155 ; h = 180;
                        xy = pos(1:2) + pos(3:4)/2 - [w h]/2;
                        error_logic = {'ignore','repeat immediately','repeat delayed'};

                        hDlg = figure;
                        fontsize = 9;
                        bgcolor = [0.9255 0.9137 0.8471];
                        set(hDlg,'position',[xy w h],'menubar','none','numbertitle','off','name','Error Logic','color',bgcolor,'windowstyle','modal');

                        uicontrol('parent',hDlg,'style','pushbutton','position',[w-140 10 60 25],'string','Done','fontsize',fontsize,'callback','uiresume(gcbf);');
                        uicontrol('parent',hDlg,'style','pushbutton','position',[w-70 10 60 25],'string','Cancel','fontsize',fontsize,'callback','close(gcbf);');
                        uicontrol('parent',hDlg,'style','text','position',[0 149 155 22],'string','Error Handling','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold');
                        hlist = uicontrol('parent',hDlg,'style','listbox','position',[10 45 135 106],'min',1,'max',1,'string',error_logic,'fontsize',fontsize);
                        pause(0.3); drawnow; uiwait(hDlg); pause(0.3); drawnow;

                        if ishandle(hDlg)
                            TrialRecord.set_errorlogic(get(hlist,'value'));
                            close(hDlg);
                        end
                        mglsetcontrolscreenshow(true);
                    case 18  % e
                        if ~DAQ.eye_present() || 1==MLConfig.EyeCalibration, continue, end
                        switch MLConfig.EyeCalibration
                            case 2, MLConfig.EyeTransform{MLConfig.EyeCalibration} = mlcalibrate_origin_gain(1,MLConfig);
                            case 3, MLConfig.EyeTransform{MLConfig.EyeCalibration} = mlcalibrate_spatial_transform(1,MLConfig);
                        end
                    case 36  % j
                        if ~DAQ.joystick_present() || 1==MLConfig.JoystickCalibration, continue, end
                        switch MLConfig.JoystickCalibration
                            case 2, MLConfig.JoystickTransform{MLConfig.JoystickCalibration} = mlcalibrate_origin_gain(2,MLConfig);
                            case 3, MLConfig.JoystickTransform{MLConfig.JoystickCalibration} = mlcalibrate_spatial_transform(2,MLConfig);
                        end
                    case 47  % v
                        if isempty(MLEditable), continue, end
                        mglsetcontrolscreenshow(false);
                        field = fieldnames(MLEditable);
                        field = field(~strcmp(field,'editable'));
                        nfield = length(field);
                        w = 453; h = 70 + 25 * nfield;
                        pos = get(hFig,'position');
                        xy = pos(1:2) + pos(3:4)/2 - [w h]/2;

                        hDlg = figure;
                        fontsize = 9;
                        bgcolor = [0.9255 0.9137 0.8471];
                        set(hDlg,'position',[xy w h],'menubar','none','numbertitle','off','name','Editable variables','color',bgcolor,'windowstyle','modal');

                        uicontrol('parent',hDlg,'style','pushbutton','position',[w-140 10 60 25],'string','Save','fontsize',fontsize,'callback','uiresume(gcbf);');
                        uicontrol('parent',hDlg,'style','pushbutton','position',[w-70 10 60 25],'string','Cancel','fontsize',fontsize,'callback','close(gcbf);');
                        uicontrol('parent',hDlg,'style','text','position',[5 h-25 195 22],'string','Variables','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold');
                        uicontrol('parent',hDlg,'style','text','position',[205 h-25 245 22],'string','Values','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold');
                        for m=1:nfield
                            uicontrol('parent',hDlg,'style','text','position',[5 h-25-25*m 195 22],'string',[field{m} ' :'],'backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','right');
                            switch MLEditable.editable.(field{m})
                                case 'file'
                                    uicontrol('parent',hDlg,'style','edit','position',[205 h-22-25*m 215 22],'tag',field{m},'string',MLEditable.(field{m}),'fontsize',fontsize,'fontweight','bold');
                                    uicontrol('parent',hDlg,'style','pushbutton','position',[425 h-22-25*m 25 22],'string','...','fontsize',fontsize,'fontweight','bold','callback',sprintf('f = uigetfile; if 0~=f, set(findobj(''tag'',''%s''),''string'',f); end, drawnow;',field{m}));
                                case 'dir'
                                    uicontrol('parent',hDlg,'style','edit','position',[205 h-22-25*m 215 22],'tag',field{m},'string',MLEditable.(field{m}),'fontsize',fontsize,'fontweight','bold');
                                    uicontrol('parent',hDlg,'style','pushbutton','position',[425 h-22-25*m 25 22],'string','...','fontsize',fontsize,'fontweight','bold','callback',sprintf('p = uigetdir; if 0~=p, set(findobj(''tag'',''%s''),''string'',p); end, drawnow;',field{m}));
                                case 'color'
                                    uicontrol('parent',hDlg,'style','text','position',[205 h-24-25*m 175 22],'tag',[field{m} '_edit'],'string',sprintf('[%.3f %.3f %.3f]',MLEditable.(field{m})),'backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold');
                                    uicontrol('parent',hDlg,'style','pushbutton','position',[385 h-21-25*m 65 22],'tag',field{m},'string','Color','backgroundcolor',MLEditable.(field{m}),'foregroundcolor',1-MLEditable.(field{m}),'fontsize',fontsize,'callback',sprintf('c = uisetcolor; if ~isscalar(c), set(findobj(''tag'',''%s_edit''),''string'',sprintf(''[%%.3f %%.3f %%.3f]'',c)); set(findobj(''tag'',''%s''),''backgroundcolor'',c,''foregroundcolor'',1-c); end, drawnow;',field{m},field{m}));
                                otherwise
                                    uicontrol('parent',hDlg,'style','edit','position',[205 h-22-25*m 245 22],'tag',field{m},'string',MLEditable.(field{m}),'fontsize',fontsize,'fontweight','bold');
                            end
                        end
                        pause(0.3); drawnow; uiwait(hDlg); pause(0.3); drawnow;

                        if ishandle(hDlg)
                            for m=1:nfield
                                switch MLEditable.editable.(field{m})
                                    case 'color', MLEditable.(field{m}) = get(findobj(hDlg,'tag',field{m}),'backgroundcolor');
                                    otherwise, if isnumeric(MLEditable.(field{m})), MLEditable.(field{m}) = str2double(get(findobj(hDlg,'tag',field{m}),'string')); else MLEditable.(field{m}) = get(findobj(hDlg,'tag',field{m}),'string'); end
                                end
                            end
                            close(hDlg);
                        end
                        TrialRecord.set_editable(MLEditable);
                        mglsetcontrolscreenshow(true);
                    case 31  % s
                        TrialRecord.SimulationMode = ~TrialRecord.SimulationMode;
                        mglsetproperty(id(end),'text',['[S]: Simulation mode is ' fi(TrialRecord.SimulationMode,'ON','OFF')],'color',fi(TrialRecord.SimulationMode,[1 0 0],[1 1 1]));
                end
                kbdflush;
            end
            mglrendergraphic(2);
            mglpresent(2);
            pause(0.02);
        end
        MLEditable2.MLEditable = MLEditable;
        MLEditable2.(editable_by_subject) = MLEditable; %#ok<STRNU>
        if 2==exist(MLPath.ConfigurationFile,'file'), save(MLPath.ConfigurationFile,'-struct','MLEditable2','-append'); else save(MLPath.ConfigurationFile,'-struct','MLEditable2'); end

        if ishandle(hFig)
            mgldestroygraphic(id);
            set(hzoom,'enable','off');
            mglkeepsystemawake(true);
        end
    end

    function mlmessage(text,varargin)
        if isempty(text), return, end
        nvarargs = length(varargin);
        if 0==nvarargs
            type = 'i';
        else
            nformat = length(regexp(text,'%[0-9\.\-+ #]*[diuoxXfeEgGcs]'));
            text = sprintf(text,varargin{1:nformat});
            if nformat < nvarargs
                type = varargin{end};
            elseif nvarargs == nformat
                type = 'i';
            else
                error('Not enough input arguments');
            end
        end
        
        switch lower(type(1))
            case 'e',  icon = 'warning.gif'; color = 'red';
            case 'w',  icon = 'help_ex.png'; color = 'blue';
            otherwise, icon = 'help_gs.png'; color = 'black';
        end
        icon = fullfile(matlabroot,'toolbox/matlab/icons',icon);
        str = get(hMessagebox,'string');
        if 10<length(str), str = str(end-9:end); end
        str{end} =  sprintf('<html><img src="file:///%s" height="16" width="16">&nbsp;<font color="%s">%s</font></html>',icon,color,text);
        str{end+1} = '<html><font color="gray">>> End of the messages</font></html>';
        set(hMessagebox,'string',str,'value',length(str));
    end

    function init()
        fontsize = 9;
        fontsize2 = 10;
        figure_bgcolor = [.65 .70 .80];
        frame_bgcolor = [0.9255 0.9137 0.8471];
        callbackfunc = @UIcallback;

        pos = get(findobj('tag','mlmainmenu'),'position');
        screen_pos = GetMonitorPosition(Pos2Rect(pos));
        dx = fi(screen_pos(3) < 1009, 95, 0);
        dy = fi(screen_pos(4) < 864, 100, 0);
        
        fw = 993-dx;
        fh = 787-dy;
        fx = pos(1) + 0.5 * (pos(3) - fw);
        if fx < screen_pos(1), fx = screen_pos(1) + 8; end
        fy = min(pos(2) + 0.5 * (pos(4) - fh),sum(screen_pos([2 4])) - fh - 30);
        fig_pos = [fx fy fw fh];

        hFig = figure;
        set(hFig,'tag','mlmonitor','numbertitle','off','name',sprintf('MonkeyLogic (%s)',MLConfig.MLVersion),'menubar','none','position',fig_pos,'resize','off','color',figure_bgcolor,'windowstyle','modal');

        set(hFig,'closerequestfcn',@closeDlg);
        warning('off','MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame');
        jFrame = get(hFig,'JavaFrame');
        jAxis = jFrame.getAxisComponent;
        if verLessThan('matlab','8.4')
            hAxis = handle(jAxis,'CallbackProperties');
            set(hAxis,'AncestorMovedCallback',@on_move);
        else
            set(jAxis.getComponent(0),'AncestorMovedCallback',@on_move);
        end

        hReplica = subplot('position',[0.2 0 0.1 0.1]);
        x = 5; y = fh - 603+dy;
        replica_pos = [x y 800-dx 600-dy];
        set(hReplica,'tag','replica','units','pixel','position',replica_pos,'xtick',[],'ytick',[],'box','on','color',[0 0 0]);

        x = 5; y = 45;
        uicontrol('parent',hFig,'style','frame','position',[x y 186 134],'backgroundcolor',frame_bgcolor);
        x = 10; y = 179 - 25; bgcolor = frame_bgcolor;
        uicontrol('parent',hFig,'style','text','units','pixel','position',[x y 52 20],'string','Trial','backgroundcolor',bgcolor,'fontsize',fontsize2,'fontweight','bold');
        uicontrol('parent',hFig,'style','text','units','pixel','position',[x+62 y 52 20],'string','Block','backgroundcolor',bgcolor,'fontsize',fontsize2,'fontweight','bold');
        uicontrol('parent',hFig,'style','text','units','pixel','position',[x+124 y 52 20],'string','Cond','backgroundcolor',bgcolor,'fontsize',fontsize2,'fontweight','bold');
        y = y - 19; bgcolor = [0 0 0]; fgcolor = [1 1 1];
        uicontrol('parent',hFig,'style','edit','units','pixel','position',[x y+3 52 20],'tag','TrialNo','backgroundcolor',bgcolor,'foregroundcolor',fgcolor,'fontsize',fontsize2,'fontweight','bold');
        uicontrol('parent',hFig,'style','edit','units','pixel','position',[x+62 y+3 52 20],'tag','BlockNo','backgroundcolor',bgcolor,'foregroundcolor',fgcolor,'fontsize',fontsize2,'fontweight','bold');
        uicontrol('parent',hFig,'style','edit','units','pixel','position',[x+124 y+3 52 20],'tag','CondNo','backgroundcolor',bgcolor,'foregroundcolor',fgcolor,'fontsize',fontsize2,'fontweight','bold');
        y = y - 28; bgcolor = [0 0 0]; fgcolor = [1 1 1];
        uicontrol('parent',hFig,'style','edit','units','pixel','position',[x y+2 40 20],'tag','TrialsInThisBlock','backgroundcolor',bgcolor,'foregroundcolor',fgcolor,'fontsize',fontsize,'fontweight','bold');
        bgcolor = frame_bgcolor;
        uicontrol('parent',hFig,'style','text','units','pixel','position',[x+44 y 136 20],'string','Trial # within this block','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        y = y - 28; bgcolor = [0 0 0]; fgcolor = [1 1 1];
        uicontrol('parent',hFig,'style','edit','units','pixel','position',[x y+2 40 20],'tag','BlocksCompleted','backgroundcolor',bgcolor,'foregroundcolor',fgcolor,'fontsize',fontsize,'fontweight','bold');
        bgcolor = frame_bgcolor;
        uicontrol('parent',hFig,'style','text','units','pixel','position',[x+44 y 136 20],'string','# of blocks completed','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        y = y - 28; bgcolor = [0 0 0]; fgcolor = [1 1 1];
        uicontrol('parent',hFig,'style','edit','units','pixel','position',[x y+2 40 20],'tag','TotalCorrectTrials','backgroundcolor',bgcolor,'foregroundcolor',fgcolor,'fontsize',fontsize,'fontweight','bold');
        bgcolor = frame_bgcolor;
        uicontrol('parent',hFig,'style','text','units','pixel','position',[x+44 y 136 20],'string','Total # of correct trials','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');

        x = 5; y = 24; bgcolor = figure_bgcolor;
        uicontrol('parent',hFig,'style','text','units','pixel','position',[x y 90 18],'tag','MaxLatencyLabel','string','Max latency','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold');
        uicontrol('parent',hFig,'style','text','units','pixel','position',[x+96 y 90 18],'tag','CycleRateLabel','string','Cycle rate','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold');
        x = 5; y = 5; bgcolor = [0 0 0]; fgcolor = [1 1 1];
        uicontrol('parent',hFig,'style','edit','units','pixel','position',[x y 90 20],'tag','MaxLatency','backgroundcolor',bgcolor,'foregroundcolor',fgcolor,'fontsize',fontsize,'fontweight','bold');
        uicontrol('parent',hFig,'style','edit','units','pixel','position',[x+96 y 90 20],'tag','CycleRate','backgroundcolor',bgcolor,'foregroundcolor',fgcolor,'fontsize',fontsize,'fontweight','bold');
        
        x = 192; y = 179 - 19; bgcolor = figure_bgcolor;
        uicontrol('parent',hFig,'style','text','units','pixel','position',[x y 310 18],'string','Trial errors','backgroundcolor',bgcolor,'fontsize',fontsize2,'fontweight','bold');
        y = y - 23;
        uicontrol('parent',hFig,'style','text','units','pixel','position',[x y 62 20],'string','All cond','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','right');
        bgcolor = [0 0 0]; fgcolor = [1 1 1];
        uicontrol('parent',hFig,'style','edit','units','pixel','position',[x+64 y+3 231 20],'tag','TrialErrorsInAllConds1','backgroundcolor',bgcolor,'foregroundcolor',fgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','right');
        uicontrol('parent',hFig,'style','edit','units','pixel','position',[x+297 y+3 12 20],'tag','TrialErrorsInAllConds2','backgroundcolor',bgcolor,'foregroundcolor',fgcolor,'fontsize',fontsize,'fontweight','bold');
        y = y - 23; bgcolor = figure_bgcolor;
        uicontrol('parent',hFig,'style','text','units','pixel','position',[x y 62 20],'string','This cond','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','right');
        bgcolor = [0 0 0]; fgcolor = [1 1 1];
        uicontrol('parent',hFig,'style','edit','units','pixel','position',[x+64 y+3 231 20],'tag','TrialErrorsInThisCond1','backgroundcolor',bgcolor,'foregroundcolor',fgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','right');
        uicontrol('parent',hFig,'style','edit','units','pixel','position',[x+297 y+3 12 20],'tag','TrialErrorsInThisCond2','backgroundcolor',bgcolor,'foregroundcolor',fgcolor,'fontsize',fontsize,'fontweight','bold');

        x = 192; y = y - 19; bgcolor = figure_bgcolor;
        uicontrol('parent',hFig,'style','text','units','pixel','position',[x y 310 18],'string','Performance','backgroundcolor',bgcolor,'fontsize',fontsize2,'fontweight','bold');
        y = y - 23; bgcolor = figure_bgcolor;
        uicontrol('parent',hFig,'style','text','units','pixel','position',[x y 62 20],'string','Over all','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','right');
        uicontrol('parent',hFig,'style','text','units','pixel','position',[x+64 y+2 45 20],'tag','PerformanceOverAll2','backgroundcolor',bgcolor,'foregroundcolor',[1 1 1],'fontsize',10,'fontweight','bold');
        bgcolor = [0 0 0];
        uicontrol('parent',hFig,'style','edit','units','pixel','position',[x+109 y+3 200 20],'tag','PerformanceOverAll','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold');
        y = y - 23; bgcolor = figure_bgcolor;
        uicontrol('parent',hFig,'style','text','units','pixel','position',[x y 62 20],'string','This block','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','right');
        uicontrol('parent',hFig,'style','text','units','pixel','position',[x+64 y+2 45 20],'tag','PerformanceThisBlock2','backgroundcolor',bgcolor,'foregroundcolor',[1 1 1],'fontsize',10,'fontweight','bold');
        bgcolor = [0 0 0];
        uicontrol('parent',hFig,'style','edit','units','pixel','position',[x+109 y+3 200 20],'tag','PerformanceThisBlock','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold');
        y = y - 23; bgcolor = figure_bgcolor;
        uicontrol('parent',hFig,'style','text','units','pixel','position',[x y 62 20],'string','This cond','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','right');
        uicontrol('parent',hFig,'style','text','units','pixel','position',[x+64 y+2 45 20],'tag','PerformanceThisCond2','backgroundcolor',bgcolor,'foregroundcolor',[1 1 1],'fontsize',10,'fontweight','bold');
        bgcolor = [0 0 0];
        uicontrol('parent',hFig,'style','edit','units','pixel','position',[x+109 y+3 200 20],'tag','PerformanceThisCond','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold');

        colororder = [0 1 0; 0 1 1; 1 1 0; 0 0 1; 0.5 0.5 0.5; 1 0 1; 1 0 0; .3 .7 .5; .7 .2 .5; .5 .5 1; .75 .75 .5];
        performance_bar.PerformanceOverAll = zeros(2,10);
        performance_bar.PerformanceThisBlock = zeros(2,10);
        performance_bar.PerformanceThisCond = zeros(2,10);
        for m=1:10
            performance_bar.PerformanceOverAll(1,m) = uicontrol('parent',hFig,'style','frame','visible','off','backgroundcolor',colororder(m,:));
            performance_bar.PerformanceThisBlock(1,m) = uicontrol('parent',hFig,'style','frame','visible','off','backgroundcolor',colororder(m,:));
            performance_bar.PerformanceThisCond(1,m) = uicontrol('parent',hFig,'style','frame','visible','off','backgroundcolor',colororder(m,:));
            performance_bar.PerformanceOverAll(2,m) = uicontrol('parent',hFig,'style','text','visible','off','string',num2str(m-1),'backgroundcolor',colororder(m,:),'foregroundcolor',[1 1 1],'fontsize',fontsize,'fontweight','bold');
            performance_bar.PerformanceThisBlock(2,m) = uicontrol('parent',hFig,'style','text','visible','off','string',num2str(m-1),'backgroundcolor',colororder(m,:),'foregroundcolor',[1 1 1],'fontsize',fontsize,'fontweight','bold');
            performance_bar.PerformanceThisCond(2,m) = uicontrol('parent',hFig,'style','text','visible','off','string',num2str(m-1),'backgroundcolor',colororder(m,:),'foregroundcolor',[1 1 1],'fontsize',fontsize,'fontweight','bold');
        end
        
        x = x + 10; y = y - 23; bgcolor = figure_bgcolor;
        uicontrol('parent',hFig,'style','text','units','pixel','position',[x y 110 20],'string','Screen zoom (%) :','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        uicontrol('parent',hFig,'style','edit','tag','operatorview1','units','pixel','position',[x+110 y+3 50 20],'fontsize',fontsize,'callback',callbackfunc);
        uicontrol('parent',hFig,'style','slider','tag','operatorview2','min',ControlScreenZoomRange(1),'max',ControlScreenZoomRange(2),'sliderstep',[1 10]./(ControlScreenZoomRange(2)-ControlScreenZoomRange(1)),'value',ControlScreenZoomRange(1),'units','pixel','position',[x+170 y+3 120 19],'fontsize',fontsize,'callback',callbackfunc);

        x = 505; y = 5;
        hMessagebox = uicontrol('style','list','position',[x y 300-dx 174],'string',{'<html><font color="gray">>> End of the messages</font></html>'},'backgroundcolor',[1 1 1],'fontsize',fontsize);

        x = 810; y = fh - 603+dy;
        hTimeline = subplot('position',[0.2 0 0.1 0.1]);
        set(hTimeline,'tag','timeline','units','pixel','position',[x-dx y 180 600-dy],'xlim',[0 1],'ylim',[0 1],'xtick',[],'ytick',[],'box','on','color',[0.3 0.3 0.5]);
        h = text(0.5,0.97,'Time Line');
        set(h,'color',[1 1 1],'horizontalalignment','center','fontweight','bold','fontsize',11);
        patch([0.25 0.28 0.28 0.25],[0.05 0.05 0.90 0.90],[1 1 1]);
        
        hUserplot = subplot('position',[0.2 0 0.1 0.1]);
        set(hUserplot,'tag','userplot','units','pixel','xtick',[],'ytick',[],'box','off','color',figure_bgcolor);
        if verLessThan('matlab','8.4')
            set(hUserplot,'position',[850-dx 42 127 109]);
        else
            set(hUserplot,'outerposition',[810-dx 0 184 184]);
        end
    	pause(0.3); drawnow;

        mglcreatecontrolscreen(Pos2Rect([fx-1 fy-1 0 0]+replica_pos));
        update_UI();

        if ~isempty(MLPath.BehavioralCodesFile)
            code_str = regexp(fileread(MLPath.BehavioralCodesFile),'([0-9]+)[ \t]+([^\n]+)','tokens');
            code_str = [code_str{:}]';
            BehavioralCodes.CodeNumbers = cellfun(@str2double, code_str(1:2:end));
            BehavioralCodes.CodeNames = strtrim(code_str(2:2:end));
        end
        TrialRecord.TaskInfo.BehavioralCodes = BehavioralCodes;
    end

    function UIcallback(hObject,~)
        obj_tag = get(hObject,'tag');
        switch lower(obj_tag)
            case 'operatorview1'
                val = round(str2double(get(gcbo,'string')));
                if ControlScreenZoomRange(1)<=val && val<=ControlScreenZoomRange(2), MLConfig.ControlScreenZoom = val; end

            case 'operatorview2'
                val = round(get(gcbo,'value'));
                if ControlScreenZoomRange(1)<=val && val<=ControlScreenZoomRange(2), MLConfig.ControlScreenZoom = val; end
        end
        update_UI();
    end

    function update_UI()
        set(findobj(hFig,'tag','operatorview1'),'string',num2str(MLConfig.ControlScreenZoom));
        set(findobj(hFig,'tag','operatorview2'),'value',MLConfig.ControlScreenZoom);
        mglsetcontrolscreenzoom(MLConfig.ControlScreenZoom/100);
   end

    function on_move(~,~)
        try
            set(hFig,'Units','pixel');
            controlscreenposition = get(hFig,'position');
            mglsetcontrolscreenrect(Pos2Rect([controlscreenposition(1:2)-1 0 0]+replica_pos));
            drawnow;
        catch
            % do nothing
        end
    end

    function closeDlg(~,~)
        stop(DAQ);
        mglkeepsystemawake(false);
        mglsetcursorpos(-1);
        destroy(Screen);
        closereq;
        looping = false;
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