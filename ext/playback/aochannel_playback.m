classdef aochannel_playback < matlab.mixin.Copyable
    properties
        ChannelName;
        HwChannel;
        Index;
        OutputRange = [-10 10]
        Parent;
    end
    properties (Constant)
        Type = 'Channel';
    end
    properties
        Units = 'Volts';
        UnitsRange = [-10 10]
    end
    properties (Access = protected, Constant)
        UnitsSet = {'Volts'};
    end
    
    methods
        function obj = aochannel(parent)
            if 0==nargin || ~isa(parent,'analogoutput'), parent = []; end
            obj.Parent = parent;
            obj.Units = obj.UnitsSet{1};
        end
        function delete(obj)
            try
                if isobject(obj.Parent) && isvalid(obj.Parent)
                    if obj.Parent.Running
                        obj.Parent.Channel(obj.Index) = copy(obj);
                        warning('Cannot delete a channel while OBJ is running.');
                    else
                        obj.Parent.Channel(obj.Index) = [];
                        for m=1:length(obj.Parent.Channel), obj.Parent.Channel(m).Index = m; end
                        obj.Parent.update_channels;
                    end
                end
            catch  % update_channels may throw an error if the c++ object is already destroyed.
            end
        end
        function tf = ischannel(obj) %#ok<MANU>
            tf = true;
        end
        
        function varargout = subsref(obj,s)
            switch length(s)
                case 1
                    switch s.type
                        case '()'
                            if isempty(s.subs)
                                varargout{1} = [];
                            else
                                varargout{1} = obj(s.subs{1});
                            end
                        case '.'
                            nobj = length(obj);
                            switch nobj
                                case 0, varargout{1} = [];
                                case 1, varargout{1} = obj.(s.subs);
                                otherwise
                                    varargout{1} = cell(nobj,1);
                                    for m=1:nobj
                                        varargout{1}{m} = obj(m).(s.subs);
                                    end
                            end
                        otherwise
                            error('Unknown subsref type');
                    end
                case 2
                    switch s(1).type
                        case '.'
                            if all('()'==s(2).type)
                                narr = length(s(2).subs{1});
                                switch narr
                                    case 0, error('Index exceeds matrix dimension.');
                                    case 1, varargout{1} = obj(s(2).subs{1}).(s(1).subs);
                                    otherwise
                                        if any(length(obj) < s(2).subs{1}), error('Index exceeds matrix dimension.'); end
                                        varargout{1} = cell(narr,1);
                                        for m=1:narr
                                            varargout{1}{m} = obj(s(2).subs{1}(m)).(s(1).subs);
                                        end
                                end
                            end
                        case '()'
                            if '.'==s(2).type
                                varargout{1} = obj(s(1).subs{1}).(s(2).subs);
                            end
                        otherwise
                            error('Unknown subsref type');
                    end
                otherwise
                    error('Unknown subsref type');
            end
        end
        function n = numel(varargin)
            n = 1;
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
