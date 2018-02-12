classdef NotAdapter < mladapter
    methods
        function obj = NotAdapter(varargin)
            obj = obj@mladapter(varargin{:});
        end
        function continue_ = analyze(obj,p)
            continue_ = ~obj.Adapter.analyze(p);
            obj.Success = ~obj.Adapter.Success;
        end
    end
end
