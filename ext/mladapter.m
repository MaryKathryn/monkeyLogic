classdef mladapter < handle
    properties (SetAccess = protected)
        Success
    end
    properties (Access = protected)
        Adapter
        Tracker
    end
%     methods (Abstract)
%         continue_ = analyze(obj,p)
%     end
    methods
        function obj = mladapter(varargin)
            if 0==nargin, return, end
%             if 1<nargin || ~isa(varargin{1},'mladapter'), error('The 1st argument must be mladapter'); end
            obj.Adapter = varargin{1};
            obj.Tracker = obj.tracker();
        end
        function init(obj,p)
            obj.Adapter.init(p);
            obj.Success = false;
        end
        function fini(obj,p)
            obj.Adapter.fini(p);
        end
        function continue_ = analyze(obj,p)
            continue_ = obj.Adapter.analyze(p);
        end
        function draw(obj,p)
            obj.Adapter.draw(p);
        end
        
        function o = get_adapter(obj,name)
            if isa(obj,name), o = obj; else, o = obj.Adapter.get_adapter(name); end
        end
        function o = tracker(obj)
            o = obj.Adapter.tracker();
        end
        function val = export(obj)
            val = fieldnames(obj);
            for m=1:size(val,1), val{m,2} = obj.(val{m,1}); end
        end
        function import(obj,val)
            fn = fieldnames(obj);
            for m=1:size(val,1), if ismember(val{m,1},fn), obj.(val{m,1}) = val{m,2}; end, end
        end
        function info(obj,s)
            obj.Adapter.info(s);
            s.AdapterList{end+1} = class(obj);
            s.AdapterArgs{end+1} = obj.export();
        end
        function val = fieldnames(obj)
            val = properties(obj); l = length(val); s = false(l,1);
            for m=1:l, s(m) = strcmp(obj.findprop(val{m}).SetAccess,'public'); end
            val = val(s);
        end
    end
end
