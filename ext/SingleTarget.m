classdef SingleTarget < mladapter
    properties
        Target = [0 0];
        Threshold = 0;
        Color = [0 1 0];
    end
    properties (SetAccess = protected)
        Running
        Position
        Time
    end
    properties (Access = protected)
        LastData
        LastCrossTime
        
        FixWindowID
        ScreenPosition
        ThresholdInPixels
    end
    
    methods
        function obj = SingleTarget(varargin)
            obj = obj@mladapter(varargin{:});
        end
        function delete(obj)
            destroy_fixwindow(obj);
        end
        
        function set.Target(obj,target)
            if isscalar(target)
                modality = obj.Tracker.TaskObject.Modality(target);
                if 1~=modality && 2~=modality, error('Target #%d is not visual',target); end
                obj.Target = target;
                obj.Position = obj.Tracker.TaskObject.Position(obj.Target,:); %#ok<*MCSUP>
                obj.ScreenPosition = obj.Tracker.TaskObject.ScreenPosition(obj.Target,:);
            elseif 2==numel(target)
                obj.Target = target(:)';
                obj.Position = obj.Target;
                obj.ScreenPosition = obj.Tracker.CalFun.deg2pix(target);
            else
                error('Target must be a scalar or a 2-element vector');
            end
            create_fixwindow(obj);
        end
        function set.Threshold(obj,threshold)
            if 0==numel(threshold) || 2<numel(threshold), error('Threshold must be a scalar or a 1-by-2 vector'); end
            threshold = threshold(:)';
            if ~isempty(obj.Threshold) && all(size(threshold)==size(obj.Threshold)) && all(threshold==obj.Threshold), return, end
            obj.Threshold = threshold;
            create_fixwindow(obj);
        end
        function set.Color(obj,color)
            if 3~=numel(color), error('Color must be a 1-by-3 vector'); end
            color = color(:)';
            if ~isempty(obj.Color) && all(color==obj.Color), return, end
            obj.Color = color;
            create_fixwindow(obj);
        end
        
        function init(obj,p)
            init@mladapter(obj,p);
            obj.Running = true;
            obj.LastCrossTime = 0;
            mglactivategraphic(obj.FixWindowID,true);
        end
        function fini(obj,p)
            fini@mladapter(obj,p);
            mglactivategraphic(obj.FixWindowID,false);
        end
        function continue_ = analyze(obj,p)
            analyze@mladapter(obj,p);
            if ~obj.Running, continue_ = false; return, end
            
            data = obj.Tracker.XYData;
            ndata = size(data,1);
            if 0==ndata, continue_ = true; return, end
            
            if isscalar(obj.ThresholdInPixels)
                in = sum((data-repmat(obj.ScreenPosition,ndata,1)).^2,2) < obj.ThresholdInPixels;
            else
                rc = obj.ThresholdInPixels;
                in = rc(1)<data(:,1) & data(:,1)<rc(3) & rc(2)<data(:,2) & data(:,2)<rc(4);
            end
            
            d = diff([obj.LastData; in]);
            d(isnan(d)) = false;  % for touch input
            t = find(-1==d|1==d,1,'last');
            
            if isempty(t)
                obj.Success = in(end);
                obj.Time = obj.LastCrossTime;
            else
                obj.LastCrossTime = obj.Tracker.LastSamplePosition + t;
            end
            continue_ = ~obj.Success;
            obj.LastData = in(end);
        end
        function stop(obj)
            mglactivategraphic(obj.FixWindowID,false);
            obj.Running = false;
        end
    end
    
    methods (Access = protected)
        function create_fixwindow(obj)
            if isempty(obj.ScreenPosition) || isempty(obj.Threshold), return, end
            destroy_fixwindow(obj);
            
            threshold_in_pixels = obj.Threshold * obj.Tracker.Screen.PixelsPerDegree;
            if isscalar(obj.Threshold)
                obj.FixWindowID = mgladdcircle(obj.Color,threshold_in_pixels*2,10);
                obj.ThresholdInPixels = threshold_in_pixels^2;
            else
                obj.FixWindowID = mgladdbox(obj.Color,threshold_in_pixels,10);
                obj.ThresholdInPixels = [obj.ScreenPosition-0.5*threshold_in_pixels obj.ScreenPosition+0.5*threshold_in_pixels];
            end
            mglsetorigin(obj.FixWindowID,obj.ScreenPosition);
            mglactivategraphic(obj.FixWindowID,false);
        end
        function destroy_fixwindow(obj)
            if ~isempty(obj.FixWindowID), mgldestroygraphic(obj.FixWindowID); obj.FixWindowID = []; end
        end
    end
end
