classdef TimeCounter < mladapter
    properties
        Duration = 0;
    end
    methods
        function obj = TimeCounter(varargin)
            obj = obj@mladapter(varargin{:});
        end
        function continue_ = analyze(obj,p)
            analyze@mladapter(obj,p);
            obj.Success = obj.Duration <= p.scene_time();
            continue_ = ~obj.Success;
        end
    end
end
