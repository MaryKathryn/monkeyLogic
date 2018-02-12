function varargout = trialholder(MLConfig,TrialRecord,TaskObject,TrialData)
% This is the code into which a timing script is embedded (by "embed_timingfile") to create the run-time trial function.
%
% See www.monkeylogic.org for more information.
%
%   Oct 22, 2016    This file is completely re-written by Jaewon Hwang.

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
ML_PixelsPerDegree = MLConfig.PixelsPerDegree(1);
ML_BackgroundColor = MLConfig.SubjectScreenBackground;
ML_FrameLength = Screen.FrameLength;

% calibration function provider
EyeCal = mlcalibrate('eye',MLConfig);
JoyCal = mlcalibrate('joy',MLConfig);

% TaskObject variables
ML_nObject = length(TaskObject);

ML_Visual = 1==TaskObject.Modality | 2==TaskObject.Modality;
ML_Visual_InitialFrame = NaN(1,ML_nObject);
ML_Visual_PositionArray = cell(1,ML_nObject);
ML_Visual_StartPosition = ones(1,ML_nObject);
ML_Visual_PositionStep = zeros(1,ML_nObject);
ML_Visual_nPosition = zeros(1,ML_nObject);

ML_Movie = 2==TaskObject.Modality;
ML_Movie_FrameByFrame = false(1,ML_nObject);
ML_Movie_StartTime = zeros(1,ML_nObject);
ML_Movie_StartFrame = ones(1,ML_nObject);
ML_Movie_FrameStep = zeros(1,ML_nObject);
ML_Movie_nFrame = zeros(1,ML_nObject);
ML_Movie_DurationInRefreshCounts = zeros(1,ML_nObject);
for ML_ = find(ML_Movie)
    ML_Movie_nFrame(ML_) = TaskObject(ML_).MoreInfo.TotalFrames;
    ML_Movie_DurationInRefreshCounts(ML_) = TaskObject(ML_).MoreInfo.DurationInRefreshCounts;
end
ML_Movie_FrameOrderArray = cell(1,ML_nObject);
ML_Movie_nFrameOrder = zeros(1,ML_nObject);
ML_Movie_FrameEventArray = cell(1,ML_nObject);
ML_Movie_nFrameEvent = zeros(1,ML_nObject);

ML_Sound = 3==TaskObject.Modality;
ML_Stimulation = 4==TaskObject.Modality;
ML_TTL = 5==TaskObject.Modality;
ML_IO_Channel = zeros(1,ML_nObject);
for ML_ = find(ML_Stimulation|ML_TTL), ML_IO_Channel(ML_) = TaskObject(ML_).MoreInfo.Channel; end

% DAQ variable cache
if SIMULATION_MODE
   ML_eyepresent = true;
   ML_joypresent = true;
   ML_buttonpresent = true;
   ML_ButtonsAvailable = 1:10;
else
    ML_eyepresent = DAQ.eye_present;
    ML_joypresent = DAQ.joystick_present;
    ML_buttonpresent = DAQ.button_present;
    ML_ButtonsAvailable = DAQ.buttons_available;
end
if DAQ.mouse_present, ML_Mouse = DAQ.get_device('mouse'); else ML_Mouse = pointingdevice; end

% prepare the tracers
ML_PdStatus = false;
if 1 < MLConfig.PhotoDiodeTrigger, mglactivategraphic([Screen.PhotodiodeWhite Screen.PhotodiodeBlack],[ML_PdStatus ~ML_PdStatus]); end
mglactivategraphic(Screen.EyeTracer,ML_eyepresent);
mglactivategraphic(Screen.JoystickCursor(2),ML_joypresent);
mglactivategraphic(Screen.ButtonLabel(ML_ButtonsAvailable),true);
mglactivategraphic(Screen.DashBoard,true);
mglactivategraphic([Screen.Reward Screen.RewardCount Screen.RewardDuration Screen.TTL(:)' Screen.Stimulation(:)'], false);

% eyejoytrack variables
ML_TimeFromLastPresent = zeros(1,9);
ML_SampleCycleStage = 0;
ML_SampleCycleTime = [];

% Benchmark variables
ML_Benchmark = false;
ML_BenchmarkSample = [];
ML_BenchmarkFrame = [];
ML_BenchmarkSampleCount = 0;
ML_BenchmarkFrameCount = 0;
ML_WarmingUp = false;


    %% function toggleobject
    ML_RenderingState = 0;
    ML_CurrentFrameNumber = 0;
    ML_LastPresentTime = 0;
    ML_eventcode = [];
    ML_forced_new_scene = false;
    ML_scene_updated = false;
    ML_GraphicsUsedInThisTrial = false(1,ML_nObject);
    ML_ShowJoyCursor = false;
    ML_SkippedFrameTimeInfo = [];
    ML_TotalSkippedFrames = 0;
    ML_ToggleCount = 0;
    ML_MaxObjectStatusRecord = 2000;
    ML_ObjectStatusRecord.Time = zeros(ML_MaxObjectStatusRecord,1);
    ML_ObjectStatusRecord.Status = zeros(ML_MaxObjectStatusRecord,ML_nObject);
    ML_ObjectStatusRecord.Position = cell(ML_MaxObjectStatusRecord,1);
    ML_ObjectStatusRecord.BackgroundColor = zeros(ML_MaxObjectStatusRecord,3);
    ML_ObjectStatusRecord.Info = [];
    for ML_=1:ML_MaxObjectStatusRecord
        ML_ObjectStatusRecord.Position{ML_} = zeros(ML_nObject,2);
    end
    function ml_tflip = toggleobject(stimuli, varargin)
        ml_tflip = [];
       
        if isempty(stimuli)         % do nothing
            return
        elseif 0 < stimuli(1)       % new stimuli to turn on/off
            ml_new_scene = true;
            ML_RenderingState = 0;
        else                        % call from eyejoytrack
            ml_new_scene = false;
            if ML_forced_new_scene, ML_RenderingState = 0; end
        end

        ml_position_update = [];
        ml_frame_update = [];
        non_framebyframe = [];
        if 0==ML_RenderingState
            ML_eventcode = [];
            ML_scene_updated = ML_forced_new_scene;
            if ml_new_scene
                ml_old_status = TaskObject.Status;

                % input arguments
                ml_stim2toggle = false(1,ML_nObject);
                ml_stim2toggle(stimuli) = true;
                ml_vis2toggle = ML_Visual & ml_stim2toggle;
                ml_mov2toggle = ML_Movie & ml_stim2toggle;

                ml_numargs = length(varargin);
                if mod(ml_numargs, 2), error('ToggleObject requires all arguments beyond the first to come in parameter/value pairs'); end
                ml_status_specified = false;
                for ml_ = 1:2:ml_numargs
                    ml_v = varargin{ml_};
                    ml_a = varargin{ml_+1};
                    switch lower(ml_v)
                        case 'eventmarker'
                            if ~isnumeric(ml_a), error('Value for <Toggleobject: EventMarker> must be numeric'); end
                            ML_eventcode = ml_a(:);
                        case 'status'
                            if ischar(ml_a), TaskObject.Status(ml_stim2toggle) = strcmpi(ml_a,'on'); else TaskObject.Status(ml_stim2toggle) = logical(ml_a); end
                            ml_status_specified = true;
                        case 'moviestartframe'
                            if ~isnumeric(ml_a), error('Value for <Toggleobject: MovieStartFrame> must be numeric'); end
                            if any(ml_a<1), error('Value for <Toggleobject: MovieStartFrame> must be equal to or greater than 1'); end
                            if 1~=length(ml_a) && length(stimuli)~=length(ml_a), error('Number of values for <ToggleObject: MovieStartFrame> must be equal to the number of specified stimuli, or scalar'); end
                            ML_Movie_StartFrame(ml_mov2toggle) = ml_a;
                            ML_Movie_FrameStep(ml_mov2toggle & 0==ML_Movie_FrameStep) = 1;
                            ML_Movie_FrameByFrame(ml_mov2toggle) = true;
                            mglsetproperty(TaskObject.ID(ml_mov2toggle),'framebyframe',true);
                        case 'moviestep'
                            if ~isnumeric(ml_a), error('Value for <Toggleobject: MovieStep> must be numeric'); end
                            if 1~=length(ml_a) && length(stimuli)~=length(ml_a), error('Number of values for <ToggleObject: MovieStep> must be equal to the number of specified stimuli, or scalar'); end
                            ML_Movie_FrameStep(ml_mov2toggle) = ml_a;
                            ML_Movie_FrameByFrame(ml_mov2toggle) = true;
                            mglsetproperty(TaskObject.ID(ml_mov2toggle),'framebyframe',true);
                        case 'startposition'
                            if ~isnumeric(ml_a), error('Value for <Toggleobject: StartPosition> must be numeric'); end
                            if any(ml_a<1), error('Value for <Toggleobject: StartPosition> must be equal to or greater than 1'); end
                            if 1~=length(ml_a) && length(stimuli)~=length(ml_a), error('Number of values for <ToggleObject: StartPosition> must be equal to the number of specified stimuli, or scalar'); end
                            ML_Visual_StartPosition(ml_vis2toggle) = ml_a;
                            ML_Visual_PositionStep(ml_vis2toggle & 0==ML_Visual_PositionStep) = 1;
                        case 'positionstep'
                            if ~isnumeric(ml_a), error('Value for <Toggleobject: PositionStep> must be numeric'); end
                            if 1~=length(ml_a) && length(stimuli)~=length(ml_a), error('Number of values for <ToggleObject: PositionStep> must be equal to the number of specified stimuli, or scalar'); end
                            ML_Visual_PositionStep(ml_vis2toggle) = ml_a;
                        otherwise
                            error('Unrecognized option "%s" calling ToggleObject', ml_v);
                    end
                end
                if ~ml_status_specified, TaskObject.Status(ml_stim2toggle) = ~TaskObject.Status(ml_stim2toggle); end
                ml_ = ml_mov2toggle & 1==ML_Movie_StartFrame & ML_Movie_FrameStep < 0;
                if any(ml_), ML_Movie_StartFrame(ml_) = ML_Movie_nFrame(ml_); end
                ml_ = ml_vis2toggle & 1==ML_Visual_StartPosition & ML_Visual_PositionStep < 0;
                if any(ml_), ML_Visual_StartPosition(ml_) = ML_Visual_nPosition(ml_); end

                % set up stimuli
                ml_new_on = ~ml_old_status & TaskObject.Status;
                ml_new_off = ml_old_status & ~TaskObject.Status;
                ML_CurrentFrameNumber = floor(trialtime()/ML_FrameLength);

                ml_new_on_visual = ml_new_on & ML_Visual;
                if any(ml_new_on_visual)
                    ML_GraphicsUsedInThisTrial = ML_GraphicsUsedInThisTrial | ml_new_on_visual;
                    ML_scene_updated = true;
                    ML_Visual_InitialFrame(ml_new_on_visual) = ML_CurrentFrameNumber;
                    mglactivategraphic(TaskObject.ID(ml_new_on_visual),true);
                end
                ml_new_off_visual = ml_new_off & ML_Visual;
                if any(ml_new_off_visual)
                    ML_scene_updated = ML_scene_updated | any(~isnan(ML_Visual_InitialFrame(ml_new_off_visual)));
                    ML_Visual_InitialFrame(ml_new_off_visual) = NaN;
                    mglactivategraphic(TaskObject.ID(ml_new_off_visual),false);
                end
                
                ml_new_on_sound = ml_new_on & ML_Sound;
                if any(ml_new_on_sound), mglactivatesound(TaskObject.ID(ml_new_on_sound),true); end
                ml_new_off_sound = ml_new_off & ML_Sound;
                if any(ml_new_off_sound), ml_id = TaskObject.ID(ml_new_off_sound); mglstopsound(ml_id); mglactivatesound(ml_id,false); end
                 
                ml_new_on_STM = ML_IO_Channel(ml_new_on & ML_Stimulation);
                if ~isempty(ml_new_on_STM)
                    mglactivategraphic(Screen.Stimulation(:,ml_new_on_STM),true);
                    ml_device = [DAQ.Stimulation{ml_new_on_STM}];
                    if ~isempty(ml_device), register(ml_device); end
                end
                ml_new_off_STM = ML_IO_Channel(ml_new_off & ML_Stimulation);
                if ~isempty(ml_new_off_STM)
                    ml_device = [DAQ.Stimulation{ml_new_off_STM}];
                    if ~isempty(ml_device), stop(ml_device); end
                end
                
                ml_new_on_TTL = ML_IO_Channel(ml_new_on & ML_TTL);
                if ~isempty(ml_new_on_TTL)
                    mglactivategraphic(Screen.TTL(:,ml_new_on_TTL),true);
                    ml_device = [DAQ.TTL{ml_new_on_TTL}];
                    if ~isempty(ml_device), register(ml_device,'TTL'); end
                end
                ml_new_off_TTL = ML_IO_Channel(ml_new_off & ML_TTL);
                if ~isempty(ml_new_off_TTL)
                    ml_device = [DAQ.TTL{ml_new_off_TTL}];
                    if ~isempty(ml_device), putvalue(ml_device,0); end
                end
            end
            if ML_forced_new_scene, ml_new_scene = true; ML_forced_new_scene = false; end
            
            ml_elapsed_frame = ML_CurrentFrameNumber - ML_Visual_InitialFrame;

            % visual stimuli position change
            ml_position_update = TaskObject.Status & 0 < ML_Visual_nPosition;
            if any(ml_position_update)
                ml_position_index = mod(ML_Visual_StartPosition-1 + sign(ML_Visual_PositionStep) .* floor(ml_elapsed_frame .* abs(ML_Visual_PositionStep)),ML_Visual_nPosition) + 1;

                ML_scene_updated = true;
                for ml_=find(ml_position_update), TaskObject.Position(ml_,:) = ML_Visual_PositionArray{ml_}(ml_position_index(ml_),:); end
                mglsetorigin(TaskObject.ID(ml_position_update),TaskObject.ScreenPosition(ml_position_update,:));
            end
            
            % movie update
            ml_movie_update = TaskObject.Status & ML_Movie;
            if any(ml_movie_update)
                ml_frame_update = ml_movie_update & ML_Movie_FrameByFrame;
                if any(ml_frame_update)
                    ml_frame_index = mod(ML_Movie_StartFrame-1 + sign(ML_Movie_FrameStep) .* floor(ml_elapsed_frame .* abs(ML_Movie_FrameStep)),ML_Movie_nFrame) + 1;

                    ml_frame_order = find(ml_frame_update & 0 < ML_Movie_nFrameOrder);
                    if ~isempty(ml_frame_order)
                        for ml_=ml_frame_order
                            if ml_frame_index(ml_) < ML_Movie_nFrameOrder(ml_), ml_frame_index(ml_) = ML_Movie_FrameOrderArray{ml_}(ml_frame_index(ml_)); end
                        end
                    end
                    ml_frame_event = find(ml_frame_update & 0 < ML_Movie_nFrameEvent);
                    if ~isempty(ml_frame_event)
                        for ml_=ml_frame_event
                            ml_idx = ML_Movie_FrameEventArray{ml_}(:,1)==ml_frame_index(ml_);
                            if any(ml_idx), ML_eventcode = [ML_eventcode; ML_Movie_FrameEventArray{ml_}(ml_idx,2)]; end %#ok<AGROW>
                        end
                    end
                    
                    ML_scene_updated = true;
                    for m=find(ml_frame_update), mglsetproperty(TaskObject.ID(m),'setnextframe',ml_frame_index(m)); end
                end
                
                non_framebyframe = ml_movie_update & ~ML_Movie_FrameByFrame;
                if any(non_framebyframe)
                    ML_scene_updated = ML_scene_updated | any(~isnan(ML_Visual_InitialFrame(non_framebyframe)));
                    ML_Visual_InitialFrame(non_framebyframe & ML_Movie_DurationInRefreshCounts<ml_elapsed_frame) = NaN;
                end
            end
            
            % photodiode
            if ML_scene_updated && 1 < MLConfig.PhotoDiodeTrigger
                ML_PdStatus = ~ML_PdStatus;
                mglactivategraphic([Screen.PhotodiodeWhite Screen.PhotodiodeBlack],[ML_PdStatus ~ML_PdStatus]);
            end
            ML_TimeFromLastPresent(4) = trialtime;
            
            % render screen
            if ML_scene_updated || ML_ShowJoyCursor
                mglrendergraphic(ML_CurrentFrameNumber,1);
                if ML_WarmingUp, mglclearscreen(1); ML_eventcode = []; end
            end
            ML_TimeFromLastPresent(5) = trialtime;

            ML_RenderingState = 1;
            if ~ml_new_scene, return, end
        end
                
        if 1==ML_RenderingState
            mglrendergraphic(ML_CurrentFrameNumber,2);
            if ML_WarmingUp, mglclearscreen(2); end
            ML_TimeFromLastPresent(6) = trialtime;

            ML_RenderingState = 2;
            if ~ml_new_scene, return, end
        end

        if 2==ML_RenderingState
            if ml_new_scene
                ml_tflip = mdqmex(97,ML_scene_updated|ML_ShowJoyCursor,ML_eventcode);
                ML_LastPresentTime = ml_tflip;
                ML_RenderingState = 3;
            else
                if ML_scene_updated || ML_ShowJoyCursor
                    ML_TimeFromLastPresent(8) = trialtime;
                    ml_vsync = (ML_TimeFromLastPresent(8)-ML_LastPresentTime) < ML_FrameLength;
                    ml_tflip = mdqmex(97,true,ML_eventcode,ml_vsync,false);
                    ml_frame_count = round((ml_tflip - ML_LastPresentTime) / ML_FrameLength);
                    if ML_scene_updated && 0<ML_LastPresentTime && ~ML_WarmingUp
                        ML_TimeFromLastPresent(9) = ml_tflip;
                        ml_skipped = ml_frame_count - 1;
                        if 0 < ml_skipped
                            ml_skippedframetimeinfo = [ML_TimeFromLastPresent ML_SampleCycleStage ML_SampleCycleTime ML_CurrentFrameNumber];
                            ml_nskippedframetimeinfo = length(ml_skippedframetimeinfo);
                            ML_SkippedFrameTimeInfo(end+1,ml_nskippedframetimeinfo) = 0;
                            ML_SkippedFrameTimeInfo(end,1:ml_nskippedframetimeinfo) = ml_skippedframetimeinfo;
                            eventmarker(13);
                            ML_TotalSkippedFrames = ML_TotalSkippedFrames + ml_skipped;
                            ML_CurrentFrameNumber = NaN;
                            user_warning('%d skipped frame(s) at %.0f ms. (Total %d skipped)', ml_skipped, ML_LastPresentTime, ML_TotalSkippedFrames);
                        end
                    end
                    if ml_vsync, ML_LastPresentTime = ml_tflip; else ML_LastPresentTime = ML_LastPresentTime + ml_frame_count * ML_FrameLength; end
                    ML_RenderingState = 3;
                else
                    ml_next_flip_time = ML_LastPresentTime + ML_FrameLength;
                    if ml_next_flip_time < trialtime
                        ML_LastPresentTime = ml_next_flip_time;
                        ML_RenderingState = 3;
                    end
                end
                return
            end
        end
        
        if 3==ML_RenderingState
            mglpresent(2,MLConfig.RunMessageLoop,SIMULATION_MODE);
            if isnan(ML_CurrentFrameNumber)
                ML_CurrentFrameNumber = floor(trialtime()/ML_FrameLength);
            else
                ML_CurrentFrameNumber = ML_CurrentFrameNumber + 1;
            end
            
            % update ObjectStatusRecord (used to play back trials from BHV file)
            if ml_new_scene && ML_ToggleCount < ML_MaxObjectStatusRecord
                ML_ToggleCount = ML_ToggleCount + 1;
                ML_ObjectStatusRecord.Time(ML_ToggleCount) = ML_LastPresentTime;
                ML_ObjectStatusRecord.Status(ML_ToggleCount,:) = TaskObject.Status;
                ML_ObjectStatusRecord.Position{ML_ToggleCount} = TaskObject.Position;
                ML_ObjectStatusRecord.BackgroundColor(ML_ToggleCount,:) = ML_BackgroundColor;
                if any(ml_position_update)
                    ML_ObjectStatusRecord.Info(ML_ToggleCount).Position = ML_Visual_PositionArray;
                    ML_ObjectStatusRecord.Info(ML_ToggleCount).StartPosition = ML_Visual_StartPosition;
                    ML_ObjectStatusRecord.Info(ML_ToggleCount).PositionStep = ML_Visual_PositionStep;
                end
                if any(ml_frame_update)
                    ML_ObjectStatusRecord.Info(ML_ToggleCount).MovieStartFrame = ML_Movie_StartFrame;
                    ML_ObjectStatusRecord.Info(ML_ToggleCount).MovieFrameStep = ML_Movie_FrameStep;
                    ML_ObjectStatusRecord.Info(ML_ToggleCount).MovieFrameOrder = ML_Movie_FrameOrderArray;
                end
                if any(non_framebyframe)
                    ML_ObjectStatusRecord.Info(ML_ToggleCount).MovieStartTime = ML_Movie_StartTime;
                end
            end
            
            ML_RenderingState = 0;
        end
    end

    %% function eyejoytrack
    ML_TotalTrackingTime = 0;
    ML_MaxCycleTime = 0;
    ML_TotalAcquiredSamples = 0;
    ML_MaxEyeTargetIndex = 1000;
    ML_EyeTargetRecord = zeros(ML_MaxEyeTargetIndex,4);
    ML_EyeTargetIndex = 0;
    function [ml_ontarget, ml_rt, ml_trialtime] = eyejoytrack(varargin)
        ml_starttime = trialtime;
        ml_ontarget = 0;
        ml_rt = NaN;
        ml_trialtime = NaN;
        ML_TimeFromLastPresent(1) = ML_LastPresentTime;
        ML_TimeFromLastPresent(2) = ml_starttime;

        % bhvanalyzer{:,1} = function name
        % bhvanalyzer{:,2} = target stimuli/buttons
        % bhvanalyzer{:,3} = fixation threshold in visual angles (or button threshold in voltages)
        % bhvanalyzer{:,4} = target position in pixels
        % bhvanalyzer{:,5} = fixation threshold in pixels (or target button index)
        % bhvanalyzer{:,6} = ID of fixation window graphics
        % bhvanalyzer{:,7} = fixation status

        % check input arguments
        if strcmp(varargin{1}, 'idle')
            ml_bhvanalyzer = [];
            ml_nbhvanalyzer = 0;
            ml_maxtime = varargin{2};
        else
            ml_nbhvanalyzer = floor(nargin/3);
            ml_bhvanalyzer = cell(ml_nbhvanalyzer,7);
            ml_bhvanalyzer(:,1:3) = reshape(varargin(1:end-1),3,ml_nbhvanalyzer)';
            ml_bhvanalyzer(:,1) = lower(ml_bhvanalyzer(:,1));
            ml_maxtime = varargin{end};
        end

        for ml_=1:ml_nbhvanalyzer
            % signal type
            if ~ML_WarmingUp
                switch ml_bhvanalyzer{ml_,1}
                    case {'acquirefix','holdfix'}, if ~ML_eyepresent, error('*** No eye-signal input defined in I/O menu ***'); end
                    case {'acquiretarget','holdtarget'}, if ~ML_joypresent && ~ML_usbjoypresent, error('*** No joystick defined in I/O menu ***'); end
                    case {'acquiretouch','holdtouch'}, if ~ML_buttonpresent, error('*** No button defined in I/O menu ***'); end
                    case {'touchtarget','releasetarget'}  % do nothing. Mouse/touchscreen is always available.
                    otherwise, error('Undefined eyejoytrack function "%s".', ml_bhvanalyzer{ml_,1});
                end
            end
            
            % target type, threshold & stimulus position/button index
            ml_ntargetobj = length(ml_bhvanalyzer{ml_,2});
            ml_nthreshold = numel(ml_bhvanalyzer{ml_,3});
            switch ml_bhvanalyzer{ml_,1}
                case {'acquiretouch','holdtouch'}
                    ml_invalid_button = ~ismember(ml_bhvanalyzer{ml_,2},ML_ButtonsAvailable);
                    if any(ml_invalid_button), error('*** Button #%d is not valid in I/O menu ***',find(ml_invalid_button,1)); end
                    if 0 == ml_nthreshold
                        DAQ.button_threshold(ml_bhvanalyzer{ml_,2},[]);
                    else
                        ml_bhvanalyzer{ml_,3}(end+1:ml_ntargetobj) = ml_bhvanalyzer{ml_,3}(end);
                        DAQ.button_threshold(ml_bhvanalyzer{ml_,2},ml_bhvanalyzer{ml_,3});
                        ml_bhvanalyzer{ml_,5} = zeros(ml_ntargetobj,1);
                        for n=1:ml_ntargetobj, ml_bhvanalyzer{ml_,5}(n) = find(ML_ButtonsAvailable==ml_bhvanalyzer{ml_,2}(n),1); end
                    end
                otherwise
                    ml_nonvisual_obj = ~ML_Visual(ml_bhvanalyzer{ml_,2});
                    if any(ml_nonvisual_obj), error('*** Target #%d is not a visual object ***',find(ml_nonvisual_obj,1)); end
                    if 0 == ml_nthreshold, error('*** The fixation radius is not specified ***'); end
                    ml_bhvanalyzer{ml_,4} = TaskObject.ScreenPosition(ml_bhvanalyzer{ml_,2},:);
                    ml_bhvanalyzer{ml_,6} = NaN(ml_ntargetobj,1);
                    if 1==ml_nthreshold || ml_ntargetobj==ml_nthreshold  % circle window
                        ml_bhvanalyzer{ml_,3}(end+1:ml_ntargetobj) = ml_bhvanalyzer{ml_,3}(end);
                        ml_bhvanalyzer{ml_,3} = ml_bhvanalyzer{ml_,3}(:);
                        ml_bhvanalyzer{ml_,5} = ml_bhvanalyzer{ml_,3} * ML_PixelsPerDegree;
                        for n=1:ml_ntargetobj, ml_bhvanalyzer{ml_,6}(n) = mgladdcircle([0 255 0], ml_bhvanalyzer{ml_,5}(n) .* [2 2], 10); end
                    else  % rect window
                        if 2==ml_nthreshold, ml_bhvanalyzer{ml_,3} = repmat(ml_bhvanalyzer{ml_,3},ml_ntargetobj,1); end
                        ml_bhvanalyzer{ml_,5} = ml_bhvanalyzer{ml_,3} * ML_PixelsPerDegree;
                        for n=1:ml_ntargetobj, ml_bhvanalyzer{ml_,6}(n) = mgladdbox([0 255 0], ml_bhvanalyzer{ml_,5}(n,:), 10); end
                        ml_bhvanalyzer{ml_,5} = [ml_bhvanalyzer{ml_,4} - ml_bhvanalyzer{ml_,5}/2 ml_bhvanalyzer{ml_,4} + ml_bhvanalyzer{ml_,5}/2]; 
                    end
                    mglsetorigin(ml_bhvanalyzer{ml_,6},ml_bhvanalyzer{ml_,4});
            end
        end

        ml_nstep = 3 + ml_nbhvanalyzer;
        ml_earlybreak = false;
        ml_sampletime = Inf;
        ml_stage_start_time = trialtime;
        ML_SampleCycleTime = zeros(1,ml_nstep + 1);
        ML_SampleCycleTime(2) = ml_stage_start_time - ml_starttime;
        ML_SampleCycleTime(end) = MLConfig.VsyncSpinlock;
        ML_TimeFromLastPresent(3) = ml_stage_start_time;
        
        ml_analyzed = false;
        while trialtime - ml_starttime < ml_maxtime
            for ML_SampleCycleStage=1:ml_nstep
                if 2~=ML_RenderingState, toggleobject(0); end
                ML_SampleCycleTime(ML_SampleCycleStage) = trialtime - ml_stage_start_time;
                if 2==ML_RenderingState
                    ml_time_to_next_flip = ML_FrameLength - (trialtime - ML_LastPresentTime);
                    if ml_time_to_next_flip < max(ML_SampleCycleTime)
                        ML_TimeFromLastPresent(7) = trialtime;
                        ml_tflip = toggleobject(0);
                        if ML_Benchmark && ~isempty(ml_tflip), ML_BenchmarkFrameCount = ML_BenchmarkFrameCount + 1; ML_BenchmarkFrame(ML_BenchmarkFrameCount,2) = ml_tflip; end
                    end
                end
                ml_stage_start_time = trialtime;

                switch ML_SampleCycleStage
                    case 1  % read samples
                        ML_TotalAcquiredSamples = ML_TotalAcquiredSamples + 1;
                        ML_MaxCycleTime = max(ML_MaxCycleTime, trialtime - ml_sampletime);
                        ml_sampletime = trialtime;
                        if SIMULATION_MODE, DAQ.simulated_input(0); [ml_mouse,ml_mousebutton] = getsample(ML_Mouse); else getsample(DAQ); end
                        if ML_Benchmark, ML_BenchmarkSampleCount = ML_BenchmarkSampleCount + 1; ML_BenchmarkSample(ML_BenchmarkSampleCount,1) = ml_sampletime; end
                        ml_kb = kbdgetkey;
                        if ~isempty(ml_kb), hotkey(ml_kb); end
           
                    case 2
                        ml_eye = []; ml_joy = []; ml_button = []; ml_touch = [];
                        if SIMULATION_MODE
                            ml_eye = EyeCal.control2pix(ml_mouse);
                            ml_joy = JoyCal.deg2pix(DAQ.SimulatedJoystick);
                            ml_button = DAQ.SimulatedButton;
                            if any(ml_mousebutton), ml_touch = ml_eye; end
                        else
                            if ML_eyepresent, ml_eye = EyeCal.sig2pix(DAQ.Eye,ML_EyeOffset); end
                            if ML_joypresent, ml_joy = JoyCal.sig2pix(DAQ.Joystick,ML_JoyOffset); end
                            if ML_buttonpresent, ml_button = DAQ.Button; end
                            if any(DAQ.MouseButton), ml_touch = DAQ.Mouse - Screen.SubjectScreenRect(1:2); end
                        end
                        
                    case 3
                        if ~isempty(ml_eye)
                            if Screen.EyeLineTracer
                                mglsetproperty(Screen.EyeTracer,'addpoint',ml_eye);
                            else
                                mglsetorigin(Screen.EyeTracer,ml_eye);
                            end
                        end
                        if ~isempty(ml_joy)
                            mglsetorigin(Screen.JoystickCursor(1),ml_joy);  % cursor on the subject screen
                            mglsetorigin(Screen.JoystickCursor(2),ml_joy);  % cursor on the control screen
                        end
                        if ~isempty(ml_button)
                            mglactivategraphic(Screen.ButtonPressed(ML_ButtonsAvailable),ml_button(ML_ButtonsAvailable));
                            mglactivategraphic(Screen.ButtonReleased(ML_ButtonsAvailable),~ml_button(ML_ButtonsAvailable));
                        end
                        if ~isempty(ml_touch)
                            mglactivategraphic(Screen.TouchCursor,true);
                            mglsetorigin(Screen.TouchCursor,ml_touch);
                        else
                            mglactivategraphic(Screen.TouchCursor,false);
                        end
                        
                    otherwise  % check behavior
                        ml_ = ML_SampleCycleStage - 3;
                        switch ml_bhvanalyzer{ml_,1}
                            case 'acquiretouch', ml_bhvanalyzer{ml_,7} = ml_button(ml_bhvanalyzer{ml_,5}); ml_hold = 0;
                            case 'holdtouch',    ml_bhvanalyzer{ml_,7} = ml_button(ml_bhvanalyzer{ml_,5}); ml_hold = 1;
                            otherwise
                                switch ml_bhvanalyzer{ml_,1}
                                    case 'acquirefix',    ml_source = ml_eye;   ml_hold = 0;
                                    case 'holdfix',       ml_source = ml_eye;   ml_hold = 1;
                                    case 'acquiretarget', ml_source = ml_joy;   ml_hold = 0;
                                    case 'holdtarget',    ml_source = ml_joy;   ml_hold = 1;
                                    case 'touchtarget',   ml_source = ml_touch; ml_hold = 0;
                                    case 'releasetarget', ml_source = ml_touch; ml_hold = 1;
                                end
                                if ~isempty(ml_source)
                                    if 1==size(ml_bhvanalyzer{ml_,5},2)  % circle window
                                        ml_bhvanalyzer{ml_,7} = sum((ml_bhvanalyzer{ml_,4} - repmat(ml_source,size(ml_bhvanalyzer{ml_,4},1),1)).^2,2) < ml_bhvanalyzer{ml_,5}.^2;
                                    else
                                        ml_rc = ml_bhvanalyzer{ml_,5};  % rect window
                                        ml_bhvanalyzer{ml_,7} = ml_rc(:,1)<ml_source(1) & ml_source(1)<ml_rc(:,3) & ml_rc(:,2)<ml_source(2) & ml_source(2)<ml_rc(:,4);
                                    end
                                end
                        end
                        ml_earlybreak = ml_earlybreak | any(ml_bhvanalyzer{ml_,7} - ml_hold);
                end
            end
            ml_analyzed = true;
            
            if ml_earlybreak, ml_rt = round(ml_sampletime-ml_starttime); ml_trialtime = ml_sampletime; break, end
        end
        if 3==ML_RenderingState, toggleobject(0); end
        
        for ml_=ml_nbhvanalyzer:-1:1
            mgldestroygraphic(ml_bhvanalyzer{ml_,6});
            ml_success = find(ml_bhvanalyzer{ml_,7},1);
            if isempty(ml_success)
                ml_ontarget(ml_) = 0;
                if ~ML_WarmingUp && ~ml_analyzed, user_warning('Duration for eyejoytrack() is too short'); end
            else
                ml_ontarget(ml_) = ml_success;
                if any(strcmp('holdfix',ml_bhvanalyzer{ml_,1})) && ML_EyeTargetIndex < ML_MaxEyeTargetIndex
                    ML_EyeTargetIndex = ML_EyeTargetIndex + 1;
                    ML_EyeTargetRecord(ML_EyeTargetIndex,1:2) = TaskObject.Position(ml_bhvanalyzer{ml_,2},:);
                    ML_EyeTargetRecord(ML_EyeTargetIndex,3:4) = [ml_starttime 0] + ml_maxtime/2;  % use the 2nd half of the holding period
                end
            end
        end

        if ml_earlybreak, ML_TotalTrackingTime = ML_TotalTrackingTime + ml_rt; else ML_TotalTrackingTime = ML_TotalTrackingTime + ml_maxtime; end
    end

    %% function eventmarker
    function eventmarker(code), DAQ.eventmarker(code); end

    %% function goodmonkey
    ML_RewardCount = 0;
    function goodmonkey(duration, varargin)
        ML_RewardCount = ML_RewardCount + DAQ.goodmonkey(duration, varargin{:});
        if ~ML_WarmingUp && (SIMULATION_MODE || DAQ.reward_present)
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
    ML_EyeOffset = [0 0];
    function varargout = eye_position()
        if SIMULATION_MODE
            ml_eye = mouse_position();
        elseif ML_eyepresent
            getsample(DAQ);
            ml_eye = EyeCal.sig2deg(DAQ.Eye,ML_EyeOffset);
        else
            ml_eye = [0 0];
        end
        switch nargout
            case 1, varargout{1} = ml_eye;
            case 2, varargout{1} = ml_eye(1); varargout{2} = ml_eye(2);
        end
    end
    
    %% function joystick_position
    ML_JoyOffset = [0 0];
    function varargout = joystick_position(varargin)
        if SIMULATION_MODE
            ml_joy = DAQ.SimulatedJoystick;
        else
            getsample(DAQ);
            ml_joy = JoyCal.sig2deg(DAQ.Joystick,ML_JoyOffset);
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
                case 'eye', ml_data = EyeCal.sig2deg(DAQ.Eye,ML_EyeOffset);
                case 'joy', ml_data = JoyCal.sig2deg(DAQ.Joystick,ML_JoyOffset);
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
        mglsetorigin(TaskObject.ID(stimnum),TaskObject.ScreenPosition(stimnum,:));
        ML_Visual_PositionArray(stimnum) = {[]};
        ML_Visual_StartPosition(stimnum) = 1;
        ML_Visual_PositionStep(stimnum) = 0;
        ML_Visual_nPosition(stimnum) = 0;
        if any(TaskObject.Status(stimnum)), ML_forced_new_scene = true; end
        ml_success = true;
    end

    %% function set_object_path
    function ml_success = set_object_path(stimnum, xydeg, ydeg)
        if ~isscalar(stimnum), error('This function works for one stimulus at a time. Please pass a scalar.'); end
        if ML_nObject < stimnum, error('Stimulus #%d does not exist.',stimnum); end
        if ~ML_Visual(stimnum), error('Stimulus #%d is not a visual stimulus.',stimnum); end

        if 2<nargin, xydeg = [xydeg(:) ydeg(:)]; end
        
        ml_npath = size(xydeg,1);
        if 1 == ml_npath
            reposition_object(stimnum,xydeg,ydeg);
        else
            ML_Visual_PositionArray{stimnum} = xydeg;
            ML_Visual_StartPosition(stimnum) = 1;
            if 0==ML_Visual_PositionStep(stimnum), ML_Visual_PositionStep(stimnum) = 1; end
            ML_Visual_nPosition(stimnum) = ml_npath;
            if any(TaskObject.Status(stimnum)), ML_forced_new_scene = true; end
        end
        ml_success = true;
    end

    %% function set_frame_order
    function ml_success = set_frame_order(stimnum,frameorder)
        if ~isscalar(stimnum), error('This function works for one stimulus at a time. Please pass a scalar.'); end
        if ML_nObject < stimnum, error('Stimulus #%d does not exist.',stimnum); end
        if ~ML_Movie(stimnum), error('Stimulus #%d is not a movie.',stimnum); end
        if ~isnumeric(frameorder), error('FrameOrder must be numeric.'); end
        if any(ML_Movie_nFrame(stimnum) < frameorder), error('FrameOrder is out of range'); end

        if isempty(frameorder)
            ML_Movie_FrameOrderArray{stimnum} = [];
            ML_Movie_nFrameOrder(stimnum) = 0;
        else
            ML_Movie_FrameByFrame(stimnum) = true;
            mglsetproperty(TaskObject.ID(stimnum),'framebyframe',true);
            ML_Movie_FrameOrderArray{stimnum} = frameorder(:);
            ML_Movie_nFrameOrder(stimnum) = numel(frameorder);
            if any(TaskObject.Status(stimnum)), ML_forced_new_scene = true; end
        end
        ml_success = true;
    end
    
    %% function set_frame_event
    function set_frame_event(stimnum,framenum,evcode)
        if ~isscalar(stimnum), error('This function works for one stimulus at a time. Please pass a scalar.'); end
        if ML_nObject < stimnum, error('Stimulus #%d does not exist.',stimnum); end
        if ~ML_Movie(stimnum), error('Stimulus #%d is not a movie.',stimnum); end
        if ~isnumeric(framenum) || ~isnumeric(evcode), error('Frame-triggered event marker arguments must be numeric.'); end
        if numel(framenum) ~= numel(evcode), error('Frame-triggered event marker arguments must be of equal length.'); end

        ML_Movie_FrameEventArray{stimnum} = [framenum(:) evcode(:)];
        ML_Movie_nFrameEvent(stimnum) = numel(framenum);
    end

    %% function idle
    function idle(duration, varargin)
        if ~isempty(varargin)
            ML_BackgroundColor = varargin{1};
            mglsetscreencolor(1,ML_BackgroundColor);
            ML_forced_new_scene = true;
        end
        eyejoytrack('idle', duration);
        if ~isempty(varargin)
            ML_BackgroundColor = MLConfig.SubjectScreenBackground;
            mglsetscreencolor(1,ML_BackgroundColor);
            ML_forced_new_scene = true;
        end
    end
    
    %% function set_iti
    TrialData.InterTrialInterval = MLConfig.InterTrialInterval;
    function set_iti(t), TrialData.InterTrialInterval = t; end

    %% functon showcursor
    mglactivategraphic(Screen.JoystickCursor(1), ML_ShowJoyCursor);
    function showcursor(cflag)
        if ischar(cflag), ML_ShowJoyCursor = strcmpi(cflag, 'on'); else ML_ShowJoyCursor = logical(cflag); end
        mglactivategraphic(Screen.JoystickCursor(1), ML_ShowJoyCursor);
        if SIMULATION_MODE, mglactivategraphic(Screen.JoystickCursor(2), ML_ShowJoyCursor); end
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
        if ~exist('stimnum','var'), stimnum = find(ML_Movie & ~ML_Movie_FrameByFrame); end
        if ~exist('time_in_msec','var'), time_in_msec = 0; end
        nstim = length(stimnum); ntime = length(time_in_msec);
        if ntime < nstim, time_in_msec(ntime+1:nstim) = time_in_msec(ntime); end
        ML_Movie_StartTime(stimnum) = time_in_msec/1000;
        for ml_=stimnum, mglsetproperty(TaskObject.ID(ml_),'seek',ML_Movie_StartTime(ml_)); end
        ml_ = ~isnan(ML_Visual_InitialFrame(stimnum));
        if any(ml_), ML_Visual_InitialFrame(stimnum(ml_)) = floor(trialtime()/ML_FrameLength); ML_forced_new_scene = true; end
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
        for ml_=1:nstim, mglsetproperty(TaskObject.ID(stimnum(ml_)),'seek',time_in_msec(ml_)/1000); end
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
            mglrendergraphic(ML_CurrentFrameNumber,1,true);
            mglpresent(1);
        end
        
        TrialData.BehavioralCodes = struct('CodeTimes',[], 'CodeNumbers',[]);
        TrialData.AnalogData = struct('SampleInterval',[],'Eye',[],'EyeExtra',[],'Joystick',[],'Mouse',[],'PhotoDiode',[]);
        for ml_=1:DAQ.nGeneral, TrialData.AnalogData.General.(sprintf('Gen%d',ml_)) = []; end
        
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
                if ~isempty(DAQ.Eye), TrialData.AnalogData.Eye = EyeCal.sig2deg(DAQ.Eye,ML_EyeOffset); end
                if ~isempty(DAQ.EyeExtra), TrialData.AnalogData.EyeExtra = DAQ.EyeExtra; end
                if ~isempty(DAQ.Joystick), TrialData.AnalogData.Joystick = JoyCal.sig2deg(DAQ.Joystick,ML_JoyOffset); end
                if ~isempty(DAQ.Mouse), TrialData.AnalogData.Mouse = [EyeCal.subject2deg(DAQ.Mouse) DAQ.MouseButton]; end
                if ~isempty(DAQ.PhotoDiode), TrialData.AnalogData.PhotoDiode = DAQ.PhotoDiode; end
                for ml_=DAQ.general_available, TrialData.AnalogData.General.(sprintf('Gen%d',ml_)) = DAQ.General{ml_}; end
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
                if ~isempty(DAQ.Eye), TrialData.AnalogData.Eye = EyeCal.sig2deg(DAQ.Eye(ml_SamplePoint,:),ML_EyeOffset); end
                if ~isempty(DAQ.EyeExtra), TrialData.AnalogData.EyeExtra = DAQ.EyeExtra(ml_SamplePoint,:); end
                if ~isempty(DAQ.Joystick), TrialData.AnalogData.Joystick = JoyCal.sig2deg(DAQ.Joystick(ml_SamplePoint,:),ML_JoyOffset); end
                if ~isempty(DAQ.Mouse), TrialData.AnalogData.Mouse = [EyeCal.subject2deg(DAQ.Mouse(ml_SamplePoint,:)) DAQ.MouseButton(ml_SamplePoint,:)]; end
                if ~isempty(DAQ.PhotoDiode), TrialData.AnalogData.PhotoDiode = DAQ.PhotoDiode(ml_SamplePoint,:); end
                for ml_=DAQ.general_available, TrialData.AnalogData.General.(sprintf('Gen%d',ml_)) = DAQ.General{ml_}(ml_SamplePoint,:); end
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
            mglactivategraphic(TaskObject.ID(ML_Visual),false);
            mglactivategraphic(TaskObject.ID(ML_GraphicsUsedInThisTrial),true);
            mglsetproperty(TaskObject.ID(ML_Movie_FrameByFrame),'setnextframe',1);
        end
        
        % eye drift correction
        ml_id = NaN;
        if 0<MLConfig.EyeAutoDriftCorrection && all(0==ML_EyeOffset) && 0 < ML_EyeTargetIndex && ~isempty(TrialData.AnalogData.Eye)
            ML_EyeTargetRecord = ML_EyeTargetRecord(ml_SampleInterval < ML_EyeTargetRecord(:,4),:);
            ML_EyeTargetRecord(:,3) = ceil(ML_EyeTargetRecord(:,3) ./ ml_SampleInterval);
            ML_EyeTargetRecord(:,4) = ML_EyeTargetRecord(:,3) + floor(ML_EyeTargetRecord(:,4) ./ ml_SampleInterval) - 1;
            ml_npoint = size(ML_EyeTargetRecord,1);
            ml_new_fix_point = zeros(ml_npoint,2);
            for ml_ = 1:ml_npoint
                ml_new_fix_point(ml_,:) = median(TrialData.AnalogData.Eye(ML_EyeTargetRecord(ml_,3):ML_EyeTargetRecord(ml_,4),:),1);
            end
            ML_EyeOffset = mean(ml_new_fix_point - ML_EyeTargetRecord(:,1:2),1) * EyeCal.rotation_rev_t .* (MLConfig.EyeAutoDriftCorrection / 100);

            if MLConfig.SummarySceneDuringITI
                ML_EyeTargetRecord(:,1:2) = EyeCal.deg2pix(ML_EyeTargetRecord(:,1:2));
                ml_new_fix_point = EyeCal.deg2pix(ml_new_fix_point);
                ml_id = NaN(ml_npoint,2);
                ml_size = 0.3 * ML_PixelsPerDegree;
                for ml_ = 1:ml_npoint
                    ml_id(ml_,1) = mgladdcircle([MLConfig.FixationPointColor; MLConfig.FixationPointColor],ml_size,10); mglsetorigin(ml_id(ml_,1),ML_EyeTargetRecord(ml_,1:2));
                    ml_id(ml_,2) = mgladdcircle([MLConfig.EyeTracerColor; MLConfig.EyeTracerColor],ml_size,10); mglsetorigin(ml_id(ml_,2),ml_new_fix_point(ml_,:));
                end
            end
        end
        mglsetscreencolor(2,fi(MLConfig.NonStopRecording,[0 0.4 0.2],[0.25 0.25 0.25]));
        mdqmex(104);  % ClearControlScreenEdge
        mglrendergraphic(ML_CurrentFrameNumber,2,false);
        mglpresent(2);
        mgldestroygraphic([ml_eye_trace ml_joy_trace ml_touch_trace ml_id(:)']);

        % update EyeTransform
        if any(ML_EyeOffset), EyeCal.translate(ML_EyeOffset); end
        
        [TrialData.BehavioralCodes.CodeTimes,TrialData.BehavioralCodes.CodeNumbers] = mdqmex(98);
        TrialData.ReactionTime = rt;
        TrialData.ObjectStatusRecord.Time = ML_ObjectStatusRecord.Time(1:ML_ToggleCount);
        TrialData.ObjectStatusRecord.Status = ML_ObjectStatusRecord.Status(1:ML_ToggleCount,:);
        TrialData.ObjectStatusRecord.Position = ML_ObjectStatusRecord.Position(1:ML_ToggleCount);
        TrialData.ObjectStatusRecord.BackgroundColor = ML_ObjectStatusRecord.BackgroundColor(1:ML_ToggleCount,:);
        TrialData.ObjectStatusRecord.Info = ML_ObjectStatusRecord.Info;
        [TrialData.RewardRecord.StartTimes,TrialData.RewardRecord.EndTimes] = mdqmex(101);
        if 0==ML_TotalTrackingTime, TrialData.CycleRate = [0 0]; else TrialData.CycleRate = [ML_MaxCycleTime round(1000*ML_TotalAcquiredSamples/ML_TotalTrackingTime)]; end
        TrialData.NewEyeTransform = EyeCal.get_transform_matrix();
        TrialData.VariableChanges.EyeOffset = ML_EyeOffset;
        TrialData.VariableChanges.reward_dur = reward_dur;
        TrialData.UserVars.SkippedFrameTimeInfo = ML_SkippedFrameTimeInfo;
        TrialData.TaskObject.FrameByFrameMovie = ML_Movie_FrameByFrame;
        TrialData.TaskObject.CurrentConditionInfo = TrialRecord.CurrentConditionInfo;
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
    hotkey('c', 'ML_prev_eye_position(end+1,:) = eye_position * EyeCal.rotation_rev_t; ML_EyeOffset = ML_EyeOffset + ML_prev_eye_position(end,:);');  % adjust eye offset
    hotkey('u', 'if ~isempty(ML_prev_eye_position), ML_EyeOffset = ML_EyeOffset - ML_prev_eye_position(end,:); ML_prev_eye_position(end,:) = []; end');
end

kbdflush;
rt = NaN;

    function warming_up()
        ML_WarmingUp = true;
        ml_tflip = toggleobject(find(ML_Visual), 'status', 'on'); %#ok<NASGU>
        for ml_ = 1:10
            eyejoytrack('acquirefix',find(ML_Visual),1,20);
            eyejoytrack('acquiretarget',find(ML_Visual),1,20);
            eyejoytrack('acquiretouch',ML_ButtonsAvailable,[],20);
            eyejoytrack('touchtarget',find(ML_Visual),1,20);
            goodmonkey(20,'ML_WarmingUp',ML_WarmingUp,'NumReward',1);
        end
        toggleobject(find(ML_Visual), 'status', 'off');
        mglsetproperty(TaskObject.ID(ML_Movie),'seek',0);
        ML_WarmingUp = false;

        ML_PdStatus = false;
        if 1 < MLConfig.PhotoDiodeTrigger, mglactivategraphic([Screen.PhotodiodeWhite Screen.PhotodiodeBlack],[ML_PdStatus ~ML_PdStatus]); end
        ML_RenderingState = 0;
        ML_CurrentFrameNumber = 0;
        ML_LastPresentTime = 0;
        ML_GraphicsUsedInThisTrial = false(1,ML_nObject);
        ML_TotalSkippedFrames = 0;
        ML_ToggleCount = 0;
        ML_TotalTrackingTime = 0;
        ML_MaxCycleTime = 0;
        ML_TotalAcquiredSamples = 0;
        ML_EyeTargetIndex = 0;
        ML_RewardCount = 0;
    end

if MLConfig.NonStopRecording
    if TrialRecord.CurrentTrialNumber < 2
        start(DAQ);
        warming_up();

        flushmarker(DAQ);
        ML_trialtime_offset = toc(ML_global_timer);
        ML_Clock = clock;
        flushdata(DAQ);
        ML_global_timer_offset = ML_trialtime_offset;
    end
    TrialData.TrialDateTime = ML_Clock;
else
    start(DAQ);
    if TrialRecord.CurrentTrialNumber < 2, warming_up(); end

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
