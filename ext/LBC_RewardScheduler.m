classdef LBC_RewardScheduler < mladapter
    properties
        Schedule
    end
    properties (SetAccess = protected)
        TotalElapsedFrame
        TotalFixFrame
        CurrentFixFrame
        CurrentSchedule
        NextRewardFrame
    end
    properties (Access = protected)
        TimeInFrames
    end
    
    methods
        function obj = LBC_RewardScheduler(varargin)
            obj = obj@mladapter(varargin{:});
        end
        function init(obj,p)
            init@mladapter(obj,p);
            obj.TotalElapsedFrame = 0;
            obj.TotalFixFrame = 0;
            obj.CurrentFixFrame = 0;
            obj.NextRewardFrame = 0;
            obj.TimeInFrames = ceil(obj.Schedule(:,1:3) / obj.Tracker.Screen.FrameLength);
        end
        function continue_ = analyze(obj,p)
            continue_ = analyze@mladapter(obj,p);
            obj.Success = obj.Adapter.Success;
            
            obj.TotalElapsedFrame = obj.TotalElapsedFrame + 1;
            if obj.Success
                obj.TotalFixFrame = obj.TotalFixFrame + 1;
                obj.CurrentFixFrame = obj.CurrentFixFrame + 1;
            else
                obj.CurrentFixFrame = 0; obj.NextRewardFrame = 0;
            end

            obj.CurrentSchedule = find(obj.TimeInFrames(:,1) < obj.CurrentFixFrame,1,'last');
            if ~isempty(obj.CurrentSchedule)
                if obj.NextRewardFrame < obj.CurrentFixFrame
                    min_interval = obj.TimeInFrames(obj.CurrentSchedule,2);
                    max_interval = obj.TimeInFrames(obj.CurrentSchedule,3);
                    duration = obj.Schedule(obj.CurrentSchedule,4);
                    code = obj.Schedule(obj.CurrentSchedule,5);
                    
                    p.goodmonkey(duration,'eventmarker',code,'nonblocking',2);
                    obj.NextRewardFrame = obj.NextRewardFrame + round(min_interval + rand * (max_interval-min_interval));
                end
            end
        end
    end
end
