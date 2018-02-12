classdef LooseHold < mladapter
    properties
        HoldTime = 0;
        BreakTime = 300;
    end
    properties (Access = protected)
        WasGood
        ReturnTime
    end
    
    methods
        function obj = LooseHold(varargin)
            obj = obj@mladapter(varargin{:});
        end
        function init(obj,p)
            init@mladapter(obj,p);
            obj.WasGood = true;
        end
        function continue_ = analyze(obj,p)
            analyze@mladapter(obj,p);

            good = obj.Adapter.Success;
            elapsed = p.scene_time();
            
            if obj.WasGood && ~good
                obj.WasGood = false;
                obj.ReturnTime = min(obj.HoldTime,elapsed+obj.BreakTime);
            end
            
            if ~obj.WasGood && ~good
                if elapsed < obj.ReturnTime
                    continue_ = true;
                else
                    continue_ = false;
                    obj.Success = false;
                end
                return
            end
            
            if ~obj.WasGood && good
                obj.WasGood = true;
            end
            
            if elapsed < obj.HoldTime
                continue_ = true;
            else
                continue_ = false;
                obj.Success = true;
            end
        end
    end
end
