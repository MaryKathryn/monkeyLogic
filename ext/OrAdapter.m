classdef OrAdapter < mladapter
    methods
        function obj = OrAdapter(adapter)
            if 0==nargin, return, end
            if iscell(adapter), obj.Adapter = adapter; else, obj.Adapter{1} = adapter; end
        end
        
        function add(obj,adapter)
            obj.Adapter{end+1} = adapter;
        end
        
        function init(obj,p)
            for m=1:length(obj.Adapter), obj.Adapter{m}.init(p); end
        end
        function fini(obj,p)
            for m=1:length(obj.Adapter), obj.Adapter{m}.fini(p); end
        end
        function continue_ = analyze(obj,p)
            continue_ = false;
            obj.Success = false;
            for m=1:length(obj.Adapter)
                continue_ = continue_ | obj.Adapter{m}.analyze(p);
                obj.Success = obj.Success | obj.Adapter{m}.Success;
            end
        end
        function draw(obj,p)
            for m=1:length(obj.Adapter), obj.Adapter{m}.draw(p); end
        end
    end
    
    methods
        function o = get_adapter(obj,name)
            if isa(obj,name)
                o = obj;
            else
                for m=1:length(obj.Adapter)
                    o = obj.Adapter.get_adapter(name);
                    if ~isempty(o), break, end
                end
            end
        end
        function o = tracker(obj)
            for m=1:length(obj.Adapter)
                o = obj.Adapter{m}.tracker();
                if ~isempty(o), break, end
            end
        end
        function info(obj,s)
            nanalyzer = length(obj.Adapter);
            Args = cell(1,nanalyzer);
            for m=1:nanalyzer
                a = SceneParam();
                obj.Adapter{m}.info(a);
                Args{m} = a;
            end
            s.AdapterList{end+1} = class(obj);
            s.AdapterArgs{end+1} = Args;
        end
    end
end
