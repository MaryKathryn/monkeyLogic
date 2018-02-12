classdef pointingdevice < dynamicprops
    properties
        Name
        Running
        SampleRate
        SamplesAcquired
        SamplesAvailable
    end
    properties (Constant)
        Type = 'Pointing Device'
    end
    properties (Access = protected)
        hwInfo
        AdaptorName
        DeviceID
        TaskID
    end
    properties (Access = protected, Constant)
        SubsystemType = 1  % 1: AI, 2: AO, 3: DIO
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
    end
    
    methods
        function obj = pointingdevice(adaptor,DeviceID)
            if ~exist('adaptor','var'), adaptor = 'mouse'; end
            if ~exist('DeviceID','var'), DeviceID = '0'; end
            InstalledAdaptors = mdqmex(50,2);
            idx = strncmpi(InstalledAdaptors,adaptor,length(adaptor));
            if ~any(idx), error('Failure to find requested data acquisition device: %s.',adaptor); end
            adaptor = InstalledAdaptors{idx};
            hw = daqhwinfo(adaptor);
            if isscalar(DeviceID), DeviceID = num2str(DeviceID); end
            idx = strcmpi(hw.InstalledBoardIds,DeviceID);
            if ~any(idx), error('The specified device ID is invalid. Use DAQHWINFO(adaptorname) to determine valid device IDs.'); end
            if isempty(hw.ObjectConstructorName{idx,obj.SubsystemType}), error('This device does not support the subsystem requested.  Use DAQHWINFO(adaptorname) to determine valid constructors.'); end
            DeviceID = hw.InstalledBoardIds{idx};

            obj.AdaptorName = adaptor;
            obj.DeviceID = DeviceID;
            obj.TaskID = obj.taskid();
            mdqmex(53,obj.AdaptorName,obj.DeviceID,obj.SubsystemType,obj.TaskID);
            obj.hwInfo = about(obj);
            obj.Name = [adaptor DeviceID '-PointingDevice'];
        end
        function delete(obj)
            for m=1:length(obj)
                mdqmex(54,obj(m).AdaptorName,obj(m).DeviceID,obj(m).SubsystemType,obj(m).TaskID);
            end
        end
        function info = about(obj)
            info = mdqmex(52,obj.AdaptorName,obj.DeviceID,obj.SubsystemType);
        end
        
        function start(obj)
            for m=1:length(obj)
                if isrunning(obj(m)), error('OBJ has already started.'); end
                mdqmex(57,obj(m).AdaptorName,obj(m).DeviceID,obj(m).SubsystemType,obj(m).TaskID);
            end
        end
        function stop(obj)
            for m=1:length(obj)
                mdqmex(58,obj(m).AdaptorName,obj(m).DeviceID,obj(m).SubsystemType,obj(m).TaskID);
            end
        end
        function tf = isrunning(obj)
            nobj = length(obj);
            tf = false(1,nobj);
            for m=1:nobj
                tf(m) = mdqmex(59,obj(m).AdaptorName,obj(m).DeviceID,obj(m).SubsystemType,obj(m).TaskID);
            end
        end
        
        function marker_position = flushmarker(obj)
            marker_position = mdqmex(77,obj.AdaptorName,obj.DeviceID,obj.SubsystemType,obj.TaskID,1);
        end
        function flushdata(obj,mode) % Since we don't do triggering in pointing device, mode doesn't matter.
            for m=1:length(obj)
                mdqmex(72,obj(m).AdaptorName,obj(m).DeviceID,obj(m).SubsystemType,obj(m).TaskID,false);
            end
        end
        function [xy,buttons,timestamps] = getdata(obj,nsamples)
            if 1 < length(obj), error('OBJ must be a 1-by-1 analog input object.'); end
            switch nargin
                case 1, data = mdqmex(74,obj.AdaptorName,obj.DeviceID,obj.SubsystemType,obj.TaskID)';
                otherwise, data = mdqmex(74,obj.AdaptorName,obj.DeviceID,obj.SubsystemType,obj.TaskID,nsamples)';
            end
            if isempty(data)
                xy = []; buttons = logical([]); timestamps = [];
            else
                xy = double(data(:,1:2));
                buttons = '1' == fliplr(dec2bin(data(:,3),obj.hwInfo.Buttons));
                timestamps = data(:,4);
            end
        end
        function [xy,buttons,timestamps] = peekdata(obj,nsamples)
            if 1 < length(obj), error('OBJ must be a 1-by-1 analog input object.'); end
            switch nargin
                case 1, data = mdqmex(75,obj.AdaptorName,obj.DeviceID,obj.SubsystemType,obj.TaskID)';
                otherwise, data = mdqmex(75,obj.AdaptorName,obj.DeviceID,obj.SubsystemType,obj.TaskID,nsamples)';
            end
            if isempty(data)
                xy = []; buttons = logical([]); timestamps = [];
            else
                xy = double(data(:,1:2));
                buttons = '1' == fliplr(dec2bin(data(:,3),obj.hwInfo.Buttons));
                timestamps = data(:,4);
            end
        end
        function [xy,buttons] = getsample(obj)
            if 1 < length(obj), error('OBJ must be a 1-by-1 pointing device object.'); end
            data = mdqmex(76,obj.AdaptorName,obj.DeviceID,obj.TaskID)';
            if isempty(data)
                xy = []; buttons = logical([]);
            else
                xy = double(data(:,1:2));
                buttons = '1' == fliplr(dec2bin(data(:,3),obj.hwInfo.Buttons));
            end
        end
        function marker_position = frontmarker(obj)
            marker_position = mdqmex(77,obj.AdaptorName,obj.DeviceID,obj.SubsystemType,obj.TaskID,2);
        end
        function [xy,buttons,timestamps,nsamps_from_marker] = peekfront(obj)
            if 1 < length(obj), error('OBJ must be a 1-by-1 pointing device object.'); end
            [data,nsamps_from_marker] = mdqmex(79,obj.AdaptorName,obj.DeviceID,obj.SubsystemType,obj.TaskID,true);
            if isempty(data)
                xy = []; buttons = logical([]); timestamps = [];
            else
                data = data';
                xy = double(data(:,1:2));
                buttons = '1' == fliplr(dec2bin(data(:,3),obj.hwInfo.Buttons));
                timestamps = data(:,4);
            end
        end
        function marker_position = backmarker(obj)
            marker_position = mdqmex(77,obj.AdaptorName,obj.DeviceID,obj.SubsystemType,obj.TaskID,3);
        end
        function [xy,buttons,timestamps] = getback(obj)
            if 1 < length(obj), error('OBJ must be a 1-by-1 pointing device object.'); end
            data = mdqmex(79,obj.AdaptorName,obj.DeviceID,obj.SubsystemType,obj.TaskID,false)';
            if isempty(data)
                xy = []; buttons = logical([]); timestamps = [];
            else
                xy = double(data(:,1:2));
                buttons = '1' == fliplr(dec2bin(data(:,3),obj.hwInfo.Buttons));
                timestamps = data(:,4);
            end
        end
        function register(obj,name)
            if ~exist('name','var'), name = ''; end
            for m=1:length(obj)
                mdqmex(90,obj(m).AdaptorName,obj(m).DeviceID,obj(m).SubsystemType,obj(m).TaskID,name);
            end
        end
        function nsamps = TotalAcquired(obj)
            nsamps = mdqmex(80,obj.AdaptorName,obj.DeviceID,obj.SubsystemType,obj.TaskID);
        end
        
        function set.Running(obj,val) %#ok<*INUSD>
            error('Attempt to modify read-only property: ''Running''.');
        end
        function val = get.Running(obj)
            val = isrunning(obj);
        end
        function set.SampleRate(obj,val)
            mdqmex(55,obj.AdaptorName,obj.DeviceID,obj.SubsystemType,obj.TaskID,'SampleRate',numchk(obj,val,obj.hwInfo.MinSampleRate,obj.hwInfo.MaxSampleRate)); %#ok<*MCSUP>
        end
        function val = get.SampleRate(obj)
            val = mdqmex(56,obj.AdaptorName,obj.DeviceID,obj.SubsystemType,obj.TaskID,'SampleRate');
        end
        function set.SamplesAcquired(obj,val)
            error('Attempt to modify read-only property: ''SamplesAcquired''.');
        end
        function val = get.SamplesAcquired(obj)
            val = mdqmex(64,obj.AdaptorName,obj.DeviceID,obj.SubsystemType,obj.TaskID);
        end
        function set.SamplesAvailable(obj,val)
            error('Attempt to modify read-only property: ''SamplesAvailable''.');
        end
        function val = get.SamplesAvailable(obj)
            val = mdqmex(65,obj.AdaptorName,obj.DeviceID,obj.SubsystemType,obj.TaskID);
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
