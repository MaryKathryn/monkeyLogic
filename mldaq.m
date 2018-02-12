classdef mldaq < handle
    properties (Dependent = true)  % input
        Eye
        EyeExtra
        Joystick
        PhotoDiode
        Button
        General
        Mouse
        MouseButton
    end
    properties (SetAccess = protected)  % output
        Stimulation
        TTL
        goodmonkey
        eventmarker
        nSampleFromMarker

        nButton
        nGeneral
        nStimulation
        nTTL
    end
    properties (SetAccess = protected, Hidden = true)
        Reward
        BehavioralCodes
        StrobeBit
        
        LastSamplePosition
        SimulatedJoystick
        SimulatedButton
    end
    properties (Access = protected)
        DAQ         % compact list of DAQ tasks
        Type        % 1:AI, 2:AO, 3:DIO
        Startable   % AI & DI
        Map         % device & channel mapping
        Data        % recently acquired data
        LastAcquisition  % 1:one sample, 2: continuous

        IO          % config variables related to DAQ
        AIOnlineSmoothing
        AIOnlineSmoothingWindow
        StrobeTrigger
    end
    properties (Constant, Hidden = true)
        MLConfigFields = {'AIOnlineSmoothing','AIOnlineSmoothingWindow','StrobeTrigger'};
    end
    
    methods
        function obj = mldaq(MLConfig)
            if exist('MLConfig','var') && isa(MLConfig,'mlconfig'), create(obj,MLConfig); end
        end
        function delete(obj)
            if ~isempty(obj.DAQ), unregister_all(obj); end
            for m=1:length(obj.DAQ), delete(obj.DAQ{m}); end
        end
        
        function val = eye_present(obj), val = 0~=obj.Map.Eye(1); end
        function val = joystick_present(obj), val = 0~=obj.Map.Joystick(1) | 0~=obj.Map.USBJoystick(1); end
        function val = button_present(obj), val = any(0~=obj.Map.Button(:,1)) | 0<obj.nButton(2); end
        function val = mouse_present(obj), val = 0~=obj.Map.Mouse(1); end
        function val = usbjoystick_present(obj), val = 0~=obj.Map.USBJoystick(1); end
        function val = buttons_available(obj), val = [find(0~=obj.Map.Button(:,1))' (1:obj.nButton(2))+obj.nButton(1)]; end
        function val = general_available(obj), val = find(0~=obj.Map.General(:,1))'; end
        function val = ttl_available(obj), val = find(0==cellfun(@isempty,obj.TTL)); end
        function val = stimulation_available(obj), val = find(0==cellfun(@isempty,obj.Stimulation)); end
        function val = reward_present(obj), val = ~strcmp(func2str(obj.goodmonkey),func2str(@obj.dummy_goodmonkey)); end
        function val = strobe_present(obj), val = ~strcmp(func2str(obj.eventmarker),func2str(@obj.dummy_eventmarker)); end
        function val = eyetracker_present(obj), val = 0~=obj.Map.EyeTracker(1); end
        function button_threshold(obj,button,val), if isempty(val), obj.Map.Button(button,3) = obj.Map.Button(button,4); else obj.Map.Button(button,3) = val; end, end
        function [val,val2] = get_device(obj,type)
            switch lower(type)
                case {'eye',1}, if 0~=obj.Map.Eye(1), val = obj.DAQ{obj.Map.Eye(1)}; val2 = obj.Map.Eye(:,2)'; else val = []; val2 = []; end
                case {'joystick',2}, if 0~=obj.Map.Joystick(1), val = obj.DAQ{obj.Map.Joystick(1)}; val2 = obj.Map.Joystick(:,2)'; else val = []; val2 = []; end
                case 'mouse', val2 = []; if 0~=obj.Map.Mouse(1), val = obj.DAQ{obj.Map.Mouse(1)}; else val = []; end
                case 'usbjoystick', val2 = []; if 0~=obj.Map.USBJoystick(1), val = obj.DAQ{obj.Map.USBJoystick(1)}; else val = []; end
                case 'eyetracker', val2 = []; if 0~=obj.Map.EyeTracker(1), val = obj.DAQ{obj.Map.EyeTracker(1)}; else val = []; end
            end
        end
        
        function obj = create(obj,MLConfig,reset)
            if ~exist('reset','var'), reset = false; end
            if isempty(obj.Map)
                obj.nButton = [sum(strncmpi('Button',MLConfig.IOList(:,1),6)) 0];
                obj.nGeneral = sum(strncmpi('General',MLConfig.IOList(:,1),7));
                obj.nStimulation = sum(strncmpi('Stimulation',MLConfig.IOList(:,1),11));
                obj.nTTL = sum(strncmpi('TTL',MLConfig.IOList(:,1),3));
                init(obj);
            end

            reset = reset | ~isequal(obj.IO,MLConfig.IO) ...
                | xor(MLConfig.Touchscreen,obj.mouse_present()) ...
                | ~strcmpi('None',MLConfig.USBJoystick) ...
                | ~isempty(MLConfig.EyeTracker.ID);
            if ~reset
                try  % quick return after updating non-IO variables
                    stop(obj);
                    update(obj,MLConfig);
                    return
                catch  % try full reset if quick update fails
                    daqreset
                end
            end
            
            init(obj);
            obj.IO = MLConfig.IO;  % store IO as unsorted so that we can compare it with MLConfig's IO
            if ~isempty(MLConfig.IO)
                eye = strncmp({MLConfig.IO.SignalType},'Eye',3);
                if 1==sum(eye), error('Either Eye X or Y is not assigned. They both should be assigned together.'); end
                if 2==length(unique_subsystem(obj,MLConfig.IO(eye))), error('Both Eye X and Y should be on the same DAQ device.'); end
                joy = strncmp({MLConfig.IO.SignalType},'Joystick',8);
                if 1==sum(joy), error('Either Joystick X or Y is not assigned. They both should be assigned together.'); end
                if 2==length(unique_subsystem(obj,MLConfig.IO(joy))), error('Both Joystick X and Y should be on the same DAQ device.'); end

                analog = MLConfig.IO(strcmp({MLConfig.IO.Subsystem},'AnalogInput') | strcmp({MLConfig.IO.Subsystem},'AnalogOutput'));
                if isempty(analog), ia1 = []; ic1 = []; else [~,ia1,ic1] = unique_subsystem(obj,analog); end
                digital = MLConfig.IO(strcmp({MLConfig.IO.Subsystem},'DigitalIO'));
                if isempty(digital)
                    din = []; dout = []; ia2 = []; ic2 = [];
                else
                    dioinfo = cell(length(digital),1);
                    for m=1:length(digital), dioinfo{m} = digital(m).DIOInfo{1,2}; end
                    in = strcmp(dioinfo,'in');
                    din = digital(in); dout = digital(~in);
                    if isempty(din), ia2 = []; ic2 = []; else [~,ia2,ic2] = unique_subsystem(obj,din); end
                end
                if isempty(analog), analog = []; end  % make it sure that all demensions are 0
                if isempty(din), din = []; end
                if isempty(dout), dout = []; end

                IO = [analog; din; dout]; %#ok<*PROPLC> % original list
                daq = [analog(ia1); din(ia2); dout];    % compact list
                map = [ic1; ic2+length(ia1); (1:length(dout))'+length(ia1)+length(ia2)];  % original-to-compact map

                ndaq = length(daq);            
                obj.DAQ = cell(ndaq,1);
                obj.Type = zeros(ndaq,1);
                for m=1:ndaq
                    switch daq(m).Subsystem
                        case 'AnalogInput'
                            obj.DAQ{m} = analoginput(daq(m).Adaptor,daq(m).DevID); %#ok<*TNMLP>
                            obj.DAQ{m}.SamplesPerTrigger = Inf;
                            obj.DAQ{m}.InputType = MLConfig.AIConfiguration;
                            obj.Type(m) = 1;
                            obj.Startable(end+1) = m;
                        case 'AnalogOutput'
                            obj.DAQ{m} = analogoutput(daq(m).Adaptor,daq(m).DevID);
                            obj.DAQ{m}.TriggerType = 'Manual';
                            obj.Type(m) = 2;
                        case 'DigitalIO'
                            obj.DAQ{m} = digitalio(daq(m).Adaptor,daq(m).DevID);
                            obj.Type(m) = 3;
                            if strcmpi(daq(m).DIOInfo{1,2},'in'), obj.Startable(end+1) = m; end
                    end
                end

                for m=1:length(IO)
                    d = map(m);
                    o = obj.DAQ{d};
                    switch IO(m).SignalType
                        case 'Eye X', addchannel(o,IO(m).Channel,'EyeX'); obj.Map.Eye(1,:) = [d length(o.Channel)];
                        case 'Eye Y', addchannel(o,IO(m).Channel,'EyeY'); obj.Map.Eye(2,:) = [d length(o.Channel)];
                        case 'Joystick X', addchannel(o,IO(m).Channel,'JoystickX'); obj.Map.Joystick(1,:) = [d length(o.Channel)];
                        case 'Joystick Y', addchannel(o,IO(m).Channel,'JoystickY'); obj.Map.Joystick(2,:) = [d length(o.Channel)];
                        case 'Reward'
                            obj.Reward = o;
                            switch class(o)
                                case 'analogoutput', addchannel(o,IO(m).Channel,'Reward');
                                case 'digitalio', for n=1:length(IO(m).Channel), addline(o,IO(m).DIOInfo{n,1},IO(m).Channel(n),IO(m).DIOInfo{n,2},'Reward'); end
                            end
                        case 'Behavioral Codes', obj.BehavioralCodes = o; for n=1:length(IO(m).Channel), addline(o,IO(m).DIOInfo{n,1},IO(m).Channel(n),IO(m).DIOInfo{n,2},'BehavioralCodes'); end
                        case 'Strobe Bit', obj.StrobeBit = o; for n=1:length(IO(m).Channel), addline(o,IO(m).DIOInfo{n,1},IO(m).Channel(n),IO(m).DIOInfo{n,2},'StrobeBit'); end
                        case 'PhotoDiode', addchannel(o,IO(m).Channel,'PhotoDiode'); obj.Map.PhotoDiode = [d length(o.Channel)];
                        otherwise
                            n = str2double(regexp(IO(m).SignalType,'\d+','match'));
                            switch IO(m).SignalType(1:3)
                                case 'But'
                                    switch class(o)
                                        case 'analoginput', addchannel(o,IO(m).Channel,sprintf('Button%d',n)); obj.Map.Button(n,:) = [d length(o.Channel) 3 3];
                                        case 'digitalio', addline(o,IO(m).DIOInfo{1},IO(m).Channel,IO(m).DIOInfo{2},sprintf('Button%d',n)); obj.Map.Button(n,:) = [d length(o.Line) 0.5 0.5];
                                    end
                                case 'Gen', addchannel(o,IO(m).Channel,sprintf('General%d',n)); obj.Map.General(n,:) = [d length(o.Channel)];
                                case 'Sti', obj.Stimulation{n} = o; addchannel(o,IO(m).Channel,sprintf('Stimulation%d',n));
                                case 'TTL', obj.TTL{n} = o; addline(o,IO(m).DIOInfo{1},IO(m).Channel,IO(m).DIOInfo{2},sprintf('TTL%d',n));
                            end
                    end
                end
            end
            
            if MLConfig.Touchscreen
                obj.DAQ{end+1,1} = pointingdevice; obj.Type(end+1,1) = 4;
                m = length(obj.DAQ); obj.Startable(end+1) = m; obj.Map.Mouse = m;
            end
            if ~strcmpi('None',MLConfig.USBJoystick)
                obj.DAQ{end+1,1} = pointingdevice('joystick',MLConfig.USBJoystick); obj.Type(end+1,1) = 4;
                m = length(obj.DAQ); obj.Startable(end+1) = m; obj.Map.Joystick = [m 1; m 2]; obj.Map.USBJoystick = m;
                info = daqhwinfo(obj.DAQ{end}); obj.nButton(2) = info.Buttons;
            end
            if ~isempty(MLConfig.EyeTracker.ID)
                eye = eyetracker(MLConfig.EyeTracker.ID);
                switch MLConfig.EyeTracker.ID
                    case 'viewpoint'
                        eye.setting('Port',MLConfig.EyeTracker.ViewPoint.Port);
                        eye.IP_address = MLConfig.EyeTracker.ViewPoint.IP_address;
                        eye.Source = MLConfig.EyeTracker.ViewPoint.Source;
                    case 'eyelink'
                        [width,height] = mglgetadapterdisplaymode(MLConfig.SubjectScreenDevice);
                        eye.setting('ScreenSize',[width height]);
                        eye.setting('Filter',MLConfig.EyeTracker.EyeLink.Filter);
                        eye.setting('PupilSize',MLConfig.EyeTracker.EyeLink.PupilSize);
                        eye.IP_address = MLConfig.EyeTracker.EyeLink.IP_address;
                        eye.Source = MLConfig.EyeTracker.EyeLink.Source;
                    otherwise, error('Unknown TCP/IP eye tracker type!!!');
                end
                obj.DAQ{end+1,1} = eye; obj.Type(end+1,1) = 1;
                m = length(obj.DAQ); obj.Startable(end+1) = m; obj.Map.Eye = [m 1; m 2]; obj.Map.EyeTracker = m;
            end
            
            update(obj,MLConfig);
        end
        
        function val = get.Eye(obj)
            if 0==obj.Map.Eye(1) || isempty(obj.Data{obj.Map.Eye(1),1}), val = []; return, end
            val = obj.Data{obj.Map.Eye(1),1}(:,obj.Map.Eye(:,2));
            if 3==obj.LastAcquisition, obj.LastSamplePosition = obj.nSampleFromMarker(obj.Map.Eye(1)); end
        end
        function val = get.EyeExtra(obj)
            if 0==obj.Map.EyeTracker(1) || isempty(obj.Data{obj.Map.EyeTracker(1),1}), val = []; return, end
            val = obj.Data{obj.Map.EyeTracker(1),1}(:,3:end);
            if 3==obj.LastAcquisition, obj.LastSamplePosition = obj.nSampleFromMarker(obj.Map.EyeTracker(1)); end
        end
        function val = get.Joystick(obj)
            if 0==obj.Map.Joystick(1) || isempty(obj.Data{obj.Map.Joystick(1),1}), val = []; return, end
            if 0==obj.Map.USBJoystick
                val = obj.Data{obj.Map.Joystick(1),1}(:,obj.Map.Joystick(:,2));
            else
                val = obj.Data{obj.Map.Joystick(1),1}(:,obj.Map.Joystick(:,2)) ./ 1000;
            end
            if 3==obj.LastAcquisition, obj.LastSamplePosition = obj.nSampleFromMarker(obj.Map.Joystick(1)); end
        end
        function val = get.PhotoDiode(obj)
            if 0==obj.Map.PhotoDiode(1) || isempty(obj.Data{obj.Map.PhotoDiode(1),1}), val = []; return, end
            val = obj.Data{obj.Map.PhotoDiode(1),1}(:,obj.Map.PhotoDiode(:,2));
            if 3==obj.LastAcquisition, obj.LastSamplePosition = obj.nSampleFromMarker(obj.Map.PhotoDiode(1)); end
        end
        function val = get.Button(obj)
            btn = find(0~=obj.Map.Button(:,1))';
            nbtn = sum(obj.nButton);
            switch obj.LastAcquisition
                case 1
                    val = false(1,obj.nButton(1));
                    for m=btn
                        if isempty(obj.Data{obj.Map.Button(m,1),1}), continue, end
                        val(m) = obj.Map.Button(m,3) < obj.Data{obj.Map.Button(m,1),1}(:,obj.Map.Button(m,2));
                    end
                    if 0~=obj.Map.USBJoystick, val = [val obj.Data{obj.Map.USBJoystick,2}]; end
                case 2
                    val = cell(1,nbtn);
                    for m=btn
                        if isempty(obj.Data{obj.Map.Button(m,1),1}), continue, end
                        val{m} = obj.Map.Button(m,3) < obj.Data{obj.Map.Button(m,1),1}(:,obj.Map.Button(m,2));
                    end
                    if 0==obj.Map.USBJoystick || isempty(obj.Data{obj.Map.USBJoystick,2}), return, end
                    for m=1:obj.nButton(2), val{m+obj.nButton(1)} = obj.Data{obj.Map.USBJoystick,2}(:,m); end
                case 3
                    val = cell(1,nbtn);
                    for m=btn
                        if isempty(obj.Data{obj.Map.Button(m,1),1}), continue, end
                        val{m} = obj.Map.Button(m,3) < obj.Data{obj.Map.Button(m,1),1}(:,obj.Map.Button(m,2));
                    end
                    obj.LastSamplePosition = NaN(1,nbtn); obj.LastSamplePosition(btn) = obj.nSampleFromMarker(obj.Map.Button(btn,1));
                    if 0==obj.Map.USBJoystick || isempty(obj.Data{obj.Map.USBJoystick,2}), return, end
                    for m=1:obj.nButton(2), val{m+obj.nButton(1)} = obj.Data{obj.Map.USBJoystick,2}(:,m); end
                    obj.LastSamplePosition(obj.nButton(1)+1:end) = obj.nSampleFromMarker(obj.Map.USBJoystick);
                otherwise, val = [];
            end
        end
        function val = get.General(obj)
            gen = find(0~=obj.Map.General(:,1))';
            switch obj.LastAcquisition
                case 1
                    val = NaN(1,obj.nGeneral);
                    for m=gen
                        if isempty(obj.Data{obj.Map.General(m,1),1}), continue, end
                        val(m) = obj.Data{obj.Map.General(m,1),1}(:,obj.Map.General(m,2));
                    end
                case 2
                    val = cell(1,obj.nGeneral);
                    for m=gen
                        if isempty(obj.Data{obj.Map.General(m,1),1}), continue, end
                        val{m} = obj.Data{obj.Map.General(m,1),1}(:,obj.Map.General(m,2));
                    end
                case 3
                    val = cell(1,obj.nGeneral);
                    for m=gen
                        if isempty(obj.Data{obj.Map.General(m,1),1}), continue, end
                        val{m} = obj.Data{obj.Map.General(m,1),1}(:,obj.Map.General(m,2));
                    end
                    obj.LastSamplePosition = NaN(1,obj.nGeneral); obj.LastSamplePosition(gen) = obj.nSampleFromMarker(obj.Map.General(gen,1));
                otherwise, val = [];
            end
        end
        function val = get.Mouse(obj)
            if 0==obj.Map.Mouse || isempty(obj.Data{obj.Map.Mouse,1}), val = []; return, end
            val = obj.Data{obj.Map.Mouse,1};
            if 3==obj.LastAcquisition, obj.LastSamplePosition = obj.nSampleFromMarker(obj.Map.Mouse); end
        end
        function val = get.MouseButton(obj)
            if 0==obj.Map.Mouse || isempty(obj.Data{obj.Map.Mouse,2}), val = []; return, end
            val = obj.Data{obj.Map.Mouse,2};
            if 3==obj.LastAcquisition, obj.LastSamplePosition = obj.nSampleFromMarker(obj.Map.Mouse); end
        end
        
        function start(~), mdqmex(94,0); end
        function stop(~), mdqmex(94,1); end
        function flushdata(~), mdqmex(94,2); end
        function flushmarker(~), mdqmex(94,8); end
        function frontmarker(~), mdqmex(94,3); end
        function backmarker(~), mdqmex(94,7); end
        function val = isrunning(~), val = mdqmex(94,4); end
        function val = MinSamplesAvailable(~), val = mdqmex(94,5); end
        function val = MinSamplesAcquired(~), val = mdqmex(94,6); end
        function getsample(obj)
            if isempty(obj.DAQ), return, end
            obj.Data = cell(length(obj.DAQ),2);
            for m=obj.Startable
                switch obj.Type(m)
                    case 1
                        if obj.DAQ{m}.Running
                            switch obj.AIOnlineSmoothing
                                case 1, obj.Data{m,1} = getsample(obj.DAQ{m});
                                case 2, obj.Data{m,1} = mean(peekdata(obj.DAQ{m},min(obj.AIOnlineSmoothingWindow,obj.DAQ{m}.SamplesAvailable)),1);
                                case 3, obj.Data{m,1} = median(peekdata(obj.DAQ{m},min(obj.AIOnlineSmoothingWindow,obj.DAQ{m}.SamplesAvailable)),1);
                            end
                        else
                            obj.Data{m,1} = getsample(obj.DAQ{m});
                        end
                    case 3, obj.Data{m,1} = getvalue(obj.DAQ{m});
                    case 4, [obj.Data{m,1},obj.Data{m,2}] = getsample(obj.DAQ{m});
                end
            end
            obj.LastAcquisition = 1;
        end
        function peekfront(obj)
            obj.Data = cell(length(obj.DAQ),2);
            obj.nSampleFromMarker = NaN(length(obj.IO),1);
            for m=obj.Startable
                switch obj.Type(m)
                    case 1, [obj.Data{m,1},obj.nSampleFromMarker(m)] = peekfront(obj.DAQ{m});
                    case 3, if 0<obj.DAQ{m}.SamplesAvailable, [obj.Data{m,1},obj.nSampleFromMarker(m)] = peekfront(obj.DAQ{m}); end
                    case 4, [obj.Data{m,1},obj.Data{m,2},~,obj.nSampleFromMarker(m)] = peekfront(obj.DAQ{m});
                end
            end
            obj.LastAcquisition = 3;
        end
        function getback(obj)
            obj.Data = cell(length(obj.DAQ),2);
            for m=obj.Startable
                switch obj.Type(m)
                    case 1, obj.Data{m,1} = getback(obj.DAQ{m});
                    case 3, if 0<obj.DAQ{m}.SamplesAvailable, obj.Data{m,1} = getback(obj.DAQ{m}); end
                    case 4, [obj.Data{m,1},obj.Data{m,2}] = getback(obj.DAQ{m});
                end
            end
            obj.LastAcquisition = 2;
        end
        function getdata(obj,varargin)
            obj.Data = cell(length(obj.DAQ),2);
            for m=obj.Startable
                switch obj.Type(m)
                    case 1, obj.Data{m,1} = getdata(obj.DAQ{m},varargin{:});
                    case 3, if 0<obj.DAQ{m}.SamplesAvailable, obj.Data{m,1} = getdata(obj.DAQ{m},varargin{:}); end
                    case 4, [obj.Data{m,1},obj.Data{m,2}] = getdata(obj.DAQ{m},varargin{:});
                end
            end
            obj.LastAcquisition = 2;
        end
        function peekdata(obj,nsample)
            obj.Data = cell(length(obj.DAQ),2);
            for m=obj.Startable
                switch obj.Type(m)
                    case 1, obj.Data{m,1} = peekdata(obj.DAQ{m},nsample);
                    case 3, if 0<obj.DAQ{m}.SamplesAcquired, obj.Data{m,1} = peekdata(obj.DAQ{m},nsample); end
                    case 4, [obj.Data{m,1},obj.Data{m,2}] = peekdata(obj.DAQ{m},nsample);
                end
            end
            obj.LastAcquisition = 2;
        end
    end
    
    methods (Hidden = true)
        function unregister_all(~), mdqmex(91,0); mdqmex(91,1); mdqmex(91,2); mdqmex(91,3); mdqmex(91,4); end
%         function unregister_startable(~), mdqmex(91,0); end
%         function unregister_stimulation_and_ttl(~), mdqmex(91,1); end
%         function unregister_behavioralcodes(~), mdqmex(91,2); end
        function unregister_digitalinput(~), mdqmex(91,3); end
        function init_timer(~,start,offset), if ~exist('offset','var'), offset = 0; end; mdqmex(92,start,offset); end
        function strobe_function(~,code), mdqmex(96,code); end
        function dummy_eventmarker(~,code), mdqmex(96,code); end
        function num_reward = dummy_goodmonkey(~,Duration,varargin)
            num_reward = 0;
            persistent NumReward PauseTime
            JuiceLine = 1; %#ok<*NASGU>
            NonBlocking = 0;
            TriggerVal = 3;
            
            if Duration < 0
                MLConfig = varargin{2};
                r = MLConfig.RewardFuncArgs;
                NumReward = r.NumReward;
                PauseTime = r.PauseTime;
                return
            end
            
            ML_WarmingUp = false;
            code = [];
            if ~isempty(varargin)
                nargs = length(varargin);
                if mod(nargs,2), error('goodmonkey() requires all arguments beyond the first to come in parameter/value pairs'); end
                for m = 1:2:nargs
                    val = varargin{m+1};
                    switch lower(varargin{m})
                        case 'numreward', NumReward = val;
                        case 'pausetime', PauseTime = val;
                        case 'eventmarker', code = val;
                        case 'nonblocking', NonBlocking = val;
                        case 'duration', Duration = val;
                        case 'ml_warmingup', ML_WarmingUp = val;
                        case 'eval', eval(val);
                    end
                end
            end
            switch length(code)
                case 0, code = NaN(1,NumReward);
                case 1, code = repmat(code,1,NumReward);
                otherwise, code(end+1:NumReward) = code(end);
            end
            
            switch NonBlocking
                case 0
                    for m = 1:NumReward
                        if ML_WarmingUp
                            mdqmex(102,Duration);
                            break;
                        else
                            mdqmex(99,Duration,code(m));
                            mdqmex(100);
                            if m < NumReward, mdqmex(102,PauseTime); end
                        end
                    end
                case {1,2}
                    mdqmex(106,NumReward,Duration,code,PauseTime,NonBlocking);
                otherwise
                    error('Unknown NonBlocking Mode!!!');
            end
            num_reward = NumReward;
        end
        function simulated_input(obj,action,varargin)
            switch action
                case -1 % reset joystick position
                    obj.SimulatedJoystick = zeros(1,2);
                case 0  % update buttons
                    obj.SimulatedButton = mglgetkeystate([49:57 48]); % key 1-9 & 0, see https://msdn.microsoft.com/en-us/library/windows/desktop/dd375731(v=vs.85).aspx
                case 1  % displacement type
                    obj.SimulatedJoystick(varargin{1}) = obj.SimulatedJoystick(varargin{1}) + varargin{2};
            end
        end
        function add_mouse(obj)
            if ~obj.mouse_present()
                obj.DAQ{end+1,1} = pointingdevice; obj.Type(end+1,1) = 4;
                obj.DAQ{end}.register(); m = length(obj.DAQ); obj.Startable(end+1) = m; obj.Map.Mouse = m;
            end
        end
        function create_simulated_output(obj)
            ao = analogoutput_playback;
            for m=1:obj.nStimulation
                addchannel(ao,m-1,sprintf('Stimulation%d',m));
            end
            for m=1:obj.nStimulation
                if isempty(obj.Stimulation{m}), obj.Stimulation{m} = ao; end
            end
            
            dio = digitalio_playback;
            for m=1:obj.nTTL
                addline(dio,m-1,0,'Out',sprintf('TTL%d',m));
            end
            for m=1:obj.nTTL
                if isempty(obj.TTL{m}), obj.TTL{m} = dio; end
            end
        end
    end        
    
    methods (Access = protected)
        function init(obj)
            for m=1:length(obj.DAQ), try delete(obj.DAQ{m}); catch, end, end
            obj.DAQ = [];
            obj.Type = [];
            obj.Reward = [];
            obj.BehavioralCodes = [];
            obj.StrobeBit = [];
            obj.Stimulation = cell(1,obj.nStimulation);
            obj.TTL = cell(1,obj.nTTL);
            obj.SimulatedJoystick = zeros(1,2);
            obj.SimulatedButton = false(1,obj.nButton(1));
            obj.Map = struct('Eye',zeros(2,2),'Joystick',zeros(2,2),'PhotoDiode',zeros(1,2),'Button',zeros(obj.nButton(1),4),'General',zeros(obj.nGeneral,2),'Mouse',0,'USBJoystick',0,'EyeTracker',0);
            obj.Startable = [];
            obj.LastAcquisition = 0;
        end
        function update(obj,MLConfig)
            unregister_all(obj);
            for m=obj.MLConfigFields, obj.(m{1}) = MLConfig.(m{1}); end
            mdqmex(95,obj.StrobeTrigger,MLConfig.StrobePulseSpec.T1,MLConfig.StrobePulseSpec.T2);
            for m=1:length(obj.DAQ)
                switch lower(class(obj.DAQ{m}))
                    case {'analoginput','pointingdevice','eyetracker'}, register(obj.DAQ{m});
                    case 'digitalio', if strcmpi(obj.DAQ{m}.Line(1).Direction,'in'), register(obj.DAQ{m}); end
                end
            end
            init_eventmarker(obj);
            init_goodmonkey(obj,MLConfig);
        end
        function init_eventmarker(obj)
            mdqmex(91,2);  % unregister behavioralcodes
            obj.eventmarker = @obj.dummy_eventmarker;
            if isempty(obj.BehavioralCodes), return, end
            if (1==obj.StrobeTrigger||2==obj.StrobeTrigger) && isempty(obj.StrobeBit), return, end
            obj.BehavioralCodes.register('BehavioralCodes');
            if ~isempty(obj.StrobeBit), obj.StrobeBit.register('StrobeBit'); end
            obj.eventmarker = @obj.strobe_function;
        end
        function init_goodmonkey(obj,MLConfig)
            if isempty(obj.Reward)
                obj.goodmonkey = @obj.dummy_goodmonkey;
                mdqmex(91,4);  % unregister reward
            else
                obj.goodmonkey = get_function_handle(MLConfig.MLPath.RewardFunction);
                obj.Reward.register('Reward');
            end
            obj.goodmonkey(-1,obj,MLConfig);
        end
        function [subsystem,ia,ic] = unique_subsystem(~,IO)
            if isempty(IO), subsystem = []; ia = []; ic = []; return, end
            um = zeros(length(IO),3);
            [~,~,um(:,1)] = unique({IO.Adaptor});
            [~,~,um(:,2)] = unique({IO.DevID});
            [~,~,um(:,3)] = unique({IO.Subsystem});
            [~,ia,ic] = unique(um,'rows');
            subsystem = IO(ia);
        end
    end
end
