classdef LBC_FixAnalyzer < mladapter
    properties
        BlinkTime = 300;
    end
    properties (SetAccess = protected)
        BreakCount
    end
    properties (Access = protected)
        ReturnTime
    end
    
    methods
        function obj = LBC_FixAnalyzer(varargin)
            obj = obj@mladapter(varargin{:});
        end
        function init(obj,p)
            init@mladapter(obj,p);
            obj.BreakCount = 0;
        end
        function continue_ = analyze(obj,p)
            analyze@mladapter(obj,p);
            elapsed = p.scene_time();
            
            if obj.Adapter.Success
                obj.Success = true;
                obj.ReturnTime = elapsed + obj.BlinkTime;
            elseif obj.ReturnTime <= elapsed
                if obj.Success, obj.BreakCount = obj.BreakCount + 1; end
                obj.Success = false;
            end
            continue_ = true;
        end
    end
end
