classdef analogoutput < dynamicprops
    properties
        BufferingConfig;        % unused
        Channel;
        EventLog;
        InitialTriggerTime;
        Name;
        RepeatOutput;
        Running;
        SampleRate;
        SamplesAvailable;
        SamplesOutput;
        Sending;
        TriggersExecuted;
        TriggerType;
    end
    properties (Constant)
        Type = 'Analog Output';
    end
    properties
        WaveformsQueued;
        ManualTriggerWFOutput;
        ManualTriggerNextWF;
        RegenerationMode;
    end
    properties (Hidden = true)
        hwInfo;
    end
    properties (Access = protected)
        AdaptorName;
        DeviceID;
        TaskID;
    end
    properties (Access = protected, Constant)
        TriggerTypeSet = {'Immediate','Manual'};
        ManualTriggerWFOutputSet = {'All','One','Chosen'};
        RegenerationModeSet = {'On','Off'};
        SubsystemType = 2;  % 1: AI, 2: AO, 3: DIO
    end
    
    methods (Access = protected, Static)
        function id = taskid()
            persistent counter;
            if isempty(counter), n = now; counter = floor((n - floor(n))*10^9); end
            counter = counter + 1;
            id = counter;
        end
    end
    methods (Access = protected)
        function val = numchk(obj,val,varargin) %#ok<*INUSL>
            if any(~isnumeric(val)), error('Parameter must be numeric.'); end
            switch nargin
                case 2
                    if ~isscalar(val), error('Parameters must be a scalar.'); end
                case 3
                    len = varargin{1};
                    if len < numel(val), error('Parameters greater than %d elements are currently unsupported.',len); end
                case 4
                    minval = varargin{1}; maxval = varargin{2};
                    if ~isscalar(val), error('Parameters must be a scalar.'); end
                    if val < minval, error('Property value can not be set below the minimum value constraint.'); end
                    if maxval < val, error('Property value can not be set below the minimum value constraint.'); end
                otherwise
                    error('Too many input arguments.');
            end
        end
        function [val,idx] = validateStringSet(obj,prop,val)
            if isempty(val) || ~ischar(val), error('Paramter must be a non-empty string.'); end
            idx = 0;
            propset = [prop 'Set'];
            if isprop(obj,propset)
                idx = find(strncmpi(obj.(propset),val,length(val)));
                if 1~=length(idx), error('There is no enumerated value named ''%s'' for the ''%s'' property',val,prop); end
                val = obj.(propset){idx};
            end
        end
        function events = getdaqevents(obj)
            events = mdqmex(73,obj.AdaptorName,obj.DeviceID,obj.SubsystemType,obj.TaskID);
            for m=1:length(events), events(m).Data.AbsTime = datevec(events(m).Data.AbsTime); end
        end
    end
    methods (Hidden = true)
        function update_channels(obj)
            param = [obj.Channel.HwChannel obj.Channel.OutputRange];
            if iscell(param), param = cell2mat(param); end
            mdqmex(60,obj.AdaptorName,obj.DeviceID,obj.SubsystemType,obj.TaskID,param);
        end
    end
    
    methods
        function obj = analogoutput(adaptor,DeviceID)
            hw = daqhwinfo;
            idx = strncmpi(hw.InstalledAdaptors,adaptor,length(adaptor));
            if ~any(idx), error('Failure to find requested data acquisition device: %s.',adaptor); end
            adaptor = hw.InstalledAdaptors{idx};
            hw = daqhwinfo(adaptor);
            if ~exist('DeviceID','var'), DeviceID = '0'; end
            if isscalar(DeviceID), DeviceID = num2str(DeviceID); end
            idx = strcmpi(hw.InstalledBoardIds,DeviceID);
            if ~any(idx), error('Constructors require a device ID, e.g. analogoutput(''nidaq'',''Dev1'').'); end
            if isempty(hw.ObjectConstructorName{idx,obj.SubsystemType}), error('This device does not support the subsystem requested.  Use DAQHWINFO(adaptorname) to determine valid constructors.'); end
            DeviceID = hw.InstalledBoardIds{idx};
            
            obj.AdaptorName = adaptor;
            obj.DeviceID = DeviceID;
            obj.TaskID = obj.taskid();
            mdqmex(53,obj.AdaptorName,obj.DeviceID,obj.SubsystemType,obj.TaskID);
            obj.hwInfo = about(obj);
            
            obj.BufferingConfig = [64 2];
            obj.Channel = aochannel.empty;
            obj.Name = [adaptor DeviceID '-AO'];
        end
        function delete(obj)
            for m=1:length(obj)
                mdqmex(54,obj(m).AdaptorName,obj(m).DeviceID,obj(m).SubsystemType,obj(m).TaskID);
            end
        end
        function info = about(obj)
            info = mdqmex(52,obj.AdaptorName,obj.DeviceID,obj.SubsystemType);
        end
        
        function chans = addchannel(obj,hwch,varargin)
            if 1 < length(obj), error('OBJ must be a 1-by-1 analog input or analog output object.'); end
            if obj.isrunning(), error('A channel cannot be added while OBJ is running.'); end
            if 1==nargin, error('Not enough input arguments.  HWCH must be defined with hardware IDs.'); end
            
            hwch = hwch(:)';
            nchan = length(hwch);
            for m=1:nchan
                idx = hwch(m) == obj.hwInfo.ChannelIDs;
                if ~any(idx), error('Unable to set HwChannel above maximum value of %d.',max(obj.hwInfo.ChannelIDs)); end
            end
            
            switch nargin
                case 2
                    a = length(obj.Channel) + 1;
                    b = a + nchan - 1;
                    index = a:b;
                    names = cell(1,nchan);
                case 3
                    if isnumeric(varargin{1})
                        index = varargin{1}(:)';
                        names = cell(1,nchan);
                    else
                        a = length(obj.Channel) + 1;
                        b = a + nchan - 1;
                        index = a:b;
                        names = varargin{1}; if ~iscell(names), names = varargin(1); end
                    end
                case 4
                    index = varargin{1};
                    names = varargin{2}; if ~iscell(names), names = varargin(2); end
                otherwise
                    error('Too many input arguments.');
            end
            if nchan~=length(index), error('The length of HWCH must equal the length of INDEX.'); end
            if 1==length(names), names(1,2:nchan) = names(1); end
            if nchan~=length(names), error('Invalid number of NAMES provided for the number of hardware IDs specified in HWCH.'); end
            
            if isempty(obj.Channel)
                if 1~=index(1), error('Invalid INDEX provided.  The Channel array cannot contain gaps.'); end
            else
                HwChannel = obj.Channel.HwChannel;
                Index = obj.Channel.Index;
                if iscell(HwChannel), HwChannel = cell2mat(HwChannel); end
                if iscell(Index), Index = cell2mat(Index); end
                for m=1:nchan
                    if any(HwChannel==hwch(m)), error('A hardware channel with the same name is already in the task.'); end
                    if length(Index)+1 < index(m), error('Invalid INDEX provided.  The Channel array cannot contain gaps.'); end
                    Index = [Index(1:index(m)-1); index(m); Index(index(m):end)];
                    HwChannel = [HwChannel(1:index(m)-1); hwch(m); HwChannel(index(m):end)];
                end
            end
            
            chans(nchan,1) = aochannel;
            for m=1:nchan
                chans(m).Parent = obj;
                chans(m).ChannelName = names{m};
                chans(m).HwChannel = hwch(m);
                chans(m).Index = index(m);
                n = 10==obj.hwInfo.OutputRanges(:,2);
                if ~any(n), n = 1; end
                chans(m).OutputRange = obj.hwInfo.OutputRanges(n,:);
                chans(m).UnitsRange = obj.hwInfo.OutputRanges(n,:);
                
                obj.Channel = [obj.Channel(1:chans(m).Index-1); chans(m); obj.Channel(chans(m).Index:end)];
                if ~isempty(chans(m).ChannelName)
                    if ~isprop(obj,chans(m).ChannelName), addprop(obj,chans(m).ChannelName); end
                    obj.(chans(m).ChannelName) = [obj.(chans(m).ChannelName); chans(m)];
                end
            end
            for m=1:length(obj.Channel), obj.Channel(m).Index = m; end
            
            update_channels(obj);
        end
        
        function start(obj)
            for m=1:length(obj)
                if isempty(obj(m).Channel), error('At least one channel must be created before calling START.'); end
                if isrunning(obj(m)), error('OBJ has already started.'); end
                if 0==obj(m).SamplesAvailable, error('Data must be queued using PUTDATA before starting.'); end
                mdqmex(57,obj(m).AdaptorName,obj(m).DeviceID,obj(m).SubsystemType,obj(m).TaskID);
            end
        end
        function stop(obj,val)
            if ~exist('val','var'), val = 0; end
            for m=1:length(obj)
                mdqmex(58,obj(m).AdaptorName,obj(m).DeviceID,obj(m).SubsystemType,obj(m).TaskID,val);
            end
        end
        function tf = isrunning(obj)
            nobj = length(obj);
            tf = false(1,nobj);
            for m=1:nobj
                tf(m) = mdqmex(59,obj(m).AdaptorName,obj(m).DeviceID,obj(m).SubsystemType,obj(m).TaskID);
            end
         end
        function tf = issending(obj)
            nobj = length(obj);
            tf = false(1,nobj);
            for m=1:nobj
                tf(m) = mdqmex(71,obj(m).AdaptorName,obj(m).DeviceID,obj(m).SubsystemType,obj(m).TaskID);
            end
        end
        function trigger(obj)
            for m=1:length(obj)
                if ~strcmp(obj(m).TriggerType,'Manual'), error('TRIGGER is only valid when TriggerType is set to ''Manual''.'); end
                if ~isrunning(obj(m)), error('OBJ must be running before TRIGGER is called. Call START.'); end
                if issending(obj(m)), error('TRIGGER cannot be called when OBJ is sending.'); end
                mdqmex(70,obj(m).AdaptorName,obj(m).DeviceID,obj(m).SubsystemType,obj(m).TaskID);
            end
        end
        function wait(obj,waittime)
            for m=1:length(obj)
                aoTimer = tic;
                while toc(aoTimer) < waittime
                    if ~isrunning(obj(m)), break; end
                end
                if isrunning(obj(m)), error('WAIT reached its timeout before OBJ stopped running.'); end
            end
        end
        
        function putdata(obj,data)
            if 1 < length(obj), error('OBJ must be a 1-by-1 analog output object.'); end
            if isempty(obj.Channel), error('At least one channel must be created before calling PUTDATA.'); end
            if size(data,2)~=length(obj.Channel), error('DATA must have a column of data for each channel in OBJ.'); end
            mdqmex(66,obj.AdaptorName,obj.DeviceID,obj.TaskID,data');
        end
        function putsample(obj,sample)
            if 1 < length(obj), error('OBJ must be a 1-by-1 analog output object.'); end
            if isempty(obj.Channel), error('At least one channel must be created before calling PUTSAMPLE.'); end
            if size(sample,2)~=length(obj.Channel), error('DATA must have a column of data for each channel in OBJ.'); end
            if isrunning(obj), error('PUTSAMPLE cannot be called while OBJ is running.'); end
            mdqmex(67,obj.AdaptorName,obj.DeviceID,obj.TaskID,sample');
        end
        function varargout = showdaqevents(obj,idx)
            if 1 < length(obj), error('OBJ must be a 1-by-1 device object.'); end
            events = getdaqevents(obj);
            if ~exist('idx','var'), idx = 1:length(events); end
            if 0<nargout, varargout{1} = showdaqevents(events,idx); else showdaqevents(events,idx); end
        end
        function register(obj,name)
            if ~exist('name','var'), name = ''; end
            for m=1:length(obj)
                mdqmex(90,obj(m).AdaptorName,obj(m).DeviceID,obj(m).SubsystemType,obj(m).TaskID,name);
            end
        end
        
        function set.EventLog(obj,val) %#ok<*INUSD>
            error('Attempt to modify read-only property: ''EventLog''.');
        end
        function val = get.EventLog(obj)
            val = getdaqevents(obj);
        end
        function set.InitialTriggerTime(obj,val)
            error('Attempt to modify read-only property: ''InitialTriggerTime''.');
        end
        function val = get.InitialTriggerTime(obj)
            val = datevec(mdqmex(56,obj.AdaptorName,obj.DeviceID,obj.SubsystemType,obj.TaskID,'InitialTriggerTime'));
        end
        function set.RepeatOutput(obj,val)
            mdqmex(55,obj.AdaptorName,obj.DeviceID,obj.SubsystemType,obj.TaskID,'RepeatOutput',numchk(obj,val,0,Inf)); %#ok<*MCSUP>
        end
        function val = get.RepeatOutput(obj)
            val = mdqmex(56,obj.AdaptorName,obj.DeviceID,obj.SubsystemType,obj.TaskID,'RepeatOutput');
        end
        function set.Running(obj,val)
            error('Attempt to modify read-only property: ''Running''.');
        end
        function val = get.Running(obj)
            val = isrunning(obj);
        end
        function set.SampleRate(obj,val)
            mdqmex(55,obj.AdaptorName,obj.DeviceID,obj.SubsystemType,obj.TaskID,'SampleRate',numchk(obj,val,obj.hwInfo.MinSampleRate,obj.hwInfo.MaxSampleRate));
        end
        function val = get.SampleRate(obj)
            val = mdqmex(56,obj.AdaptorName,obj.DeviceID,obj.SubsystemType,obj.TaskID,'SampleRate');
        end
        function set.SamplesAvailable(obj,val)
            error('Attempt to modify read-only property: ''SamplesAvailable''.');
        end
        function val = get.SamplesAvailable(obj)
            val = mdqmex(65,obj.AdaptorName,obj.DeviceID,obj.SubsystemType,obj.TaskID);
        end
        function set.SamplesOutput(obj,val)
            error('Attempt to modify read-only property: ''SamplesOutput''.');
        end
        function val = get.SamplesOutput(obj)
            val = mdqmex(64,obj.AdaptorName,obj.DeviceID,obj.SubsystemType,obj.TaskID);
        end
        function set.Sending(obj,val)
            error('Attempt to modify read-only property: ''Sending''.');
        end
        function val = get.Sending(obj)
            val = issending(obj);
        end
        function set.TriggersExecuted(obj,val)
            error('Attempt to modify read-only property: ''TriggersExecuted''.');
        end
        function val = get.TriggersExecuted(obj)
            val = mdqmex(56,obj.AdaptorName,obj.DeviceID,obj.SubsystemType,obj.TaskID,'TriggersExecuted');
        end
        function set.TriggerType(obj,val)
            mdqmex(55,obj.AdaptorName,obj.DeviceID,obj.SubsystemType,obj.TaskID,'TriggerType',validateStringSet(obj,'TriggerType',val));
        end
        function val = get.TriggerType(obj)
            val = mdqmex(56,obj.AdaptorName,obj.DeviceID,obj.SubsystemType,obj.TaskID,'TriggerType');
        end
        function set.WaveformsQueued(obj,val)
            error('Attempt to modify read-only property: ''WaveformsQueued''.');
        end
        function val = get.WaveformsQueued(obj)
            val = mdqmex(56,obj.AdaptorName,obj.DeviceID,obj.SubsystemType,obj.TaskID,'WaveformsQueued');
        end
        function set.ManualTriggerWFOutput(obj,val)
            mdqmex(55,obj.AdaptorName,obj.DeviceID,obj.SubsystemType,obj.TaskID,'ManualTriggerWFOutput',validateStringSet(obj,'ManualTriggerWFOutput',val));
        end
        function val = get.ManualTriggerWFOutput(obj)
            val = mdqmex(56,obj.AdaptorName,obj.DeviceID,obj.SubsystemType,obj.TaskID,'ManualTriggerWFOutput');
        end
        function set.ManualTriggerNextWF(obj,val)
%             if 0 == obj.WaveformsQueued, error('ManualTriggerNextWF: At least one waveform must be queued using PUTDATA before setting this property.'); end
%             if val < 1 || obj.WaveformsQueued < val, error('ManualTriggerNextWF: Property value should be between 1 and %d (the number of waveforms queued).',obj.WaveformsQueued); end
            mdqmex(55,obj.AdaptorName,obj.DeviceID,obj.SubsystemType,obj.TaskID,'ManualTriggerNextWF',numchk(obj,val));
        end
        function val = get.ManualTriggerNextWF(obj)
            val = mdqmex(56,obj.AdaptorName,obj.DeviceID,obj.SubsystemType,obj.TaskID,'ManualTriggerNextWF');
        end
        function set.RegenerationMode(obj,val)
            if ischar(val)
                [~,idx] = validateStringSet(obj,'RegenerationMode',val);
                val = 2 - idx;
            else
                val = double(0 ~= val);
            end
            mdqmex(55,obj.AdaptorName,obj.DeviceID,obj.SubsystemType,obj.TaskID,'RegenerationMode',val);
        end
        function val = get.RegenerationMode(obj)
            val = mdqmex(56,obj.AdaptorName,obj.DeviceID,obj.SubsystemType,obj.TaskID,'RegenerationMode');
        end
        
        function out = set(obj,varargin)
            switch nargin
                case 1
                    out = [];
                    fields = properties(obj(1));
                    for m=1:length(fields)
                        propset = [fields{m} 'Set'];
                        if isprop(obj(1),propset), out.(fields{m}) = obj(1).(propset); else out.(fields{m}) = {}; end
                    end
                    return;
                case 2
                    if ~isscalar(obj), error('Object array must be a scalar when using SET to retrieve information.'); end
                    fields = varargin(1);
                    vals = {{}};
                case 3
                    if iscell(varargin{1})
                        fields = varargin{1};
                        vals = varargin{2};
                        [a,b] = size(vals);
                        if length(obj) ~= a || length(fields) ~= b, error('Size mismatch in Param Cell / Value Cell pair.'); end
                    else
                        fields = varargin(1);
                        vals = varargin(2);
                    end
                otherwise
                    if 0~=mod(nargin-1,2), error('Invalid parameter/value pair arguments.'); end
                    fields = varargin(1:2:end);
                    vals = varargin(2:2:end);
            end
            for m=1:length(obj)
                proplist = properties(obj(m));
                for n=1:length(fields)
                    field = fields{n};
                    if ~ischar(field), error('Invalid input argument type to ''set''.  Type ''help set'' for options.'); end
                    if 1==size(vals,1), val = vals{1,n}; else val = vals{m,n}; end
                    
                    idx = strncmpi(proplist,field,length(field));
                    if 1~=sum(idx), error('The property, ''%s'', does not exist.',field); end
                    prop = proplist{idx};
                    
                    if ~isempty(val)
                        obj(m).(prop) = val;
                    else
                        propset = [prop 'Set'];
                        if isprop(obj(m),propset)
                            out = obj(m).(propset)(:);
                        else
                            fprintf('The ''%s'' property does not have a fixed set of property values.\n',prop);
                        end
                    end
                end
            end
        end
        function out = get(obj,fields)
            if ischar(fields), fields = {fields}; end
            out = cell(length(obj),length(fields));
            for m=1:length(obj)
                proplist = properties(obj(m));
                for n=1:length(fields)
                    field = fields{n};
                    idx = strncmpi(proplist,field,length(field));
                    if 1~=sum(idx), error('The property, ''%s'', does not exist.',field); end
                    prop = proplist{idx};
                    out{m,n} = obj(m).(prop);
                end
            end
            if isscalar(out), out = out{1}; end
        end
    end
end
