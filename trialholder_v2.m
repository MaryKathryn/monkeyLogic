function varargout = trialholder(MLConfig,TrialRecord,TaskObject,TrialData)
% This is the code into which a timing script is embedded (by "embed_timingfile") to create the run-time trial function.
%
%   Sep 7, 2017     Written by Jaewon Hwang (jaewon.hwang@nih.gov, jaewon.hwang@hotmail.com)

%% initialization
global ML_global_timer ML_global_timer_offset ML_prev_eye_position ML_trialtime_offset ML_Clock %#ok<NUSED>
if isempty(ML_global_timer), ML_global_timer = tic; end
varargout{1} = [];

DAQ = MLConfig.DAQ;
DAQ.simulated_input(-1);
Screen = MLConfig.Screen;
SIMULATION_MODE = TrialRecord.SimulationMode;
if SIMULATION_MODE, DAQ.add_mouse(); DAQ.create_simulated_output(); end

% writes the Info field from the conditions file if it exists in TrialRecord
Info = TrialRecord.CurrentConditionInfo;
StimulusInfo = TrialRecord.CurrentConditionStimulusInfo;

% Assigning structure fields to non-structure variable is totally redundant, but it makes the execution time significantly faster.
ML_BackgroundColor = MLConfig.SubjectScreenBackground;
ML_FrameLength = Screen.FrameLength;

% calibration function provider
EyeCal = mlcalibrate('eye',MLConfig);
JoyCal = mlcalibrate('joy',MLConfig);

% TaskObject variables
ML_ObjectID = TaskObject.ID;
ML_nObject = length(TaskObject);

ML_Modality = TaskObject.Modality;
ML_Visual = 1==ML_Modality | 2==ML_Modality;
ML_Movie = 2==ML_Modality;
ML_Sound = 3==ML_Modality;

ML_IO_Channel = zeros(1,ML_nObject);
for ML_=find(4==ML_Modality|5==ML_Modality), ML_IO_Channel(ML_) = TaskObject(ML_).MoreInfo.Channel; end

if DAQ.mouse_present, ML_Mouse = DAQ.get_device('mouse'); else ML_Mouse = pointingdevice; end
if TrialRecord.CurrentTrialNumber < 2, DAQ.goodmonkey(20,'ML_WarmingUp',true,'NumReward',1); end

% RunScene parameters
param_ = RunSceneParam;
param_.Screen = Screen;
param_.DAQ = DAQ;
param_.Mouse = ML_Mouse;
param_.SimulationMode = SIMULATION_MODE;
param_.PhotoDiodeStatus = false;
param_.trialtime = @trialtime;
param_.goodmonkey = @goodmonkey;
param_.dashboard = @dashboard;

% prepare the screen indicators
if 1 < MLConfig.PhotoDiodeTrigger, mglactivategraphic([Screen.PhotodiodeWhite Screen.PhotodiodeBlack],[param_.PhotoDiodeStatus ~param_.PhotoDiodeStatus]); end
mglactivategraphic(Screen.DashBoard,true);
mglactivategraphic([Screen.Reward Screen.RewardCount Screen.RewardDuration Screen.TTL(:)' Screen.Stimulation(:)'],false);

ML_Tracker = TrackerAggregate();
if SIMULATION_MODE || DAQ.eye_present, eye_ = EyeTracker(MLConfig,TaskObject,EyeCal,SIMULATION_MODE); ML_Tracker.add(eye_); end
if SIMULATION_MODE || DAQ.joystick_present, joy_ = JoyTracker(MLConfig,TaskObject,JoyCal,SIMULATION_MODE); ML_Tracker.add(joy_); end
if SIMULATION_MODE || DAQ.mouse_present, touch_ = TouchTracker(MLConfig,TaskObject,EyeCal,SIMULATION_MODE); ML_Tracker.add(touch_); end
if SIMULATION_MODE || DAQ.button_present, button_ = ButtonTracker(MLConfig,TaskObject,EyeCal,SIMULATION_MODE); ML_Tracker.add(button_); end
null_ = NullTracker(MLConfig,TaskObject,EyeCal,SIMULATION_MODE);

    %% function create_scene
    function ml_scene = create_scene(adapter,stimuli)
        if ~exist('stimuli','var'), stimuli = []; end
        ml_scene = SceneParam();
        adapter.info(ml_scene);
		ml_scene.Adapter = adapter;
        for ml_=stimuli(:)'
            switch ML_Modality(ml_)
                case 1, ml_scene.Visual(end+1) = ml_;
                case 2, ml_scene.Visual(end+1) = ml_; ml_scene.Movie(end+1) = ml_;
                case 3, ml_scene.Sound(end+1) = ml_;
                case 4, ml_scene.STM(end+1) = ml_;
                case 5, ml_scene.TTL(end+1) = ml_;
            end
        end

        if TrialRecord.CurrentTrialNumber < 2
            param_.SceneStartTime = trialtime();
            param_.SceneStartFrame = param_.FrameNum;
            ML_Tracker.init(param_);
            adapter.init(param_);
            DAQ.peekfront();
            ML_Tracker.acquire(param_);
            adapter.analyze(param_);
            adapter.draw(param_);
            mglrendergraphic(0);
            ML_Tracker.fini(param_);
            adapter.fini(param_);
        end
    end

    %% function run_scene
    ML_GraphicsUsedInThisTrial = false(1,ML_nObject);
    ML_SkippedFrameTimeInfo = [];
    ML_TotalSkippedFrames = 0;
    ML_SceneCount = 0;
    ML_MaxObjectStatusRecord = 500;
    ML_ObjectStatusRecord.SceneParam(1) = copy(SceneParam);
    ML_MaxFrameInterval = 0;
    ML_MaxDrawingTime = 0;
    ML_MaxEyeTargetIndex = 500;
    ML_EyeTargetRecord = zeros(ML_MaxEyeTargetIndex,4);
    ML_EyeTargetIndex = 0;
    function ml_fliptime = run_scene(scene,event)
        if ~exist('event','var'), event = []; end

        mglactivategraphic(ML_ObjectID(scene.Visual),true);
        mglactivatesound(ML_ObjectID(scene.Sound),true);
        if ~isempty(scene.STM), register([DAQ.Stimulation{ML_IO_Channel(scene.STM)}]); mglactivategraphic(Screen.Stimulation(:,scene.STM),true); end
        if ~isempty(scene.TTL), register([DAQ.TTL{ML_IO_Channel(scene.TTL)}]); mglactivategraphic(Screen.TTL(:,scene.TTL),true); end
        if 1 < MLConfig.PhotoDiodeTrigger, param_.PhotoDiodeStatus = ~param_.PhotoDiodeStatus; mglactivategraphic([Screen.PhotodiodeWhite Screen.PhotodiodeBlack],[param_.PhotoDiodeStatus ~param_.PhotoDiodeStatus]); end
        ML_GraphicsUsedInThisTrial(scene.Visual) = true;
        scene.Position = TaskObject.Position;
        scene.BackgroundColor = ML_BackgroundColor;
        [scene.MovieCurrentPosition,scene.MovieLooping] = mdqmex(103,TaskObject.ID(scene.Movie));

        param_.reset();
        param_.SceneStartTime = trialtime();
        param_.SceneStartFrame = floor(param_.SceneStartTime/ML_FrameLength);
        param_.FrameNum = param_.SceneStartFrame;

        ML_Tracker.init(param_);
        scene.Adapter.init(param_);
        DAQ.peekfront();
        ML_Tracker.acquire(param_);
        continue_ = scene.Adapter.analyze(param_);
        scene.Adapter.draw(param_);
        mglrendergraphic(param_.FrameNum);
        ML_MaxDrawingTime = max(ML_MaxDrawingTime,param_.scene_time());
        ml_fliptime = mdqmex(97,true,[event param_.EventMarker]); param_.EventMarker = [];
        mglpresent(2,MLConfig.RunMessageLoop,SIMULATION_MODE);
        param_.FrameNum = param_.FrameNum + 1;
        ml_prevflip = ml_fliptime;
        while continue_
            ml_drawingstart = trialtime();
            DAQ.peekfront();
            ML_Tracker.acquire(param_);
            continue_ = scene.Adapter.analyze(param_);
            scene.Adapter.draw(param_);
            mglrendergraphic(param_.FrameNum);
            ML_MaxDrawingTime = max(ML_MaxDrawingTime,trialtime()-ml_drawingstart);
            ml_currentflip = mdqmex(97,true,param_.EventMarker,true,false); param_.EventMarker = [];
            mglpresent(2,MLConfig.RunMessageLoop,SIMULATION_MODE);
            ml_frame_interval = ml_currentflip - ml_prevflip;
            ml_skipped = round(ml_frame_interval / ML_FrameLength) - 1;
            if 0 < ml_skipped
                eventmarker(13);
                param_.FrameNum = NaN;
                ML_TotalSkippedFrames = ML_TotalSkippedFrames + ml_skipped;
                ML_SkippedFrameTimeInfo(end+1,1:5) = [ml_prevflip ML_MaxDrawingTime ml_frame_interval ml_skipped ML_FrameLength]; %#ok<AGROW>
                user_warning('%d skipped frame(s) at %.0f ms. (Total %d skipped)', ml_skipped, ml_prevflip, ML_TotalSkippedFrames);
            end
            ML_MaxFrameInterval = max(ML_MaxFrameInterval,ml_frame_interval);
            ml_kb = kbdgetkey; if ~isempty(ml_kb), hotkey(ml_kb); end
            if isnan(param_.FrameNum), param_.FrameNum = floor(trialtime()/ML_FrameLength); else param_.FrameNum = param_.FrameNum + 1; end
            ml_prevflip = ml_currentflip;
        end
        ML_Tracker.fini(param_);
        scene.Adapter.fini(param_);
        
        if ML_SceneCount < ML_MaxObjectStatusRecord
            scene.Time = ml_fliptime;
            ML_SceneCount = ML_SceneCount + 1;
            ML_ObjectStatusRecord.SceneParam(ML_SceneCount) = copy(scene);
        end
        if ~isempty(param_.EyeTargetRecord) && ML_EyeTargetIndex < ML_MaxEyeTargetIndex
            ML_EyeTargetIndex = ML_EyeTargetIndex + 1;
            ML_EyeTargetRecord(ML_EyeTargetIndex,:) = param_.EyeTargetRecord;
        end
        
        mglactivategraphic(ML_ObjectID(scene.Visual),false);
        mglstopsound(ML_ObjectID(scene.Sound)); mglactivatesound(ML_ObjectID(scene.Sound),false);
        if ~isempty(scene.STM), stop([DAQ.Stimulation{ML_IO_Channel(scene.STM)}]); end
        if ~isempty(scene.TTL), putvalue([DAQ.TTL{ML_IO_Channel(scene.TTL)}],0); end
    end

    %% function eventmarker
    function eventmarker(code), DAQ.eventmarker(code); end

    %% function goodmonkey
    ML_RewardCount = 0;
    function goodmonkey(duration, varargin)
        ML_RewardCount = ML_RewardCount + DAQ.goodmonkey(duration, varargin{:});
        if SIMULATION_MODE || DAQ.reward_present
            mglactivategraphic([Screen.Reward Screen.RewardCount],true);
            mglsetproperty(Screen.RewardCount,'text',sprintf('%d',ML_RewardCount));
        end
    end

    %% function trialerror
    TrialData.TrialError = 9;
    function trialerror(e)
        if isnumeric(e)
            if e < 0 || 9 < e, error('TrialErrors can range from 0 to 9'); end
            TrialData.TrialError = e;
        elseif ischar(e)
            ml_str = {'correct','no response','late response','break fixation','no fixation','early response','incorrect','lever break','ignored','aborted'};
            ml_f = find(strncmpi(ml_str,e,length(e)));
            if isempty(ml_f)
                error('Unrecognized string passed to TrialError');
            elseif 1 < length(ml_f)
                error('Ambiguous argument passed to TrialError');
            end
            TrialData.TrialError = ml_f - 1;
        else
            error('Unexpected argument type passed to TrialError (must be either numeric or string)');
        end
    end

    %% function mouse_position
    function [ml_mouse, ml_button] = mouse_position()
        [ml_xy,ml_button] = getsample(ML_Mouse);
        if SIMULATION_MODE
            ml_mouse = EyeCal.control2deg(ml_xy);
        else
            ml_mouse = EyeCal.subject2deg(ml_xy);
        end
    end

    %% function eye_position
    function varargout = eye_position()
        if SIMULATION_MODE
            ml_eye = mouse_position();
        elseif DAQ.eye_present
            getsample(DAQ);
            ml_eye = EyeCal.sig2deg(DAQ.Eye,param_.EyeOffset);
        else
            ml_eye = [0 0];
        end
        switch nargout
            case 1, varargout{1} = ml_eye;
            case 2, varargout{1} = ml_eye(1); varargout{2} = ml_eye(2);
        end
    end
    
    %% function joystick_position
    function varargout = joystick_position(varargin)
        if SIMULATION_MODE
            ml_joy = DAQ.SimulatedJoystick;
        else
            getsample(DAQ);
            ml_joy = JoyCal.sig2deg(DAQ.Joystick,param_.JoyOffset);
        end
        switch nargout
            case 1, varargout{1} = ml_joy;
            case 2, varargout{1} = ml_joy(1); varargout{2} = ml_joy(2);
        end
   end

    %% function get_analog_data
    function [ml_data,ml_frq] = get_analog_data(sig,varargin)
        if isempty(varargin), ml_numsamples = 1; else ml_numsamples = varargin{1}; end

        ml_frq = 1000;
        peekdata(DAQ,ml_numsamples);
        if SIMULATION_MODE
            switch lower(sig(1:3))
                case {'eye','mou'}, ml_data = EyeCal.control2deg(DAQ.Mouse);
                case 'joy', ml_data = repmat(DAQ.SimulatedJoystick,ml_numsamples,1);
                otherwise,  ml_data = 10 * sin((ml_numsamples:-1:1)*pi/500)' + rand(ml_numsamples,1);
            end
        else
            switch lower(sig(1:3))
                case 'eye', ml_data = EyeCal.sig2deg(DAQ.Eye,param_.EyeOffset);
                case 'joy', ml_data = JoyCal.sig2deg(DAQ.Joystick,param_.JoyOffset);
                case 'mou', ml_data = EyeCal.subject2deg(DAQ.Mouse);
                case 'gen', ml_data = DAQ.General{str2double(regexp(sig,'\d+','match'))};
                otherwise,  ml_data = DAQ.(sig);
            end
        end
   end

    %% function getkeypress
    function [ml_scancode, ml_rt] = getkeypress(maxtime, varargin)
        kbdflush;
        ml_rt = NaN;
        ml_t1 = trialtime;
        ml_t2 = trialtime - ml_t1;
        while ml_t2 < maxtime
            ml_scancode = kbdgetkey;
            ml_t2 = trialtime - ml_t1;
            if ~isempty(ml_scancode), ml_rt = ml_t2; break, end
        end
    end

    %% function hotkey
    ML_SCAN_LETTERS = '`1234567890-=qwertyuiop[]\asdfghjkl;''zxcvbnm,./';
    ML_SCAN_CODES = [41 2:13 16:27 43 30:40 44:53];
    ML_KeyNumbers = [];
    ML_KeyCallbacks = {};
    function hotkey(keyval, varargin)
        if isnumeric(keyval)
            ml_ = ML_KeyNumbers == keyval;
            if any(ml_), eval(ML_KeyCallbacks{ml_}); end
            return
        end

        if 1 < length(keyval)
            switch lower(keyval)
                case 'esc', ml_keynum = 1;
                case 'rarr', ml_keynum = 205;
                case 'larr', ml_keynum = 203;
                case 'uarr', ml_keynum = 200;
                case 'darr', ml_keynum = 208;
                case 'numrarr', ml_keynum = 77;
                case 'numlarr', ml_keynum = 75;
                case 'numuarr', ml_keynum = 72;
                case 'numdarr', ml_keynum = 80;
                case 'space', ml_keynum = 57;
                case 'bksp', ml_keynum = 14;
                case {'f1','f2','f3','f4','f5','f6','f7','f8','f9','f10'}, ml_keynum = 58 + str2double(keyval(2:end));
                case 'f11', ml_keynum = 87;
                case 'f12', ml_keynum = 88;
                otherwise, error('Must specify only one letter, number, or symbol on each call to "hotkey" unless specifying a function key such as "F3"');
            end
        else
            ml_keynum = ML_SCAN_CODES(ML_SCAN_LETTERS == lower(keyval));
        end
        if isempty(varargin) || isempty(varargin{1}), fprintf('Warning: No function declared for HotKey "%s"\n', keyval); return, end

        ML_KeyNumbers(end+1) = ml_keynum;
        ML_KeyCallbacks{end+1} = varargin{1};
    end

    %% function reposition_object
    function ml_success = reposition_object(stimnum, xydeg, ydeg)
        if any(ML_nObject < stimnum), error('Some of given stimuli do not exist.'); end
        if any(~ML_Visual(stimnum)), error('Some of given stimuli are non-visual.'); end

        if 2<nargin, xydeg = [xydeg(:) ydeg(:)]; end

        TaskObject.Position(stimnum,:) = xydeg;
        mglsetorigin(ML_ObjectID(stimnum),TaskObject.ScreenPosition(stimnum,:));
        ml_success = true;
    end


    %% function idle
    ML_IdleTimeCounter = TimeCounter(null_);
    ML_IdleScene = create_scene(ML_IdleTimeCounter);
    ML_IdleDuration = find(strcmp(ML_IdleScene.AdapterArgs{2}(:,1),'Duration'));
    function idle(duration, varargin)
        if ~isempty(varargin)
            ML_BackgroundColor = varargin{1};
            mglsetscreencolor(1,ML_BackgroundColor);
        end
        ML_IdleTimeCounter.Duration = duration;
        ML_IdleScene.AdapterArgs{2}{ML_IdleDuration,2} = duration;
        run_scene(ML_IdleScene);
        if ~isempty(varargin)
            ML_BackgroundColor = MLConfig.SubjectScreenBackground;
            mglsetscreencolor(1,ML_BackgroundColor);
        end
    end
    
    %% function set_iti
    TrialData.InterTrialInterval = MLConfig.InterTrialInterval;
    function set_iti(t), TrialData.InterTrialInterval = t; end

    %% functon showcursor
    function showcursor(cflag)
        if ischar(cflag), param_.ShowJoyCursor = strcmpi(cflag, 'on'); else param_.ShowJoyCursor = logical(cflag); end
    end

    %% function trialtime
    function ml_t = trialtime(), ml_t = mdqmex(93); end  % in milliseconds
 
    %% function bhv_variable
    function bhv_variable(varname, val), TrialData.UserVars.(varname) = val; end

    %% function escape_screen
    mglactivategraphic(Screen.EscapeRequested,TrialRecord.Pause);
    function escape_screen()
        TrialRecord.Pause = true;
        mglactivategraphic(Screen.EscapeRequested,TrialRecord.Pause);
    end

    %% function user_text
    ML_MessageCount = 0;
    function user_text(varargin)
        varargin{1} = sprintf('Trial %d: %s',TrialRecord.CurrentTrialNumber,varargin{1});
        ML_MessageCount = ML_MessageCount + 1;
        TrialData.UserMessage{ML_MessageCount} = [varargin,'i'];
    end
    
    %% function user_warning
    function user_warning(varargin)
        varargin{1} = sprintf('Trial %d: %s',TrialRecord.CurrentTrialNumber,varargin{1});
        ML_MessageCount = ML_MessageCount + 1;
        TrialData.UserMessage{ML_MessageCount} = [varargin,'e'];
    end

    %% function rewind_movie
    function rewind_movie(stimnum,time_in_msec)
        if ~exist('stimnum','var'), stimnum = find(ML_Movie); end
        if ~exist('time_in_msec','var'), time_in_msec = 0; end
        nstim = length(stimnum); ntime = length(time_in_msec);
        if ntime < nstim, time_in_msec(ntime+1:nstim) = time_in_msec(ntime); end
        for ml_=1:nstim, mglsetproperty(ML_ObjectID(stimnum(ml_)),'seek',time_in_msec(ml_)/1000); end
    end

    %% function get_movie_duration
    function [duration_in_msec,duration_in_frames] = get_movie_duration(stimnum)
        if ~exist('stimnum','var'), stimnum = find(ML_Movie); end
        duration_in_msec = [TaskObject(stimnum).MoreInfo.Duration] * 1000;
        duration_in_frames = [TaskObject(stimnum).MoreInfo.DurationInRefreshCounts];
    end

    %% function rewind_sound
    function rewind_sound(stimnum,time_in_msec)
        if ~exist('stimnum','var'), stimnum = find(ML_Sound); end
        if ~exist('time_in_msec','var'), time_in_msec = 0; end
        nstim = length(stimnum); ntime = length(time_in_msec);
        if ntime < nstim, time_in_msec(ntime+1:nstim) = time_in_msec(ntime); end
        for ml_=1:nstim, mglsetproperty(ML_ObjectID(stimnum(ml_)),'seek',time_in_msec(ml_)/1000); end
    end

    %% function get_sound_duration
    function duration_in_msec = get_sound_duration(stimnum)
        if ~exist('stimnum','var'), stimnum = find(ML_Sound); end
        duration_in_msec = [TaskObject(stimnum).MoreInfo.Duration] * 1000;
    end

    %% function dashboard
    function dashboard(n,text,color)
        if n<1 || length(Screen.DashBoard)<n, return, end
        mglsetproperty(Screen.DashBoard(n),'text',text);
        if exist('color','var'), mglsetproperty(Screen.DashBoard(n),'color',color); end
    end

    %% function pause
    function pause(sec), a = tic; while toc(a)<sec; end, end

    %% function fi
    function op = fi(tf,op1,op2), if tf, op = op1; else op = op2; end, end

    %% function OverrideJoyTransform
    function OverrideJoyTransform(theta), JoyCal.rotate(theta); end

    %% function bhv_code
    function bhv_code(varargin)
        if 0==nargin || 0~=mod(nargin,2), error('bhv_code requires all arguments to come in code/name pairs'); end
        ml_code = [varargin{1:2:end}]';
        ml_codename = varargin(2:2:end)';
        [ml_a,ml_b] = ismember(ml_code,TrialRecord.TaskInfo.BehavioralCodes.CodeNumbers);
        if any(ml_a)
            ml_c = find(~strcmp(ml_codename(ml_a),TrialRecord.TaskInfo.BehavioralCodes.CodeNames(ml_b(ml_a))),1);
            if ~isempty(ml_c), ml_d = find(ml_a); error('Code #%d already exists.',ml_code(ml_d(ml_c))); end
        end
        TrialRecord.TaskInfo.BehavioralCodes.CodeNumbers = [TrialRecord.TaskInfo.BehavioralCodes.CodeNumbers; ml_code(~ml_a)];
        TrialRecord.TaskInfo.BehavioralCodes.CodeNames = [TrialRecord.TaskInfo.BehavioralCodes.CodeNames; ml_codename(~ml_a)];
    end

    %% function end_trial
    function end_trial
        eventmarker(18);
        mglstopsound(0);

        % turn off the photodiode trigger so that it becomes black when the next trial begins.
        if 1 < MLConfig.PhotoDiodeTrigger
            mglactivategraphic([Screen.PhotodiodeWhite Screen.PhotodiodeBlack],[false true]);
            mglrendergraphic(param_.FrameNum,1,true);
            mglpresent(1);
        end
        
        TrialData.BehavioralCodes = struct('CodeTimes',[], 'CodeNumbers',[]);
        TrialData.AnalogData = struct('SampleInterval',[],'Eye',[],'EyeExtra',[],'Joystick',[],'Mouse',[],'PhotoDiode',[]);
        for ml_=1:DAQ.nGeneral, TrialData.AnalogData.General.(sprintf('Gen%d',ml_)) = []; end
        for ml_=1:DAQ.nButton, TrialData.AnalogData.Button.(sprintf('Btn%d',ml_)) = []; end
        
        if TrialRecord.TestTrial
            stop(DAQ);
            return
        end
        
        ml_SampleInterval = 1000 / MLConfig.AISampleRate;
        TrialData.AnalogData.SampleInterval = ml_SampleInterval;
        
        if MLConfig.NonStopRecording
            backmarker(DAQ);
            ML_trialtime_offset = toc(ML_global_timer);
            ML_Clock = clock;
            getback(DAQ);
            
            if SIMULATION_MODE
                if ~isempty(DAQ.Mouse)
                    TrialData.AnalogData.Eye = EyeCal.control2deg(DAQ.Mouse);
                    TrialData.AnalogData.Mouse = [TrialData.AnalogData.Eye DAQ.MouseButton];
                end
            else
                if ~isempty(DAQ.Eye), TrialData.AnalogData.Eye = EyeCal.sig2deg(DAQ.Eye,param_.EyeOffset); end
                if ~isempty(DAQ.EyeExtra), TrialData.AnalogData.EyeExtra = DAQ.EyeExtra; end
                if ~isempty(DAQ.Joystick), TrialData.AnalogData.Joystick = JoyCal.sig2deg(DAQ.Joystick,param_.JoyOffset); end
                if ~isempty(DAQ.Mouse), TrialData.AnalogData.Mouse = [EyeCal.subject2deg(DAQ.Mouse) DAQ.MouseButton]; end
                if ~isempty(DAQ.PhotoDiode), TrialData.AnalogData.PhotoDiode = DAQ.PhotoDiode; end
                for ml_=DAQ.general_available, TrialData.AnalogData.General.(sprintf('Gen%d',ml_)) = DAQ.General{ml_}; end
                for ml_=DAQ.buttons_available
                    if button_.Invert(ml_)
                        TrialData.AnalogData.Button.(sprintf('Btn%d',ml_)) = ~DAQ.Button{ml_};
                    else
                        TrialData.AnalogData.Button.(sprintf('Btn%d',ml_)) = DAQ.Button{ml_};
                    end
                end
            end
        else
            ml_MinSamplesExpected = ceil(trialtime());
            ml_SamplePoint = 1:ml_SampleInterval:ml_MinSamplesExpected;
            if DAQ.isrunning
                while DAQ.MinSamplesAvailable <= ml_MinSamplesExpected, end
                stop(DAQ);
            end
            getdata(DAQ);

            if SIMULATION_MODE
                if ~isempty(DAQ.Mouse)
                    TrialData.AnalogData.Eye = EyeCal.control2deg(DAQ.Mouse(ml_SamplePoint,:));
                    TrialData.AnalogData.Mouse = [TrialData.AnalogData.Eye DAQ.MouseButton(ml_SamplePoint,:)];
                end
            else
                if ~isempty(DAQ.Eye), TrialData.AnalogData.Eye = EyeCal.sig2deg(DAQ.Eye(ml_SamplePoint,:),param_.EyeOffset); end
                if ~isempty(DAQ.EyeExtra), TrialData.AnalogData.EyeExtra = DAQ.EyeExtra(ml_SamplePoint,:); end
                if ~isempty(DAQ.Joystick), TrialData.AnalogData.Joystick = JoyCal.sig2deg(DAQ.Joystick(ml_SamplePoint,:),param_.JoyOffset); end
                if ~isempty(DAQ.Mouse), TrialData.AnalogData.Mouse = [EyeCal.subject2deg(DAQ.Mouse(ml_SamplePoint,:)) DAQ.MouseButton(ml_SamplePoint,:)]; end
                if ~isempty(DAQ.PhotoDiode), TrialData.AnalogData.PhotoDiode = DAQ.PhotoDiode(ml_SamplePoint,:); end
                for ml_=DAQ.general_available, TrialData.AnalogData.General.(sprintf('Gen%d',ml_)) = DAQ.General{ml_}(ml_SamplePoint,:); end
                for ml_=DAQ.buttons_available
                    if button_.Invert(ml_)
                        TrialData.AnalogData.Button.(sprintf('Btn%d',ml_)) = ~DAQ.Button{ml_}(ml_SamplePoint,:);
                    else
                        TrialData.AnalogData.Button.(sprintf('Btn%d',ml_)) = DAQ.Button{ml_}(ml_SamplePoint,:);
                    end
                end
            end
        end
        
        % eye & joy traces
        ml_eye_trace = NaN;
        ml_joy_trace = NaN;
        ml_touch_trace = NaN;
        if MLConfig.SummarySceneDuringITI
            if ~isempty(TrialData.AnalogData.Eye)
                ml_eye = EyeCal.deg2pix(TrialData.AnalogData.Eye);
                ml_eye_trace = mgladdline(MLConfig.EyeTracerColor,size(ml_eye,1),1,10);
                mglsetproperty(ml_eye_trace,'addpoint',ml_eye);
            end
            if ~isempty(TrialData.AnalogData.Joystick)
                ml_joy = JoyCal.deg2pix(TrialData.AnalogData.Joystick);
                ml_joy_trace = mgladdline(MLConfig.JoystickCursorColor,size(ml_joy,1),1,10);
                mglsetproperty(ml_joy_trace,'addpoint',ml_joy);
            end
            if ~isempty(TrialData.AnalogData.Mouse)
                ml_touch = EyeCal.deg2pix(TrialData.AnalogData.Mouse(logical(TrialData.AnalogData.Mouse(:,3)),1:2));
                ml_ntouch = size(ml_touch,1);
                if 1000<ml_ntouch
                    ml_touch = ml_touch(round(linspace(1,ml_ntouch,1000)),:);
                    ml_ntouch = 1000;
                end
                ml_touch_trace = NaN(1,ml_ntouch);
                ml_imdata = load_cursor(MLConfig.TouchCursorImage,MLConfig.TouchCursorShape,MLConfig.TouchCursorColor,MLConfig.TouchCursorSize);
                for ml_=1:ml_ntouch, ml_touch_trace(ml_) = mgladdbitmap(ml_imdata,10); end
                mglsetorigin(ml_touch_trace,ml_touch);
            end
            mglactivategraphic(ML_ObjectID(ML_Visual),false);
            mglactivategraphic(ML_ObjectID(ML_GraphicsUsedInThisTrial),true);
        end
        
        % eye drift correction
        ml_id = NaN;
        if 0<MLConfig.EyeAutoDriftCorrection && all(0==param_.EyeOffset) && 0 < ML_EyeTargetIndex && ~isempty(TrialData.AnalogData.Eye)
            ML_EyeTargetRecord = ML_EyeTargetRecord(ml_SampleInterval < ML_EyeTargetRecord(:,4),:);
            ML_EyeTargetRecord(:,3) = ceil(ML_EyeTargetRecord(:,3) ./ ml_SampleInterval);
            ML_EyeTargetRecord(:,4) = ML_EyeTargetRecord(:,3) + floor(ML_EyeTargetRecord(:,4) ./ ml_SampleInterval) - 1;
            ml_npoint = size(ML_EyeTargetRecord,1);
            ml_new_fix_point = zeros(ml_npoint,2);
            for ml_ = 1:ml_npoint
                ml_new_fix_point(ml_,:) = median(TrialData.AnalogData.Eye(ML_EyeTargetRecord(ml_,3):ML_EyeTargetRecord(ml_,4),:),1);
            end
            param_.EyeOffset = mean(ml_new_fix_point - ML_EyeTargetRecord(:,1:2),1) * EyeCal.rotation_rev_t .* (MLConfig.EyeAutoDriftCorrection / 100);

            if MLConfig.SummarySceneDuringITI
                ML_EyeTargetRecord(:,1:2) = EyeCal.deg2pix(ML_EyeTargetRecord(:,1:2));
                ml_new_fix_point = EyeCal.deg2pix(ml_new_fix_point);
                ml_id = NaN(ml_npoint,2);
                ml_size = 0.3 * MLConfig.PixelsPerDegree(1);
                for ml_ = 1:ml_npoint
                    ml_id(ml_,1) = mgladdcircle([MLConfig.FixationPointColor; MLConfig.FixationPointColor],ml_size,10); mglsetorigin(ml_id(ml_,1),ML_EyeTargetRecord(ml_,1:2));
                    ml_id(ml_,2) = mgladdcircle([MLConfig.EyeTracerColor; MLConfig.EyeTracerColor],ml_size,10); mglsetorigin(ml_id(ml_,2),ml_new_fix_point(ml_,:));
                end
            end
        end
        mglsetscreencolor(2,fi(MLConfig.NonStopRecording,[0 0.4 0.2],[0.25 0.25 0.25]));
        mdqmex(104);  % ClearControlScreenEdge
        mglrendergraphic(param_.FrameNum,2,false);
        mglpresent(2);
        mgldestroygraphic([ml_eye_trace ml_joy_trace ml_touch_trace ml_id(:)']);

        % update EyeTransform
        if any(param_.EyeOffset), EyeCal.translate(param_.EyeOffset); end
        
        [TrialData.BehavioralCodes.CodeTimes,TrialData.BehavioralCodes.CodeNumbers] = mdqmex(98);
        TrialData.ReactionTime = rt;
        TrialData.ObjectStatusRecord.SceneParam = ML_ObjectStatusRecord.SceneParam(1:ML_SceneCount);
        [TrialData.RewardRecord.StartTimes,TrialData.RewardRecord.EndTimes] = mdqmex(101);
        TrialData.CycleRate = [ML_MaxFrameInterval ML_MaxDrawingTime];
        TrialData.NewEyeTransform = EyeCal.get_transform_matrix();
        TrialData.VariableChanges.EyeOffset = param_.EyeOffset;
        TrialData.VariableChanges.reward_dur = reward_dur;
        TrialData.UserVars.SkippedFrameTimeInfo = ML_SkippedFrameTimeInfo;
        TrialData.TaskObject.CurrentConditionInfo = TrialRecord.CurrentConditionInfo;
        TrialData.Ver = 2.1;
    end


%% Task
hotkey('esc', 'escape_screen;');   % early escape
hotkey('r', 'goodmonkey(reward_dur,''juiceline'',MLConfig.RewardFuncArgs.JuiceLine,''eventmarker'',14,''nonblocking'',1);');  % reward
hotkey('-', 'reward_dur = max(0,reward_dur-10); mglactivategraphic(Screen.RewardDuration,true); mglsetproperty(Screen.RewardDuration,''text'',sprintf(''JuiceLine: %d, reward_dur: %.0f'',MLConfig.RewardFuncArgs.JuiceLine,reward_dur));');
hotkey('=', 'reward_dur = reward_dur + 10; mglactivategraphic(Screen.RewardDuration,true); mglsetproperty(Screen.RewardDuration,''text'',sprintf(''JuiceLine: %d, reward_dur: %.0f'',MLConfig.RewardFuncArgs.JuiceLine,reward_dur));');
if SIMULATION_MODE
    hotkey('rarr', 'DAQ.simulated_input(1,1,1);');  % joystick right left up down
    hotkey('larr', 'DAQ.simulated_input(1,1,-1);');
    hotkey('uarr', 'DAQ.simulated_input(1,2,1);');
    hotkey('darr', 'DAQ.simulated_input(1,2,-1);');
else
    hotkey('c', 'ML_prev_eye_position(end+1,:) = eye_position * EyeCal.rotation_rev_t; param_.EyeOffset = param_.EyeOffset + ML_prev_eye_position(end,:);');  % adjust eye offset
    hotkey('u', 'if ~isempty(ML_prev_eye_position), param_.EyeOffset = param_.EyeOffset - ML_prev_eye_position(end,:); ML_prev_eye_position(end,:) = []; end');
end

kbdflush;
rt = NaN;

if MLConfig.NonStopRecording
    if TrialRecord.CurrentTrialNumber < 2
        start(DAQ);
        flushmarker(DAQ);
        ML_trialtime_offset = toc(ML_global_timer);
        ML_Clock = clock;
        flushdata(DAQ);
        ML_global_timer_offset = ML_trialtime_offset;
    end
    TrialData.TrialDateTime = ML_Clock;
else
    start(DAQ);
    flushmarker(DAQ);
    ML_trialtime_offset = toc(ML_global_timer);
    TrialData.TrialDateTime = clock;
    flushdata(DAQ);
    if TrialRecord.CurrentTrialNumber < 2, ML_global_timer_offset = ML_trialtime_offset; end
end
TrialData.AbsoluteTrialStartTime = (ML_trialtime_offset - ML_global_timer_offset) * 1000;
DAQ.init_timer(ML_global_timer,ML_trialtime_offset);
mglsetscreencolor(2,[0.1333 0.3333 0.5490]);

eventmarker(9);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%BEGINNING OF TIMING CODE**************************************************
%END OF TIMING CODE********************************************************
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

end_trial();

end  % end of trialholder()
