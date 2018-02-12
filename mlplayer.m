function mlplayer(datafile,varargin)

data = [];
MLConfig = [];
TrialRecord = [];
TaskObject = [];
search_path = struct('manual_path',[],'base_path',[],'no_for_all',false);
DPI_ratio = [];

RefreshInterval = [];
SampleInterval = [];
current_trial = [];
current_frame = 0;
max_sample = 0;
max_frame = [];
playing = false;
stopped = false;

tracer_update = false;
position_id = [];
nonvisual_time = [];
nonvisual_id = [];

% v1 specific
framebyframe = [];
movie_nframe = [];
movie_length = [];

% v2 specific
new_playback_position = false;
current_scene = [];
param = [];
EyeCal = [];
JoyCal = [];
Tracker = [];
scenes = [];
eye_ = [];
joy_ = [];
touch_ = [];
button_ = [];
null_ = [];

hFig = [];
hProgressbar = [];
replica_pos = [];
ControlScreenZoomRange = [5 300];
error_type_color = [0 1 0; 0 1 1; 1 1 0; 0 0 1; 0.5 0.5 0.5; 1 0 1; 1 0 0; .3 .7 .5; .7 .2 .5; .5 .5 1; .75 .75 .5];
error_type = {'Correct','No response','Late response','Break fixation','No fixation','Early response','Incorrect','Lever break','Ignored','Aborted'};

load('mlimagedata.mat','reward_image','sound_triggered','stimulation_triggered','ttl_triggered');

init();

if exist('datafile','var')
    if 3==length(varargin)
        data = datafile;
        MLConfig = varargin{1};
        TrialRecord = varargin{2};
        datafile = varargin{3};
        load_data(0);
    else
        load_data(datafile);
    end
end
if ~isempty(data)
    update_UI();
    if ~playing, render_scene(); end
end

    function t = trialtime()
        t = (current_frame - param.SceneStartFrame) * RefreshInterval;
    end
    function dummy_function(varargin), end

    function render_scene(present)
        if ~exist('present','var'), present = true; end
        
        prev_event = floor(nonvisual_time / RefreshInterval) < current_frame;
        mglactivategraphic(nonvisual_id(~prev_event,:),false);
        mglactivategraphic(nonvisual_id(prev_event,:),true);
        all_visual = 1==TaskObject.Modality | 2==TaskObject.Modality;

        aidata = data(current_trial).AnalogData;
        obj = data(current_trial).ObjectStatusRecord;
        Screen = MLConfig.Screen;
        DAQ = MLConfig.DAQ;

        if tracer_update
            switch MLConfig.EyeTracerShape
                case 'Line', Screen.EyeTracer = mgladdline(MLConfig.EyeTracerColor,50,1,10);
                otherwise, Screen.EyeTracer = load_cursor('',MLConfig.EyeTracerShape,MLConfig.EyeTracerColor,MLConfig.EyeTracerSize,10);
            end
            Screen.JoystickCursor = load_cursor(MLConfig.JoystickCursorImage,MLConfig.JoystickCursorShape,MLConfig.JoystickCursorColor,MLConfig.JoystickCursorSize,10);
            Screen.TouchCursor = load_cursor(MLConfig.TouchCursorImage,MLConfig.TouchCursorShape,MLConfig.TouchCursorColor,MLConfig.TouchCursorSize,10);
            tracer_update = false;
        end
        mglactivategraphic(Screen.EyeTracer,~isempty(aidata.Eye));
        mglactivategraphic(Screen.JoystickCursor,~isempty(aidata.Joystick));
        mglactivategraphic(Screen.TouchCursor,~isempty(aidata.Mouse));
        
        switch data(1).Ver
            case 1
                mglsetproperty(position_id,'text',sprintf('Current position: %.0f ms',round(current_frame * RefreshInterval)));
                last_sample = min(round(current_frame * RefreshInterval / SampleInterval) + 1,max_sample);
                first_sample = min(round(max(0,current_frame-1) * RefreshInterval / SampleInterval) + 1,last_sample);
                nsample = last_sample - first_sample + 1;

                if ~isempty(aidata.Eye)
                    switch MLConfig.EyeTracerShape
                        case 'Line', mglsetproperty(Screen.EyeTracer,'color',MLConfig.EyeTracerColor,'addpoint',repmat(Screen.SubjectScreenHalfSize,nsample,1) + repmat(MLConfig.PixelsPerDegree,nsample,1).*aidata.Eye(first_sample:last_sample,:));
                        otherwise, mglsetorigin(Screen.EyeTracer,Screen.SubjectScreenHalfSize + MLConfig.PixelsPerDegree.*aidata.Eye(last_sample,:));
                    end
                end
                if ~isempty(aidata.Joystick)
                    mglsetorigin(Screen.JoystickCursor,Screen.SubjectScreenHalfSize + MLConfig.PixelsPerDegree.*aidata.Joystick(last_sample,:));
                end
                if ~isempty(aidata.Mouse)
                    touch = aidata.Mouse(last_sample,:);
                    xy = touch(any(touch(3:4)),1:2);
                    if ~isempty(xy)
                        mglactivategraphic(Screen.TouchCursor,true);
                        mglsetorigin(Screen.TouchCursor,Screen.SubjectScreenHalfSize + MLConfig.PixelsPerDegree.*xy);
                    else
                        mglactivategraphic(Screen.TouchCursor,false);
                    end
                end

                frame_no = floor(obj.Time / RefreshInterval);
                prev_frame = frame_no < current_frame;
                last_update = find(prev_frame,1,'last');
                if isempty(last_update)
                    mglsetscreencolor(1,MLConfig.SubjectScreenBackground);
                    mglactivategraphic(TaskObject.ID,false);
                else
                    if isfield(obj,'BackgroundColor'), mglsetscreencolor(1,obj.BackgroundColor(last_update,:)); end

                    status = logical(obj.Status(last_update,:));
                    mglactivategraphic(TaskObject.ID(all_visual),status(all_visual));

                    active_visual = all_visual & status;
                    if any(active_visual)
                        for m=find(active_visual)
                            elapsed_frame = current_frame - frame_no(find(prev_frame & 1==diff([0; obj.Status(:,m)]),1,'last'));
                            elapsed_frame_adjusted = elapsed_frame * RefreshInterval * Screen.RefreshRate / 1000;

                            position = [];
                            frame = [];
                            if isfield(obj,'Info') && ~isempty(obj.Info)
                                info = obj.Info;

                                if isfield(info,'Position') && ~isempty(info(last_update).Position) && ~isempty(info(last_update).Position{m})
                                    startposition = info(last_update).StartPosition(m);
                                    positionstep =  info(last_update).PositionStep(m);
                                    position_index = mod(startposition-1 + sign(positionstep) .* floor(elapsed_frame_adjusted .* abs(positionstep)),size(info(last_update).Position{m},1)) + 1;
                                    position = info(last_update).Position{m}(position_index,:);
                                end

                                if 2==TaskObject.Modality(m)  % if the 'Info' field exists and the stimulus is a movie, either MovieStartFrame or MovieStartTime field must exist.
                                    if framebyframe(m)
                                        startframe = info(last_update).MovieStartFrame(m);
                                        framestep =  info(last_update).MovieFrameStep(m);
                                        frameorder = info(last_update).MovieFrameOrder{m};
                                        frame = mod(startframe-1 + sign(framestep) .* floor(elapsed_frame_adjusted .* abs(framestep)),movie_nframe(m)) + 1;
                                        if ~isempty(frameorder), frame = frameorder(frame); end
                                        mglsetproperty(TaskObject.ID(m),'setnextframe',frame);
                                    else
                                        frame = elapsed_frame * RefreshInterval / 1000 + info(last_update).MovieStartTime(m);
                                        if frame < movie_length(m), mglsetproperty(TaskObject.ID(m),'seek',frame); else mglactivategraphic(TaskObject.ID(m),false); end
                                    end
                                end
                            end

                            if isempty(position), position = obj.Position{last_update}(m,:); end 
                            mglsetorigin(TaskObject.ID(m),Screen.SubjectScreenHalfSize + MLConfig.PixelsPerDegree.*position);
                            if isempty(frame) && 2==TaskObject.Modality(m)
                                frame = elapsed_frame * RefreshInterval / 1000;
                                if frame < movie_length(m), mglsetproperty(TaskObject.ID(m),'seek',frame); else mglactivategraphic(TaskObject.ID(m),false); end
                            end
                        end
                    end
                end
                
				mglsetscreencolor(2,fi(0==current_frame || current_frame==max_frame,[0.25 0.25 0.25],[0.1333 0.3333 0.5490]));
                mglrendergraphic(0);
                
            otherwise  % 2, 2.1
                if isfield(obj,'Time'), Time = obj.Time; else, Time = [obj.SceneParam(:).Time]; end
                frame_no = floor(Time / RefreshInterval);
                prev_frame = frame_no <= current_frame;
                scene_no = find(prev_frame,1,'last'); if isempty(scene_no), scene_no = 0; end
                if scene_no~=current_scene || new_playback_position
                    new_playback_position = false;
                    Tracker.fini(param);
                    if 0<current_scene, scenes{current_scene}.fini(param); end
                    current_scene = scene_no;

                    if 0==current_scene
                        current_frame = 0; set(hProgressbar,'value',current_frame);
                        mglsetscreencolor(1,MLConfig.SubjectScreenBackground);
                        mglactivategraphic(TaskObject.ID,false);
                    else
                        current_frame = frame_no(current_scene); set(hProgressbar,'value',current_frame);
                        param.SceneStartTime = 0;
                        param.SceneStartFrame = current_frame;
                        param.FrameNum = current_frame;
                        param.reset();
                        
                        if iscell(obj.SceneParam)
                            Position = obj.Position{current_scene};
                            BackgroundColor = obj.BackgroundColor(current_scene,:);
                            Visual = obj.SceneParam{current_scene}.Visual;
                            Movie = obj.SceneParam{current_scene}.Movie;
                            nMovie = length(Movie);
                            if isfield(obj,'MovieCurrentPosition'), MovieCurrentPosition = obj.MovieCurrentPosition{current_scene}; else, MovieCurrentPosition = zeros(1,nMovie); end
                            MovieLooping = false(1,nMovie);
                        else
                            Position = obj.SceneParam(current_scene).Position;
                            BackgroundColor = obj.SceneParam(current_scene).BackgroundColor;
                            Visual = obj.SceneParam(current_scene).Visual;
                            Movie = obj.SceneParam(current_scene).Movie;
                            nMovie = length(Movie);
                            MovieCurrentPosition = obj.SceneParam(current_scene).MovieCurrentPosition;
                            MovieLooping = obj.SceneParam(current_scene).MovieLooping;
                        end
                        TaskObject.Position = Position;
                        mglsetscreencolor(1,BackgroundColor);
                        mglactivategraphic(TaskObject.ID(all_visual),false);
                        mglactivategraphic(TaskObject.ID(Visual),true);
                        for m=1:nMovie, mglsetproperty(TaskObject.ID(Movie(m)),'seek',MovieCurrentPosition(m),'looping',MovieLooping(m)); end
                        
                        Tracker.init(param);
                        scenes{current_scene}.init(param);
                    end
                end
                
                mglsetproperty(position_id,'text',sprintf('Current position: %.0f ms, Scene: %d',round(current_frame * RefreshInterval),current_scene));
                last_sample = min(round(current_frame * RefreshInterval / SampleInterval) + 1,max_sample);
                first_sample = min(round(max(0,current_frame-1) * RefreshInterval / SampleInterval) + 1,last_sample);

                if DAQ.eye_present, DAQ.Eye = aidata.Eye(first_sample:last_sample,:); end
                if DAQ.joystick_present, DAQ.Joystick = aidata.Joystick(first_sample:last_sample,:); end
                if DAQ.mouse_present
                    DAQ.Mouse = aidata.Mouse(first_sample:last_sample,1:2);
                    DAQ.MouseButton = logical(aidata.Mouse(first_sample:last_sample,3:4));
                end
                if DAQ.button_present
                    DAQ.Button = cell(1,DAQ.nButton);
                    for m=DAQ.buttons_available()
                        DAQ.Button{m} = aidata.Button.(sprintf('Btn%d',m))(first_sample:last_sample);
                    end
                end
                
                param.FrameNum = current_frame;
                Tracker.acquire(param);
                if 0<current_scene
                    scenes{current_scene}.analyze(param);
                    scenes{current_scene}.draw(param);
                end
                
				mglsetscreencolor(2,fi(0==current_frame || current_frame==max_frame,[0.25 0.25 0.25],[0.1333 0.3333 0.5490]));
                mglrendergraphic(current_frame);
        end
        
        if present, mglpresent(); end
    end

    function export_AVI()
        mglsetcontrolscreenshow(false);
        [n,p] = uiputfile({'*.avi','AVI video (*.avi)'},'Save as');
        if isnumeric(n), mglsetcontrolscreenshow(true); return, end
        filename = [p n];

        err = [];
        wb = [];
        try
            item = get(findobj(hFig,'tag','videosize'),'string');
            val =  get(findobj(hFig,'tag','videosize'),'val');
            resolution = item{val};
            cs = regexp(resolution,'(\d+) x (\d+)','tokens');
            sz = str2double(cs{1}) / DPI_ratio;
            controlscreenposition = get(hFig,'position');
            mglsetcontrolscreenrect(Pos2Rect([controlscreenposition(1:2)-1+replica_pos(1:2) sz]));
            mglsetcontrolscreenzoom(1);
            init_trial(true);
            frame = current_frame;
            mglsetproperty(MLConfig.Screen.EyeTracer,'clear');
            mglactivategraphic(position_id,false);

            current_frame = 0;
            v = VideoWriter(filename);
            set(v,'FrameRate',MLConfig.Screen.RefreshRate);
            open(v);
            set_on_move([]);
            wb = waitbar(current_frame/max_frame,sprintf('%d / %d frames',current_frame,max_frame),'Name',sprintf('Writing %s',[p n]));
            while current_frame <= max_frame
                render_scene(false);
                imdata = mdqmex(44,2);
                writeVideo(v,permute(imdata,[2 1 3]));
                waitbar(current_frame/max_frame,wb,sprintf('%3d / %3d frames',current_frame,max_frame));
                current_frame = current_frame + 1;
            end
            close(v);
        catch e
            err = e;
        end
        if ~isempty(wb), close(wb); end
        set_on_move();
        
        mglsetcontrolscreenrect(Pos2Rect([controlscreenposition(1:2)-1 0 0]+replica_pos));
        mglsetcontrolscreenzoom(MLConfig.ControlScreenZoom/100);
        init_trial();
        current_frame = frame;
        mglsetproperty(MLConfig.Screen.EyeTracer,'clear');
        mglactivategraphic(position_id,true);
        render_scene();
        
        mglsetcontrolscreenshow(true);
        if ~isempty(err), rethrow(err); end
    end

    function init_trial(export) %#ok<INUSD>
        playing = false;
        if exist('export','var')
            device = 11;
            screen_ratio = MLConfig.Screen.Xsize / replica_pos(3);
            screen_width = MLConfig.Screen.Xsize / screen_ratio;
        else
            device = 12;
            screen_ratio = DPI_ratio;
            screen_width = replica_pos(3);
        end
        
        obj = data(current_trial).ObjectStatusRecord;
        mglsetproperty(MLConfig.Screen.EyeTracer,'clear');
        nsample = [floor(data(current_trial).BehavioralCodes.CodeTimes(end)/SampleInterval) size(data(current_trial).AnalogData.Eye,1) size(data(current_trial).AnalogData.Joystick,1) size(data(current_trial).AnalogData.Mouse,1)];
        max_sample = min(nsample(0<nsample));
        max_frame = floor(max_sample * SampleInterval / RefreshInterval) + 1;
        current_frame = 0;
        set(hProgressbar,'min',0,'max',max_frame,'value',current_frame);

        if 1 < data(1).Ver
            if 0<current_scene, scenes{current_scene}.fini(param); end  % fini before recreating TaskObject
        end
        
        % rebuild TrialRecord
        block = [data(1:current_trial).Block];
        trialrecord.CurrentTrialNumber = data(current_trial).Trial;
        trialrecord.CurrentTrialWithinBlock = data(current_trial).TrialWithinBlock;
        trialrecord.CurrentCondition = data(current_trial).Condition;
        trialrecord.CurrentBlock = data(current_trial).Block;
        trialrecord.CurrentBlockCount = sum(diff([0 block]));
        if isfield(data(current_trial).TaskObject,'CurrentConditionInfo'), trialrecord.CurrentConditionInfo = data(current_trial).TaskObject.CurrentConditionInfo; else trialrecord.CurrentConditionInfo = []; end
        trialrecord.ConditionsPlayed = [data(1:current_trial-1).Condition];
        trialrecord.ConditionsThisBlock = [];  % this field is not reconstructable
        trialrecord.BlocksPlayed = [data(1:current_trial-1).Block];
        trialrecord.BlockCount = cumsum(diff([0 block(1:end-1)]));
        trialrecord.BlockOrder = block(0<(diff([0 block])));
        trialrecord.BlocksSelected = [];  % this field is not reconstructable
        trialrecord.TrialErrors = [data(1:current_trial-1).TrialError];
        trialrecord.ReactionTimes = [data(1:current_trial-1).ReactionTime];
        if 1<current_trial
            trialrecord.LastTrialAnalogData = data(current_trial-1).AnalogData;
            trialrecord.LastTrialCodes = data(current_trial-1).BehavioralCodes;
        else
            trialrecord.LastTrialAnalogData = [];
            trialrecord.LastTrialCodes = [];
        end
        
        % create TaskObject
        if isfield(data(current_trial).TaskObject,'Attribute'), taskobj = data(current_trial).TaskObject.Attribute; else taskobj = data(current_trial).TaskObject; end
        if isa(taskobj,'cell') && isa(taskobj{1},'char'), taskobj = {taskobj}; end
        nobj = length(taskobj);
        if ~isempty(TaskObject), delete(TaskObject); end
        TaskObject = mltaskobject_playback(taskobj,MLConfig);
        if isfield(data(current_trial).TaskObject,'Size'), TaskObject.Size = data(current_trial).TaskObject.Size; else TaskObject.Size = 50 * ones(nobj,2); end
        TaskObject.SearchPath = search_path;
        createobj(TaskObject,taskobj,MLConfig,trialrecord);
        search_path = TaskObject.SearchPath;

        nonvisual = [];
        switch data(1).Ver
            case 1
                TaskObject.Position = obj.Position{1};
                status = 1==diff([zeros(1,nobj); obj.Status]);
                for m=1:nobj
                    switch TaskObject.Modality(m)
                        case 3, row = obj.Time(1==status(:,m)); row(:,2) = m; row(:,3) = 3;
                        case 4, row = obj.Time(1==status(:,m)); row(:,2) = m; row(:,3) = 4;
                        case 5, row = obj.Time(1==status(:,m)); row(:,2) = m; row(:,3) = 5;
                        otherwise, row = [];
                    end
                    nonvisual = [nonvisual; row];
                end

                movie = 2==TaskObject.Modality;
                if isfield(data(current_trial).TaskObject,'FrameByFrameMovie'), framebyframe = logical(data(current_trial).TaskObject.FrameByFrameMovie); else framebyframe = false(1,nobj); end
                if any(framebyframe), mglsetproperty(TaskObject.ID(framebyframe),'framebyframe',true); end
                if any(movie)
                    movie_nframe = zeros(1,nobj);
                    movie_length = zeros(1,nobj);
                    for m=find(movie)
                        mov = mglgetproperty(TaskObject.ID(m));
                        movie_nframe(m) = mov.TotalFrames;
                        movie_length(m) = mov.Duration;
                    end
                end
            otherwise  % 2, 2.1
                if isfield(obj,'Position'), TaskObject.Position = obj.Position{1}; else, TaskObject.Position = obj.SceneParam(1).Position; end
                if ~isempty(Tracker), Tracker.fini(param); end
                
                Tracker = TrackerAggregate();
                if MLConfig.DAQ.eye_present, eye_ = EyeTracker(MLConfig,TaskObject,EyeCal,2); Tracker.add(eye_); end
                if MLConfig.DAQ.joystick_present, joy_ = JoyTracker(MLConfig,TaskObject,JoyCal,2); Tracker.add(joy_); end
                if MLConfig.DAQ.mouse_present, touch_ = TouchTracker(MLConfig,TaskObject,EyeCal,2); Tracker.add(touch_); end
                if MLConfig.DAQ.button_present, button_ = ButtonTracker(MLConfig,TaskObject,EyeCal,2); Tracker.add(button_); end
                null_ = NullTracker(MLConfig,TaskObject,EyeCal,2);
                Tracker.init(param);
                tracer_update = false;
                
                current_scene = 0;
                nscene = length(obj.SceneParam);
                scenes = cell(1,nscene);
                for m=1:nscene
                    if iscell(obj.SceneParam)
                        adapter = obj.SceneParam{m}.AdapterList;
                        args = obj.SceneParam{m}.AdapterArgs;
                        t = obj.Time(m);
                        sound = obj.SceneParam{m}.Sound';
                        STM = obj.SceneParam{m}.STM';
                        TTL = obj.SceneParam{m}.TTL';
                    else
                        adapter = obj.SceneParam(m).AdapterList;
                        args = obj.SceneParam(m).AdapterArgs;
                        t = obj.SceneParam(m).Time;
                        sound = obj.SceneParam(m).Sound';
                        STM = obj.SceneParam(m).STM';
                        TTL = obj.SceneParam(m).TTL';
                    end
                    scenes{m} = reconstruct_adapter(adapter,args);
                    
                    if ~isempty(sound), sound = [repmat(t,length(sound),1) sound]; sound(:,3) = 3; end %#ok<*AGROW>
                    if ~isempty(STM), STM = [repmat(t,length(STM),1) STM]; STM(:,3) = 4; end
                    if ~isempty(TTL), TTL = [repmat(t,length(TTL),1) TTL]; TTL(:,3) = 5; end
                    nonvisual = [nonvisual; sound; STM; TTL];
                end
        end
        
        reward = data(current_trial).RewardRecord.StartTimes; reward(:,3) = 0; reward(:,2) = nobj+1;
        nonvisual = [nonvisual; reward];
        [~,idx] = sort(nonvisual(:,1));
        nonvisual = nonvisual(idx,:);
        nonvisual_time = nonvisual(:,1);
        if ~isempty(nonvisual_id), mgldestroygraphic(nonvisual_id); end
        nonvisual_id = NaN(size(nonvisual,1),2);
        for m=1:size(nonvisual,1)
            switch nonvisual(m,3)
                case 0, nonvisual_id(m,1) = mgladdbitmap(mglimresize(reward_image,screen_ratio),device);          % nonvisual_id(m,2) = mgladdtext('Reward',device);
                case 3, nonvisual_id(m,1) = mgladdbitmap(mglimresize(sound_triggered,screen_ratio),device);       nonvisual_id(m,2) = mgladdtext(TaskObject.Label{nonvisual(m,2)},device);
                case 4, nonvisual_id(m,1) = mgladdbitmap(mglimresize(stimulation_triggered,screen_ratio),device); nonvisual_id(m,2) = mgladdtext(TaskObject.Label{nonvisual(m,2)},device);
                case 5, nonvisual_id(m,1) = mgladdbitmap(mglimresize(ttl_triggered,screen_ratio),device);         nonvisual_id(m,2) = mgladdtext(TaskObject.Label{nonvisual(m,2)},device);
            end
            mglsetorigin(nonvisual_id(m,1),[screen_width-25 m*40] * screen_ratio);
            mglsetproperty(nonvisual_id(m,2),'origin',[screen_width-50 m*40] * screen_ratio,'halign',3,'valign',2,'fontsize',12);
        end
    end

    function o = reconstruct_adapter(adapter,args)
        nadapter = length(adapter);
        for m=1:nadapter
            if ~isempty(args{m}) && isa(args{m}{1},'struct')  % adapter aggregator such as AndAdapter, OrAdapter and LBC_ExpManager
                ns = length(args{m});
                s = cell(1,ns);
                for n=1:ns, s{n} = reconstruct_adapter(args{m}{n}.AdapterList,args{m}{n}.AdapterArgs); end
                o = eval([adapter{m} '(s)']);
            else
                switch adapter{m}
                    case 'EyeTracker', if isempty(eye_), error('The datafile does not contain eye data.'); else o = eye_; end
                    case 'JoyTracker', if isempty(joy_), error('The datafile does not contain joystick data.'); else o = joy_; end
                    case 'TouchTracker', if isempty(touch_), error('The datafile does not contain touch data.'); else o = touch_; end
                    case 'ButtonTracker', if isempty(button_), error('The datafile does not contain button data.'); else o = button_; end
                    case 'NullTracker', o = null_;
                    otherwise, o = eval([adapter{m} '(o)']); o.import(args{m});
                end
            end
        end
    end

    function load_data(filename)
        if ~exist('filename','var'), filename = ''; end
        if ischar(filename)
            try
                mglsetcontrolscreenshow(false);
                [data,config,TrialRecord,datafile] = mlread(filename);
                mglsetcontrolscreenshow(true);
            catch
                mglsetcontrolscreenshow(true);
                return
            end
            if ~isempty(MLConfig)
                config = copyfield(config,MLConfig,{'EyeTracerShape','EyeTracerColor','EyeTracerSize', ...
                    'JoystickCursorImage','JoystickCursorShape','JoystickCursorColor','JoystickCursorSize', ...
                    'TouchCursorImage','TouchCursorShape','TouchCursorColor','TouchCursorSize', ...
                    'ControlScreenZoom'});
            end
            MLConfig = config;
        end
        if isempty(data), return; end
        
        current_trial = 1;
        [p,n,e] = fileparts(datafile);
        cd(p);
        set(gcf,'name',['MonkeyLogic Player: ' n e]);
        Trial = [data.Trial];
        nTrial = length(Trial);
        TrialError = [data.TrialError];
        str = cell(nTrial,1);
        for m=1:nTrial
            color = round(error_type_color(TrialError(m)+1,:)*255);
            str{m} = sprintf('<html><font color="rgb(%d,%d,%d)">%d</font></html>',color,Trial(m));
        end
        set(findobj(hFig,'tag','TrialList'),'string',str,'value',current_trial);
        
        search_path.base_path = [];
        search_path.base_path{1} = [fileparts(datafile) filesep];
        p = [fileparts(datafile) filesep 'stimuli' filesep]; if exist(p,'dir'), search_path.base_path{end+1} = p; end
        p = [fileparts(datafile) filesep 'images' filesep];  if exist(p,'dir'), search_path.base_path{end+1} = p; end
        p = [fileparts(mfilename('fullpath')) filesep];      if ~ismember(p,search_path.base_path), search_path.base_path{end+1} = p; end
        if isfield(MLConfig,'MLPath')
            p = MLConfig.MLPath.ExperimentDirectory;         if ~ismember(p,search_path.base_path) && exist(p,'dir'), search_path.base_path{end+1} = p; end
            p = MLConfig.MLPath.BaseDirectory;               if ~ismember(p,search_path.base_path) && exist(p,'dir'), search_path.base_path{end+1} = p; end
        end
        search_path.no_for_all = false;
        
        MLConfig.EyeTracerShape = 'Circle';
        MLConfig.EyeTracerSize = 10;
        MLConfig.ControlScreenZoom = 90;

        MLConfig.FixationPointImage = validate_path(MLConfig.FixationPointImage);
        MLConfig.JoystickCursorImage = validate_path(MLConfig.JoystickCursorImage);
        MLConfig.TouchCursorImage = validate_path(MLConfig.TouchCursorImage);
        MLConfig.DAQ = mldaq_playback(data(current_trial).AnalogData);
        MLConfig.Screen = mlscreen_playback(MLConfig);

        param = RunSceneParam();
        param.Screen = MLConfig.Screen;
        param.DAQ = MLConfig.DAQ;
        param.Mouse = [];
        param.SimulationMode = false;
        param.trialtime = @trialtime;
        param.goodmonkey = @dummy_function;
        param.dashboard = @dummy_function;

        RefreshInterval = MLConfig.Screen.FrameLength;
        SampleInterval = 1000 / MLConfig.AISampleRate;
        mglsetcontrolscreenzoom(MLConfig.ControlScreenZoom/100);
        if isempty(position_id)
            position_id = mgladdtext('Current position:',12);
            mglsetproperty(position_id,'origin',[10 (replica_pos(4)-20) * DPI_ratio],'fontsize',12);
        end
        MLConfig.Screen.create_buttons(MLConfig);

        video_w = [80, 160, 320, 640, 800, 1024] * DPI_ratio;
        video_w(video_w<300|1300<video_w) = [];
        video_h = round(video_w./MLConfig.Screen.SubjectScreenAspectRatio);
        export_size = cell(1,length(video_w));
        for m=1:length(video_w)
            export_size{m} = sprintf('%d x %d',video_w(m),video_h(m));
        end
        set(findobj(hFig,'tag','videosize'),'string',export_size);
        
        EyeCal = mlcalibrate('eye',MLConfig);
        JoyCal = mlcalibrate('joy',MLConfig);
        tracer_update = true;
        init_trial();
    end

    function update_UI()
        set(findobj(hFig,'tag','operatorview1'),'string',num2str(MLConfig.ControlScreenZoom));
        set(findobj(hFig,'tag','operatorview2'),'value',MLConfig.ControlScreenZoom);
        
        MLConfig.EyeTracerShape = set_listbox_value(findobj(hFig,'tag','EyeTracerShape'),MLConfig.EyeTracerShape);
        set_button_color(findobj(hFig,'tag','EyeTracerColor'),MLConfig.EyeTracerColor);
        set(findobj(hFig,'tag','EyeTracerSize'),'string',num2str(MLConfig.EyeTracerSize),'enable',fi(strcmp(MLConfig.EyeTracerShape,'Line'),'off','on'));
        
        set(findobj(hFig,'tag','JoystickCursorImage'),'string',strip_path(MLConfig.JoystickCursorImage,'Select a(n) image/movie'));
        enable = fi(isempty(MLConfig.JoystickCursorImage),'on','off');
        MLConfig.JoystickCursorShape = set_listbox_value(findobj(hFig,'tag','JoystickCursorShape'),MLConfig.JoystickCursorShape,'enable',enable);
        set_button_color(findobj(hFig,'tag','JoystickCursorColor'),MLConfig.JoystickCursorColor,'enable',enable);
        set(findobj(hFig,'tag','JoystickCursorSize'),'string',num2str(MLConfig.JoystickCursorSize),'enable',enable);
        
        set(findobj(hFig,'tag','TouchCursorImage'),'string',strip_path(MLConfig.TouchCursorImage,'Select a(n) image/movie'));
        enable = fi(isempty(MLConfig.TouchCursorImage),'on','off');
        MLConfig.TouchCursorShape = set_listbox_value(findobj(hFig,'tag','TouchCursorShape'),MLConfig.TouchCursorShape,'enable',enable);
        set_button_color(findobj(hFig,'tag','TouchCursorColor'),MLConfig.TouchCursorColor,'enable',enable);
        set(findobj(hFig,'tag','TouchCursorSize'),'string',num2str(MLConfig.TouchCursorSize),'enable',enable);
        set(hProgressbar,'enable','on','value',current_frame);
        set(findobj(hFig,'tag','playbutton'),'enable','on','string',fi(playing,'Stop','Play'),'backgroundcolor',fi(playing,[1 0 0],[0 1 0]));
        
        set(findobj(hFig,'tag','Block'),'string',data(current_trial).Block);
        set(findobj(hFig,'tag','TrialWithinBlock'),'string',data(current_trial).TrialWithinBlock);
        set(findobj(hFig,'tag','Condition'),'string',data(current_trial).Condition);
        TrialError = data(current_trial).TrialError;
        if 0<=TrialError && TrialError<=9
            set(findobj(hFig,'tag','TrialError'),'string',sprintf('%s (%d)',error_type{TrialError+1},TrialError),'backgroundcolor',error_type_color(TrialError+1,:),'foregroundcolor',fi(3==TrialError,[1 1 1],[0 0 0]));
        else
            set(findobj(hFig,'tag','TrialError'),'string',TrialError,'backgroundcolor',[0.9255 0.9137 0.8471],'foregroundcolor',[0 0 0]);
        end
        set(findobj(hFig,'tag','ReactionTime'),'string',round(data(current_trial).ReactionTime));
        time = data(current_trial).BehavioralCodes.CodeTimes;
        if ~isempty(time)
            num = data(current_trial).BehavioralCodes.CodeNumbers;
            if isfield(TrialRecord,'TaskInfo') && isfield(TrialRecord.TaskInfo,'BehavioralCodes')
                [a,b] = ismember(num,TrialRecord.TaskInfo.BehavioralCodes.CodeNumbers);
                codenames = [TrialRecord.TaskInfo.BehavioralCodes.CodeNames; {''}];
                b(~a) = length(codenames);
                code = codenames(b);
            else
                code = cell(length(num),1);
            end
            for m=1:length(num)
                code{m} = sprintf('%.0f [%d] %s',time(m),num(m),code{m});
            end
            set(findobj(hFig,'tag','BehavioralCodes'),'string',code);
        end
        
        set(findobj(hFig,'tag','videosize'),'enable','on');
        set(findobj(hFig,'tag','exportbutton'),'enable','on');
    end

    function UIcallback(hObject,~)
        obj_tag = get(hObject,'tag');
        if isempty(data) && ~strcmp(obj_tag,'loadbutton'), return, end
        switch obj_tag
            case 'operatorview1'
                val = round(str2double(get(gcbo,'string')));
                if ControlScreenZoomRange(1)<=val && val<=ControlScreenZoomRange(2), MLConfig.ControlScreenZoom = val; end
                mglsetcontrolscreenzoom(MLConfig.ControlScreenZoom/100);
            case 'operatorview2'
                val = round(get(gcbo,'value'));
                if ControlScreenZoomRange(1)<=val && val<=ControlScreenZoomRange(2), MLConfig.ControlScreenZoom = val; end
                mglsetcontrolscreenzoom(MLConfig.ControlScreenZoom/100);
            case {'EyeTracerShape','JoystickCursorShape','TouchCursorShape'}
                item = get(gcbo,'string');
                val = item{get(gcbo,'value')};
                if ~strcmp(val,MLConfig.(obj_tag)), MLConfig.(obj_tag) = val; tracer_update = true; end
            case {'EyeTracerColor','JoystickCursorColor','TouchCursorColor'}
                mglsetcontrolscreenshow(false);
                val = uisetcolor(MLConfig.(obj_tag),'Pick up a color');
                if any(val~=MLConfig.(obj_tag)), MLConfig.(obj_tag) = val; tracer_update = true; end
                mglsetcontrolscreenshow(true);
            case {'EyeTracerSize','JoystickCursorSize','TouchCursorSize'}
                val = str2double(get(gcbo,'string'));
                if val~=MLConfig.(obj_tag), MLConfig.(obj_tag) = val; tracer_update = true; end
            case {'JoystickCursorImage','TouchCursorImage'}
                mglsetcontrolscreenshow(false);
                [filename,filepath] = uigetfile({'*.bmp;*.gif;*.jpg;*.jpeg;*.tif;*.tiff;*.png;*.avi;*.mpg;*.mpeg','Image/Movie Files'; '*.*','All Files'},'Select a(n) image/movie file',fileparts(MLConfig.(obj_tag)));
                val = fi(0==filename,'',[filepath filename]);
                if ~strcmp(val,MLConfig.(obj_tag)), MLConfig.(obj_tag) = val; tracer_update = true; end
                mglsetcontrolscreenshow(true);
            case 'TrialList'
                current_trial = get(gcbo,'value');
                stopped = true;
                init_trial();
            case 'progressbar'
                current_frame = round(get(gcbo,'value'));
                mglsetproperty(MLConfig.Screen.EyeTracer,'clear');
                new_playback_position = true;
            case 'playbutton'
                playing = ~playing;
                if playing
                    stopped = false;
                    if current_frame==max_frame, current_frame = 0; end
                    set(gcbo,'string','Stop','backgroundcolor',[1 0 0]); drawnow;
                    while current_frame <= max_frame && playing
                        render_scene();
                        if 0==mod(current_frame,2), set(hProgressbar,'value',current_frame); drawnow; end
                        current_frame = current_frame + 1;
                    end
                    if stopped, return, end
                    current_frame = min(current_frame,max_frame);
                    playing = false;
                else
                    return
                end
            case 'loadbutton', load_data();
            case 'exportbutton', export_AVI();
        end
        if ~isempty(data)
            update_UI();
            render_scene();
        end
    end
        
    function init()
        BaseDirectory = [fileparts(mfilename('fullpath')) filesep];
        addpath(BaseDirectory,[BaseDirectory 'daqtoolbox'],[BaseDirectory 'mgl'],[BaseDirectory 'kbd'],[BaseDirectory 'ext'],[BaseDirectory 'ext' filesep 'playback']);
        
        screensize = get(0,'ScreenSize');
        DPI_ratio = mglgetadapterdisplaymode(1) / screensize(3);

        fw = 970;
        fh = 570;
        dx = 0;

        hFig = findobj('tag','mlplayer');
        if isempty(hFig)
            screen_pos = GetMonitorPosition(mglgetcommandwindowrect);
            if screen_pos(3) < fw, dx = fw - screen_pos(3); fw = fw - dx; end
            h = findobj('tag','mlmainmenu');
            if isempty(h), pos = screen_pos; else pos = get(h,'position'); end
            fx = pos(1) + 0.5 * (pos(3) - fw);
            if fx < screen_pos(1), fx = screen_pos(1) + 8; end
            fy = min(pos(2) + 0.5 * (pos(4) - fh),screen_pos(2) + screen_pos(4) - fh - 30);
            fig_pos = [fx fy fw fh];
        else
            fig_pos = get(hFig,'position');
            close(hFig);
        end
        
        fontsize = 9;
        figure_bgcolor = [.65 .70 .80];
        frame_bgcolor = [0.9255 0.9137 0.8471];
        purple_bgcolor = [.8 .76 .82];
        callbackfunc = @UIcallback;

        hFig = figure;
        set(hFig, 'tag','mlplayer', 'numbertitle','off', 'name','MonkeyLogic Player', 'menubar','none', 'position',fig_pos, 'resize','off', 'color',frame_bgcolor, 'Units','pixel');

        set(hFig,'closerequestfcn',@closeDlg);
        set_on_move();
        
        x = 0; y = fh - 539;
        replica_pos = [x y 720-dx 540];
        set(subplot('position',[0.2 0 0.1 0.1]), 'tag','replica', 'units','pixel', 'position',replica_pos, 'xtick',[], 'ytick',[], 'box','on', 'color',[0 0 0]);
        hProgressbar = uicontrol('style','slider', 'tag','progressbar', 'enable','off', 'min',0, 'max',10, 'sliderstep',[0.005 0.05], 'value',0, 'units','pixel', 'position',[0 0 580-dx 30], 'callback',callbackfunc);        
        uicontrol('style','pushbutton', 'tag','playbutton', 'enable','off', 'units','pixel', 'position',[580-dx 0 70 30], 'string','Play', 'fontsize',fontsize, 'callback',callbackfunc);
        uicontrol('style','pushbutton', 'tag','loadbutton', 'units','pixel', 'position',[650-dx 0 70 30], 'string','Load', 'fontsize',fontsize, 'callback',callbackfunc);
        
        x0 = 720 - dx; y0 = fh - 30; bgcolor = figure_bgcolor;
        uicontrol('style','frame','position',[x0 y0-145 251 176], 'backgroundcolor',bgcolor, 'foregroundcolor',bgcolor);
        uicontrol('style','text', 'units','pixel', 'position',[x0+2 y0 65 22], 'string','Zoom (%)', 'backgroundcolor',bgcolor, 'fontsize',fontsize, 'fontweight','bold', 'horizontalalignment','left');
        uicontrol('style','edit', 'tag','operatorview1', 'units','pixel', 'position',[x0+65 y0+4 37 21], 'fontsize',fontsize, 'callback',callbackfunc);
        uicontrol('style','slider', 'tag','operatorview2', 'min',ControlScreenZoomRange(1), 'max',ControlScreenZoomRange(2), 'sliderstep',[1 10]./(ControlScreenZoomRange(2)-ControlScreenZoomRange(1)), 'value',ControlScreenZoomRange(1), 'units','pixel', 'position',[x0+110 y0+4 135 20], 'fontsize',fontsize, 'callback',callbackfunc);
        
        y0 = y0 - 30;
        uicontrol('style','text', 'position',[x0+2 y0 65 22], 'string','Eye tracer', 'backgroundcolor',bgcolor, 'fontsize',fontsize, 'fontweight','bold', 'horizontalalignment','left');
        uicontrol('style','popupmenu', 'position',[x0+65 y0+3 65 22], 'tag','EyeTracerShape', 'string', {'Line','Circle','Square'}, 'fontsize',fontsize, 'callback',callbackfunc);
        uicontrol('style','pushbutton', 'position',[x0+135 y0+3 55 22], 'tag','EyeTracerColor', 'string','Color', 'fontsize',fontsize, 'callback',callbackfunc);
        uicontrol('style','edit', 'position', [x0+195 y0+3 35 22], 'tag','EyeTracerSize', 'fontsize',fontsize, 'callback',callbackfunc);
        uicontrol('style','text', 'position',[x0+230 y0 20 22], 'string','px', 'backgroundcolor',bgcolor, 'fontsize',fontsize);
        
        y0 = y0 - 30;
        uicontrol('style','text', 'position',[x0+2 y0+3 65 18], 'string','Joystick', 'backgroundcolor',bgcolor, 'fontsize',fontsize, 'fontweight','bold', 'horizontalalignment','left');
        uicontrol('style','text', 'position',[x0 y0-15 60 18], 'string','cursor', 'backgroundcolor',bgcolor, 'fontsize',fontsize, 'fontweight','bold', 'horizontalalignment','right');
        uicontrol('style','pushbutton', 'position',[x0+65 y0+3 180 22], 'tag','JoystickCursorImage', 'fontsize',fontsize, 'callback',callbackfunc);

        y0 = y0 - 25;
        uicontrol('style','popupmenu', 'position',[x0+65 y0+3 65 22], 'tag','JoystickCursorShape', 'string', {'Circle','Square'}, 'fontsize',fontsize, 'callback',callbackfunc);
        uicontrol('style','pushbutton', 'position',[x0+135 y0+3 55 22], 'tag','JoystickCursorColor', 'string','Color', 'fontsize',fontsize, 'callback',callbackfunc);
        uicontrol('style','edit', 'position',[x0+195 y0+3 35 22], 'tag','JoystickCursorSize', 'fontsize',fontsize, 'callback',callbackfunc);
        uicontrol('style','text', 'position',[x0+230 y0 20 22], 'string','px', 'backgroundcolor',bgcolor, 'fontsize',fontsize);
        
        y0 = y0 - 30;
        uicontrol('style','text', 'position',[x0+2 y0+3 65 18], 'string','Touch', 'backgroundcolor',bgcolor, 'fontsize',fontsize, 'fontweight','bold', 'horizontalalignment','left');
        uicontrol('style','text', 'position',[x0 y0-15 60 18], 'string','cursor', 'backgroundcolor',bgcolor, 'fontsize',fontsize, 'fontweight','bold', 'horizontalalignment','right');
        uicontrol('style','pushbutton', 'position',[x0+65 y0+3 180 22], 'tag','TouchCursorImage', 'fontsize',fontsize, 'callback',callbackfunc);

        y0 = y0 - 25;
        uicontrol('style','popupmenu', 'position',[x0+65 y0+3 65 22], 'tag','TouchCursorShape', 'string', {'Circle','Square'}, 'fontsize',fontsize, 'callback',callbackfunc);
        uicontrol('style','pushbutton', 'position',[x0+135 y0+3 55 22], 'tag','TouchCursorColor', 'string','Color', 'fontsize',fontsize, 'callback',callbackfunc);
        uicontrol('style','edit', 'position',[x0+195 y0+3 35 22], 'tag','TouchCursorSize', 'fontsize',fontsize, 'callback',callbackfunc);
        uicontrol('style','text', 'position',[x0+230 y0 20 22], 'string','px', 'backgroundcolor',bgcolor, 'fontsize',fontsize);

        y0 = y0 - 10; bgcolor = frame_bgcolor;
        uicontrol('style','text', 'position',[x0+5 y0-22 60 22], 'string','Trial', 'backgroundcolor',bgcolor, 'fontsize',fontsize, 'fontweight','bold');
        uicontrol('style','list', 'position',[x0+5 y0-351 60 333], 'tag','TrialList', 'backgroundcolor',[1 1 1], 'fontsize',fontsize, 'callback',callbackfunc);
        uicontrol('style','text', 'position',[x0+75 y0-22 90 22], 'string','Block:', 'backgroundcolor',bgcolor, 'fontsize',fontsize, 'fontweight','bold', 'horizontalalignment','left');
        uicontrol('style','text', 'position',[x0+165 y0-22 55 22], 'tag','Block', 'backgroundcolor',bgcolor, 'fontsize',fontsize, 'fontweight','bold', 'horizontalalignment','right');
        uicontrol('style','text', 'position',[x0+75 y0-44 100 22], 'string','Trial in block:', 'backgroundcolor',bgcolor, 'fontsize',fontsize, 'fontweight','bold', 'horizontalalignment','left');
        uicontrol('style','text', 'position',[x0+165 y0-44 55 22], 'tag','TrialWithinBlock', 'backgroundcolor',bgcolor, 'fontsize',fontsize, 'fontweight','bold', 'horizontalalignment','right');
        uicontrol('style','text', 'position',[x0+75 y0-66 100 22], 'string','Condition:', 'backgroundcolor',bgcolor, 'fontsize',fontsize, 'fontweight','bold', 'horizontalalignment','left');
        uicontrol('style','text', 'position',[x0+165 y0-66 55 22], 'tag','Condition', 'backgroundcolor',bgcolor, 'fontsize',fontsize, 'fontweight','bold', 'horizontalalignment','right');
        uicontrol('style','text', 'position',[x0+75 y0-88 100 22], 'string','Error type:', 'backgroundcolor',bgcolor, 'fontsize',fontsize, 'fontweight','bold', 'horizontalalignment','left');
        uicontrol('style','text', 'position',[x0+140 y0-84 105 18], 'tag','TrialError', 'backgroundcolor',bgcolor, 'fontsize',fontsize, 'fontweight','bold');
        uicontrol('style','text', 'position',[x0+75 y0-110 100 22], 'string','Reaction time:', 'backgroundcolor',bgcolor, 'fontsize',fontsize, 'fontweight','bold', 'horizontalalignment','left');
        uicontrol('style','text', 'position',[x0+165 y0-110 55 22], 'tag','ReactionTime', 'backgroundcolor',bgcolor, 'fontsize',fontsize, 'fontweight','bold', 'horizontalalignment','right');
        uicontrol('style','text', 'position',[x0+220 y0-110 25 22], 'string','ms', 'backgroundcolor',bgcolor, 'fontsize',fontsize, 'fontweight','bold', 'horizontalalignment','right');
        uicontrol('style','list', 'position',[x0+70 y0-351 175 244], 'tag','BehavioralCodes', 'backgroundcolor',[1 1 1], 'fontsize',fontsize, 'callback',callbackfunc);
        
        bgcolor = purple_bgcolor;
        uicontrol('style','frame','position',[x0 0 251 33], 'backgroundcolor',bgcolor, 'foregroundcolor',bgcolor);
        uicontrol('style','text', 'position',[x0+3 1 140 22], 'string','Export to AVI', 'backgroundcolor',bgcolor, 'fontsize',fontsize, 'fontweight','bold', 'horizontalalignment','left');
        uicontrol('style','popupmenu', 'position',[x0+85 5 95 22], 'tag','videosize', 'enable','off', 'string','800 x 600', 'fontsize',fontsize, 'callback',callbackfunc);
        uicontrol('style','pushbutton', 'tag','exportbutton', 'enable','off', 'units','pixel', 'position',[x0+185 0 65 30], 'string','Export', 'fontsize',fontsize, 'callback',callbackfunc);
    end

    function closeDlg(~,~)
        playing = false;
        stopped = true;
        mgldestroycontrolscreen();
        closereq;
    end

    function set_on_move(func)
        if ~exist('func','var'), func = @on_move; end

        warning('off','MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame');
        jFrame = get(hFig, 'JavaFrame');
        jAxis = jFrame.getAxisComponent;
        if verLessThan('matlab','8.4')
            hAxis = handle(jAxis, 'CallbackProperties');
            set(hAxis,'AncestorMovedCallback',func);
        else
            set(jAxis.getComponent(0),'AncestorMovedCallback',func);
        end
    end

    function on_move(~,~,~)
        controlscreenposition = get(hFig,'position');
        mglsetcontrolscreenrect(Pos2Rect([controlscreenposition(1:2)-1 0 0]+replica_pos));
        drawnow;
    end

    function op = fi(tf,op1,op2)
        if tf, op = op1; else op = op2; end
    end

    function set_button_color(h,color,varargin)
        set(h,'backgroundcolor',color,'foregroundcolor',fi(all(0.45<color&color<0.55),[1 1 1],1-color),varargin{:});
    end

    function str = set_listbox_value(h,item,varargin)
        items = get(h,'string');
        val = find(strcmpi(items,item),1);
        if isempty(val), val = 1; end
        set(h,'value',val,varargin{:});
        str = items{val};
    end

    function filename = strip_path(filepath,replacement)
        filename = '';
        if ~isempty(filepath)
            [~,filename,ext] = fileparts(filepath);
            filename = [filename ext];
        elseif exist('replacement','var')
            filename = replacement;
        end
    end

    function filepath = validate_path(filepath)
        if isempty(filepath), return, end
        if 2==exist(filepath,'file'), return, end
        [~,n,e] = fileparts(filepath);
        p = [search_path.manual_path search_path.base_path];
        for m=1:length(p)
            filepath = [p{m} n e];
            if 2==exist(filepath,'file'), break; else filepath = []; end
        end
        if isempty(filepath) && ~search_path.no_for_all
            mglsetcontrolscreenshow(false);
            options.Interpreter = 'tex';
            options.Default = 'Yes';
            qstring = ['\fontsize{10}Can''t find the file, ''' regexprep([n e],'([\^_\\])','\\$1') '''.' char(10) 'You can keep the stimulus files with the data file or' char(10) 'under the "images" or "stimuli" subdirectory.' char(10) 'Would you like to manually locate it?'];
            button = questdlg(qstring,'Missing stimulus file','Yes','No','No for all',options);
            switch button
                case 'Yes'
                    [n,p] = uigetfile([n e]);
                    if 0~=n, search_path.manual_path{end+1} = p; filepath = [p n]; end
                case 'No for all', search_path.no_for_all = true;
            end
            mglsetcontrolscreenshow(true);
        end
    end

    function dest = copyfield(dest,src,field)
        if isempty(src), src = struct; end
        if isempty(dest), dest = struct; end
        if ~exist('field','var'), field = intersect(fieldnames(dest),fieldnames(src)); end
        for m=1:length(field), dest.(field{m}) = src.(field{m}); end
    end
end
