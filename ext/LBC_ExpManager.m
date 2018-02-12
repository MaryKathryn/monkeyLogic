classdef LBC_ExpManager < mladapter
    properties
        ImageChanger
        RewardScheduler
    end
    properties (SetAccess = protected)
        PropFixation
    end
    properties (Access = protected)
        PulseCounter
        FixAnalyzer
    end
    
    methods
        function obj = LBC_ExpManager(adapter)
            if 0<nargin
                obj.ImageChanger = adapter{1};
                obj.RewardScheduler = adapter{2};
            end
        end
        
        function set.ImageChanger(obj,val)
            obj.ImageChanger = val;
            obj.Tracker = val.tracker();
            obj.PulseCounter = val.get_adapter('PulseCounter'); %#ok<*MCSUP>
        end
        function set.RewardScheduler(obj,val)
            obj.RewardScheduler = val;
            obj.FixAnalyzer = val.get_adapter('LBC_FixAnalyzer');
        end
        
        function init(obj,p)
            obj.ImageChanger.init(p);
            obj.RewardScheduler.init(p);
        end
        function fini(obj,p)
            obj.ImageChanger.fini(p);
            obj.RewardScheduler.fini(p);
        end
        function continue_ = analyze(obj,p)
            continue_ = obj.ImageChanger.analyze(p);
            obj.Success = obj.ImageChanger.Success;
            obj.RewardScheduler.analyze(p);
            obj.PropFixation = obj.RewardScheduler.TotalFixFrame / obj.RewardScheduler.TotalElapsedFrame;
        end
        function draw(obj,p)
            obj.ImageChanger.draw(p);
            obj.RewardScheduler.draw(p);

            elapsed_sec = floor(obj.ImageChanger.ElapsedFrame * obj.Tracker.Screen.FrameLength / 1000);
            elapsed_minutes = floor(elapsed_sec/60);
            elapsed_hours = floor(elapsed_minutes/60);
            elapsed_sec = rem(elapsed_sec,60);
            time_string = sprintf('Elapsed time: %02d:%02d:%02d',elapsed_hours,elapsed_minutes,elapsed_sec);
            if ~isempty(obj.PulseCounter), time_string = [time_string sprintf(', TR pulse: %d',obj.PulseCounter.Count)]; end
            p.dashboard(1,time_string);

            p.dashboard(2,sprintf('Current image: %s',obj.ImageChanger.CurrentImageName));
            
            if isempty(obj.RewardScheduler.CurrentSchedule), schedule_str = ''; else schedule_str = sprintf('#%d (%.1f to %.1f s)',obj.RewardScheduler.CurrentSchedule,obj.RewardScheduler.Schedule(obj.RewardScheduler.CurrentSchedule,2:3)/1000); end
            p.dashboard(3,sprintf('Reward schedule: %s',schedule_str));
			
            fix_string = sprintf('Fixation: %.1f%% (= %d / %d)',obj.PropFixation*100,obj.RewardScheduler.TotalFixFrame,obj.RewardScheduler.TotalElapsedFrame);
            if ~isempty(obj.FixAnalyzer), fix_string = [fix_string sprintf(', Break: %d',obj.FixAnalyzer.BreakCount)]; end
            p.dashboard(4,fix_string);
            
            current_fix = obj.RewardScheduler.CurrentFixFrame * obj.Tracker.Screen.FrameLength / 1000;
            next_reward = (obj.RewardScheduler.NextRewardFrame - obj.RewardScheduler.CurrentFixFrame) * obj.Tracker.Screen.FrameLength / 1000;
            p.dashboard(5,sprintf('Current fix: %.1f s, To next reward: %.1f s',current_fix,next_reward));
        end
    end
    
    methods
        function info(obj,s)
            Args = cell(1,2);
            a = SceneParam();
            obj.ImageChanger.info(a);
            Args{1} = a;
            a = SceneParam();
            obj.RewardScheduler.info(a);
            Args{2} = a;

            s.AdapterList{end+1} = class(obj);
            s.AdapterArgs{end+1} = Args;
        end
        function val = fieldnames(obj)
            val = properties(obj); l = length(val); s = false(l,1);
            for m=1:l, s(m) = strcmp(obj.findprop(val{m}).SetAccess,'public'); end
            val = setdiff(val(s),{'ImageChanger','RewardScheduler'});
        end
    end
end
