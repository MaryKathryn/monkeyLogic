classdef UE_GoalTouch < mladapter
    properties
        Goals = {};
        TouchedGoal = {};
    end
    properties (SetAccess = protected)
        Running
        Time
    end
    properties (Access = protected)
        LastData
        LastCrossTime
        
        FixWindowID
        Position
        ScreenPosition
        ThresholdInPixels
    end
    
    methods
        function obj = UE_GoalTouch(varargin)
            obj = obj@mladapter(varargin{:});
        end
        function delete(obj) %#ok<*INUSD>
            % Nothing
        end
        
        function init(obj,p)
            obj.Adapter.init(p);
            obj.Success = [];
            obj.Running = true;
            obj.LastCrossTime = 0;
        end
        
        function fini(obj,p)
            obj.Adapter.fini(p);
        end
        
        function set.Goals(obj, Targets)
            %send single char or cell array containing the possible goals
            if ischar(Targets)
                obj.Goals = {Targets};
            else
                obj.Goals = Targets;
            end
        end
        
        function continue_ = analyze(obj,p)
            obj.Adapter.analyze(p);
            if ~obj.Running
                continue_ = false;
                obj.Goals = {};
                return
            end
            
            data = obj.Tracker.currentData;

            if ~iscell(data)
               data = {data}; 
            end
            
            if any(ismember(data, obj.Goals))
                obj.TouchedGoal = obj.Goals(ismember(obj.Goals, data));
                obj.Success = 1;
                obj.Goals = {};
                continue_ = 0;
            else
                obj.Success = 0;
                obj.TouchedGoal = {};
                continue_ = 1;
            end
        end
        
        function stop(obj)
            obj.Running = false;
        end
    end
    
    methods (Access = protected)
    end
end
