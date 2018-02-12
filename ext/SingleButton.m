classdef SingleButton < mladapter
    properties
        Button
    end
    properties (SetAccess = protected)
        Time
    end
    properties (Access = protected)
        LastData
        LastCrossTime
    end
    
    methods
        function obj = SingleButton(varargin)
            obj = obj@mladapter(varargin{:});
            if 0==nargin, return, end
            
            if ~strcmp(obj.Tracker.Signal,'Button'), error('SingleButton needs ButtonTracker'); end
            obj.Button = obj.Tracker.ButtonsAvailable(1);
        end
        function set.Button(obj,button)
            if ~isscalar(button), error('Please assign a single button'); end
            if ~ismember(button,obj.Tracker.ButtonsAvailable), error('Button #%d doesn''t exist',button); end %#ok<*MCSUP>
            obj.Button = button;
        end
        function init(obj,~)
            obj.Adapter.init(p);
            if isempty(obj.Button), error('No button is assigned'); end
            obj.Success = [];
            obj.LastCrossTime = 0;
        end
        function continue_ = analyze(obj,~)
            analyze@mladapter(obj,p);
            
            data = obj.Tracker.ClickData{obj.Button};
            if isempty(data), continue_ = true; return, end
            if isempty(obj.Success), obj.Success = data(1); end
            
            d = diff([obj.LastData; data]);
            t = find(-1==d|1==d,1,'last');
            
            if isempty(t)
                obj.Success = data(end);
                obj.Time = obj.LastCrossTime;
            else
                obj.LastCrossTime = obj.Tracker.LastSamplePosition + t;
            end
            continue_ = ~obj.Success;
            obj.LastData = data(end);
        end
    end
end