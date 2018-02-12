classdef FrameCounter < mladapter
    properties
        NumFrame = 0;
    end
    methods
        function obj = FrameCounter(varargin)
            obj = obj@mladapter(varargin{:});
        end
        function continue_ = analyze(obj,p)
            analyze@mladapter(obj,p);
            obj.Success = obj.NumFrame <= p.scene_frame();
            continue_ = ~obj.Success;
        end
    end
end
