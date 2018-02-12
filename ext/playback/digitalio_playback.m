classdef digitalio_playback < dynamicprops
    properties
        Line
        Name
        Running = false
        SampleRate = 1000
        SamplesAcquired = 0
        SamplesAvailable = 0
    end
    properties (Constant)
        Type = 'Digital IO';
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
        SubsystemType = 3;  % 1: AI, 2: AO, 3: DIO
    end
    
    methods
        function obj = digitalio(adaptor,DeviceID), end
        function delete(obj), end
        function info = about(obj), end
        
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
            
%             PortIDs = [obj.hwInfo.Port.ID];
%             for m=1:nline
%                 idx = port(m) == PortIDs;
%                 if ~any(idx), error('Unable to set Port above maximum value of %d.',max(PortIDs)); end
%                 if ~any(hwline(m) == obj.hwInfo.Port(idx).LineIDs), error('The specified line could not be found on any port.'); end
%                 if isempty(strfind(obj.hwInfo.Port(idx).Direction,lower(direction))), error('Port does not support requested direction. For valid port directions, see your hardware specification sheet.'); end
%             end
            if ~isempty(obj.Line)
                old = [obj.Line.HwLine obj.Line.Port];
                if iscell(old), old = cell2mat(old); end
                [a,b] = size(old);
                new = [hwline' port'];
                for m=1:nline
                    if any(b==sum(old==repmat(new(m,:),a,1),2)), error('Line %d on port %d already exists.',new(m,:)); end
                end
            end
            
            lines(nline,1) = dioline_playback;
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
        end
        
        function start(obj)
            for m=1:length(obj), obj(m).start(); end
        end
        function stop(obj)
            for m=1:length(obj), obj(m).stop(); end
        end
        function tf = isrunning(obj)
            nobj = length(obj);
            tf = false(1,nobj);
            for m=1:nobj
                tf(m) = obj.Running;
            end
        end
        
        function putvalue(obj,val), end
        function val = getvalue(obj), val = 0.5<rand; end
        function flushdata(obj,mode), end
        function register(obj,name), end
        
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
