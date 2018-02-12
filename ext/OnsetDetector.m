classdef OnsetDetector < mladapter
    properties (SetAccess = protected)
        Time
    end
    
    methods
        function obj = OnsetDetector(varargin)
            obj = obj@mladapter(varargin{:});
            if 0==nargin, return, end
            
            obj.Success = false;
        end
        function init(obj,p)
            init@mladapter(obj,p);
        end
        function continue_ = analyze(obj,p)
            continue_ = analyze@mladapter(obj,p);
            if ~obj.Success && obj.Adapter.Success
                if isprop(obj.Adapter,'Time'), obj.Time = obj.Adapter.Time(1); end
                obj.Success = true;
            end
        end
    end
end
