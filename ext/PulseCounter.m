classdef PulseCounter < mladapter
    properties
        Button
    end
    properties (SetAccess = protected)
        Count
        Time
    end
    properties (Access = protected)
        LastData
    end
    
    methods
        function obj = PulseCounter(varargin)
            obj = obj@mladapter(varargin{:});
            if 0==nargin, return, end
            
            if ~strcmp(obj.Tracker.Signal,'Button'), error('PulseCounter needs ButtonTracker'); end
            obj.Button = obj.Tracker.ButtonsAvailable(1);
        end
        function set.Button(obj,button)
            if ~isscalar(button), error('Please assign a single button'); end
            if ~ismember(button,obj.Tracker.ButtonsAvailable), error('Button #%d doesn''t exist',button); end %#ok<*MCSUP>
            obj.Button = button;
        end
        function init(obj,p)
            init@mladapter(obj,p);
            if isempty(obj.Button), error('No button is assigned'); end
            obj.Count = 0;
            obj.Time = [];
        end
        function continue_ = analyze(obj,p)
            analyze@mladapter(obj,p);
            
            data = obj.Tracker.ClickData{obj.Button};
            if isempty(data), continue_ = true; return, end
            
            obj.Time = obj.Tracker.LastSamplePosition(obj.Button) + find(1==diff([obj.LastData; data]));
            count = length(obj.Time);
            obj.Count = obj.Count + count;
            obj.Success = 0 < count;
            continue_ = ~obj.Success;
            obj.LastData = data(end);
        end
    end
end