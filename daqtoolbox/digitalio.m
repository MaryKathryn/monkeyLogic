classdef digitalio < dynamicprops
    properties
        Line
        Name
        Running
        SampleRate
        SamplesAcquired
        SamplesAvailable
    end
    properties (Constant)
        Type = 'Digital IO'
    end
    properties (Hidden = true)
        hwInfo
    end
    properties (Access = protected)
        AdaptorName
        DeviceID
        TaskID
    end
    properties (Access = protected, Constant)
        SubsystemType = 3   % 1: AI, 2: AO, 3: DIO
    end
    
    methods (Access = protected, Static)
        function id = taskid()
            persistent counter;
            if isempty(counter), n = now; counter = floor((n - floor(n))*10^9); end
            counter = counter + 1;
            id = counter;
        end
    end
    methods (Hidden = true)
        function update_lines(obj)
            param = [obj.Line.Port obj.Line.HwLine];
            if iscell(param), param = cell2mat(param); end
            mdqmex(60,obj.AdaptorName,obj.DeviceID,obj.SubsystemType,obj.TaskID,[param strcmpi(obj.Line.Direction,'Out')+1]);
        end
    end
    
    methods
        function obj = digitalio(adaptor,DeviceID)
            hw = daqhwinfo;
            idx = strncmpi(hw.InstalledAdaptors,adaptor,length(adaptor));
            if ~any(idx), error('Failure to find requested data acquisition device: %s.',adaptor); end
            adaptor = hw.InstalledAdaptors{idx};
            hw = daqhwinfo(adaptor);
            if ~exist('DeviceID','var'), DeviceID = '0'; end
            if isscalar(DeviceID), DeviceID = num2str(DeviceID); end
            idx = strcmpi(hw.InstalledBoardIds,DeviceID);
            if ~any(idx), error('Constructors require a device ID, e.g. digitalio(''nidaq'',''Dev1'').'); end
            if isempty(hw.ObjectConstructorName{idx,obj.SubsystemType}), error('This device does not support the subsystem requested.  Use DAQHWINFO(adaptorname) to determine valid constructors.'); end
            DeviceID = hw.InstalledBoardIds{idx};
            
            obj.AdaptorName = adaptor;
            obj.DeviceID = DeviceID;
            obj.TaskID = obj.taskid();
            mdqmex(53,obj.AdaptorName,obj.DeviceID,obj.SubsystemType,obj.TaskID);
            obj.hwInfo = about(obj);
            
            obj.Line = dioline.empty;
            obj.Name = [adaptor DeviceID '-DIO'];
        end
        function delete(obj)
            for m=1:length(obj)
                mdqmex(54,obj(m).AdaptorName,obj(m).DeviceID,obj(m).SubsystemType,obj(m).TaskID);
            end
        end
        function info = about(obj)
            info = mdqmex(52,obj.AdaptorName,obj.DeviceID,obj.SubsystemType);
        end
        
        function lines = addline(obj,hwline,varargin)
            if 1 < length(obj), error('OBJ must be a 1-by-1 digital I/O object.'); end
            switch nargin
                case 1, error('Not enough input arguments. HWLINE and DIRECTION must be defined.');
                case 2, error('Not enough input arguments. DIRECTION must be defined.');
            end
            
            hwline = hwline(:)';
            nline = length(hwline);
            switch nargin
                case 3
                    port = zeros(1,nline);
                    direction = varargin{1};
                    names = cell(1,nline);
                case 4
                    if ischar(varargin{1})
                        port = zeros(1,nline);
                        direction = varargin{1};
                        names = varargin{2}; if ~iscell(names), names = {names}; end
                    else
                        port = varargin{1}; port = port(:)';
                        direction = varargin{2};
                        names = cell(1,nline);
                    end
                case 5
                    port = varargin{1}; port = port(:)';
                    direction = varargin{2};
                    names = varargin{3}; if ~iscell(names), names = {names}; end
                otherwise
                    error('Too many input arguments.');
            end
            nport = length(port);
            if 1==nline, hwline = repmat(hwline,1,nport); nline = nport; end
            if 1==nport, port = repmat(port,1,nline); nport = nline; end
            if 1==length(names), names(1,2:nline) = names(1); end
            if nline~=nport, error('The lengths of HWLINE and PORT must be equal or either of them must be a scalar.'); end
            if nline~=length(names), error('Invalid number of NAMES provided for the number of lines specified in HWLINE and/or PORT.'); end
            
            PortIDs = [obj.hwInfo.Port.ID];
            for m=1:nline
                idx = port(m) == PortIDs;
                if ~any(idx), error('Unable to set Port above maximum value of %d.',max(PortIDs)); end
                if ~any(hwline(m) == obj.hwInfo.Port(idx).LineIDs), error('The specified line could not be found on any port.'); end
                if isempty(strfind(obj.hwInfo.Port(idx).Direction,lower(direction))), error('Port does not support requested direction. For valid port directions, see your hardware specification sheet.'); end
            end
            if ~isempty(obj.Line)
                old = [obj.Line.HwLine obj.Line.Port];
                if iscell(old), old = cell2mat(old); end
                [a,b] = size(old);
                new = [hwline' port'];
                for m=1:nline
                    if any(b==sum(old==repmat(new(m,:),a,1),2)), error('Line %d on port %d already exists.',new(m,:)); end
                end
            end
            
            lines(nline,1) = dioline;
            for m=1:nline
                lines(m).Parent = obj;
                lines(m).Direction = direction;
                lines(m).HwLine = hwline(m);
                lines(m).Index = length(obj.Line) + 1;
                lines(m).LineName = names{m};
                lines(m).Port = port(m);
                
                obj.Line = [obj.Line; lines(m)];
                if ~isempty(lines(m).LineName)
                    if ~isprop(obj,lines(m).LineName), addprop(obj,lines(m).LineName); end
                    obj.(lines(m).LineName) = [obj.(lines(m).LineName); lines(m)];
                end
            end
            
            update_lines(obj);
        end
        
        function start(obj)
            for m=1:length(obj)
                if isempty(obj(m).Line), error('At least one line must be created before calling START.'); end
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
        
        function putvalue(obj,val)
            for m=1:length(obj)
                nline = length(obj(m).Line);
                if isscalar(val)
                    bin = dec2binvec(val, nline);
                    if nline < length(bin), error('DATA is too large to be represented by the number of lines in OBJ.'); end
                else
                    if nline ~= numel(val), error('The number of lines and binvec values must be the same.'); end
                    bin = 0 < val;
                end
                mdqmex(68,obj(m).AdaptorName,obj(m).DeviceID,obj(m).TaskID,bin);
            end                
        end
        function val = getvalue(obj)
            if 1 < length(obj), error('OBJ must be a 1-by-1 digital I/O object or a digital I/O line array.'); end
            val = mdqmex(69,obj.AdaptorName,obj.DeviceID,obj.TaskID);
        end
        function marker_position = flushmarker(obj)
            marker_position = mdqmex(77,obj.AdaptorName,obj.DeviceID,obj.SubsystemType,obj.TaskID,1);
        end
        function flushdata(obj,mode) % Since we don't do triggering in pointing device, mode doesn't matter.
            for m=1:length(obj)
                mdqmex(72,obj(m).AdaptorName,obj(m).DeviceID,obj(m).SubsystemType,obj(m).TaskID,false);
            end
        end
        function val = getdata(obj,nsamples)
            if 1 < length(obj), error('OBJ must be a 1-by-1 analog input object.'); end
            switch nargin
                case 1, data = mdqmex(74,obj.AdaptorName,obj.DeviceID,obj.SubsystemType,obj.TaskID)';
                otherwise, data = mdqmex(74,obj.AdaptorName,obj.DeviceID,obj.SubsystemType,obj.TaskID,nsamples)';
            end
            if isempty(data), val = []; else, val = '1' == fliplr(dec2bin(data,length(obj.Line))); end
        end
        function val = peekdata(obj,nsamples)
            if 1 < length(obj), error('OBJ must be a 1-by-1 analog input object.'); end
            switch nargin
                case 1, data = mdqmex(75,obj.AdaptorName,obj.DeviceID,obj.SubsystemType,obj.TaskID)';
                otherwise, data = mdqmex(75,obj.AdaptorName,obj.DeviceID,obj.SubsystemType,obj.TaskID,nsamples)';
            end
            if isempty(data), val = []; else, val = '1' == fliplr(dec2bin(data,length(obj.Line))); end
        end
        function marker_position = frontmarker(obj)
            marker_position = mdqmex(77,obj.AdaptorName,obj.DeviceID,obj.SubsystemType,obj.TaskID,2);
        end
        function [val,nsamps_from_marker] = peekfront(obj)
            if 1 < length(obj), error('OBJ must be a 1-by-1 pointing device object.'); end
            [data,nsamps_from_marker] = mdqmex(79,obj.AdaptorName,obj.DeviceID,obj.SubsystemType,obj.TaskID,true);
            if isempty(data), val = []; else, val = '1' == fliplr(dec2bin(data',length(obj.Line))); end
        end
        function marker_position = backmarker(obj)
            marker_position = mdqmex(77,obj.AdaptorName,obj.DeviceID,obj.SubsystemType,obj.TaskID,3);
        end
        function val = getback(obj)
            if 1 < length(obj), error('OBJ must be a 1-by-1 pointing device object.'); end
            data = mdqmex(79,obj.AdaptorName,obj.DeviceID,obj.SubsystemType,obj.TaskID,false);
            if isempty(data), val = []; else, val = '1' == fliplr(dec2bin(data',length(obj.Line))); end
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
