classdef MultiTarget < mladapter
    properties
        Target
        Threshold
        Color
        WaitTime
        HoldTime
        TurnOffUnchosen = true
    end
    properties (SetAccess = protected)
        Running
        Waiting
        AcquiredTime
        ChosenTarget
    end
    properties (Access = protected)
        SingleTarget
        WaitThenHold
        nTarget
        TargetID
    end
    
    methods
        function obj = MultiTarget(varargin)
            obj = obj@mladapter(varargin{:});
            if 0==nargin, return, end

            obj.Target = [0 0; 0 0];
            obj.Threshold = 0;
            obj.Color = [0 1 0];
            obj.WaitTime = 0;
            obj.HoldTime = 0;
        end
        
        function set.Target(obj,target)
            [m,n] = size(target);
            if 1==m || 2~=n
                target = target(:)';
                modality = obj.Tracker.TaskObject.Modality(target);
                nonvisual = ~ismember(modality,[1 2]);
                if any(nonvisual), error('Target #%d is not visual',target(find(nonvisual,1))); end
                if ~isempty(obj.Target) && all(size(target)==size(obj.Target)) && all(target==obj.Target), return, end
                obj.Target = target;
                obj.nTarget = numel(obj.Target);
                obj.TargetID = obj.Tracker.TaskObject.ID(target); %#ok<*MCSUP>
            elseif 1<m && 2==n  % if target is a n-by-2 matrix (i.e., coordinates), take it as it is.
                obj.Target = target;
                obj.nTarget = size(target,1);
                obj.TargetID = [];
            else
                error('Target cannot be empty');
            end
            create_tracker(obj);
        end
        function set.Threshold(obj,threshold)
            if 0==numel(threshold) || 2<numel(threshold), error('Threshold must be a scalar or a 1-by-2 vector'); end
            threshold = threshold(:)';
            if ~isempty(obj.Threshold) && all(size(threshold)==size(obj.Threshold)) && all(threshold==obj.Threshold), return, end
            obj.Threshold = threshold;
            create_tracker(obj);
        end
        function set.Color(obj,color)
            if 3~=numel(color), error('Color must be a 1-by-3 vector'); end
            color = color(:)';
            if ~isempty(obj.Color) && all(color==obj.Color), return, end
            obj.Color = color;
            create_tracker(obj);
        end
        function set.WaitTime(obj,time)
            obj.WaitTime = time;
            create_tracker(obj);
        end
        function set.HoldTime(obj,time)
            obj.HoldTime = time;
            create_tracker(obj);
        end
        function set.TurnOffUnchosen(obj,val)
            obj.TurnOffUnchosen = logical(val);
        end
        
        function init(obj,p)
            init@mladapter(obj,p);
            for m=1:obj.nTarget, obj.WaitThenHold{m}.init(p); end

            obj.Running = true;
            obj.Waiting = true;
            obj.AcquiredTime = [];
            obj.ChosenTarget = [];
        end
        function fini(obj,p)
            fini@mladapter(obj,p);
            for m=1:obj.nTarget, obj.WaitThenHold{m}.fini(p); end
        end
        function continue_ = analyze(obj,p)
            analyze@mladapter(obj,p);
            if ~obj.Running, continue_ = false; return, end

            continue_ = false;
            for m=1:obj.nTarget
                continue_ = continue_ | obj.WaitThenHold{m}.analyze(p);
                if obj.Waiting && ~obj.WaitThenHold{m}.Waiting
                    obj.Waiting = false;
                    obj.AcquiredTime = obj.WaitThenHold{m}.AcquiredTime;
                    if obj.TurnOffUnchosen && ~isempty(obj.TargetID)
                        for n=find(obj.Target~=obj.Target(m))
                            mglactivategraphic(obj.TargetID(n),false);
                            obj.SingleTarget{n}.stop();
                            obj.WaitThenHold{n}.stop();
                        end
                    end
                end
                if obj.WaitThenHold{m}.Success
                    if isempty(obj.TargetID), obj.ChosenTarget = m; else, obj.ChosenTarget = obj.Target(m); end
                    obj.Running = false;
                    break
                end
            end
            obj.Success = ~isempty(obj.ChosenTarget);
        end
    end
    
    methods (Access = protected)
        function create_tracker(obj)
            if isempty(obj.Target) || isempty(obj.Threshold) || isempty(obj.WaitTime) || isempty(obj.HoldTime), return, end

            if length(obj.SingleTarget)~=obj.nTarget
                obj.SingleTarget = cell(1,obj.nTarget);
                obj.WaitThenHold = cell(1,obj.nTarget);
                for m=1:obj.nTarget
                    obj.SingleTarget{m} = SingleTarget(obj.Tracker); %#ok<CPROP>
                    obj.WaitThenHold{m} = WaitThenHold(obj.SingleTarget{m}); %#ok<CPROP>
                end
            end
            for m=1:obj.nTarget
                if isempty(obj.TargetID)
                    obj.SingleTarget{m}.Target = obj.Target(m,:);  % Target is coordinates
                else
                    obj.SingleTarget{m}.Target = obj.Target(m);    % Target is TaskObject
                end
                obj.SingleTarget{m}.Threshold = obj.Threshold;
                obj.SingleTarget{m}.Color = obj.Color;
                obj.WaitThenHold{m}.WaitTime = obj.WaitTime;
                obj.WaitThenHold{m}.HoldTime = obj.HoldTime;
            end
        end
    end
end
