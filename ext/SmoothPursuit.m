classdef SmoothPursuit < mladapter
    properties
        Target              % TaskObject number
        Threshold = 0;      % fixation window size in visual degrees
        Color = [0 1 0];    % fixation window color
        Origin              % [xdeg ydeg]
        Direction           % 0 to 360 deg
        Speed               % deg/s
        Duration            % msec
    end
    properties (SetAccess = protected)
        Time
    end
    properties (Access = protected)
        TargetID
        FixWindowID
        ThresholdInPixels
        ScrOrigin
        ScrDisplacement
        ScrTarget
    end
    
    methods
        function obj = SmoothPursuit(varargin)
            obj = obj@mladapter(varargin{:});
        end
        function delete(obj)
            destroy_fixwindow(obj);
        end
        
        function set.Target(obj,target)
            if ~isscalar(target), error('Target must be a TaskObject number'); end
            modality = obj.Tracker.TaskObject.Modality(target);
            if 1~=modality && 2~=modality, error('Target #%d is not visual',target); end
            obj.Target = target;
            obj.TargetID = obj.Tracker.TaskObject.ID(target); %#ok<*MCSUP>
        end
        function set.Threshold(obj,threshold)
            if ~isscalar(threshold), error('Threshold must be a scalar'); end
            if ~isempty(obj.Threshold) && threshold==obj.Threshold, return, end
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
        function set.Origin(obj,val)
            if 2~=length(val), error('Origin must be a 1-by-2 vector'); end
            obj.Origin = val(:)';
            calculate_displacement(obj);
        end
        function set.Direction(obj,val)
            if 1~=numel(val), error('Direction must be a scalar'); end
            obj.Direction = val;
            calculate_displacement(obj);
        end
        function set.Speed(obj,val)
            if 1~=numel(val), error('Speed must be a scalar'); end
            obj.Speed = val;
            calculate_displacement(obj);
        end
        
        function init(obj,p)
            init@mladapter(obj,p);
            mglactivategraphic([obj.TargetID obj.FixWindowID],true);
        end
        function fini(obj,p)
            fini@mladapter(obj,p);
            mglactivategraphic([obj.TargetID obj.FixWindowID],false);
        end
        function continue_ = analyze(obj,p)
            analyze@mladapter(obj,p);

            obj.ScrTarget = obj.ScrOrigin + p.scene_frame() * obj.ScrDisplacement;

            continue_ = true;
            if p.scene_time() < obj.Duration
                data = obj.Tracker.XYData;
                ndata = size(data,1);
                if 0==ndata, return, end
                
                in = find(obj.ThresholdInPixels < sum((data-repmat(obj.ScrTarget,ndata,1)).^2,2),1);
                if ~isempty(in)
                    obj.Time = obj.Tracker.LastSamplePosition + in;
                    continue_ = false;
                    return
                end
            else
                obj.Success = true;
                continue_ = false;
            end
        end
        function draw(obj,p)
            draw@mladapter(obj,p);
            mglsetorigin(obj.TargetID,obj.ScrTarget);
            mglsetorigin(obj.FixWindowID,obj.ScrTarget);
        end
    end
    
    methods (Access = protected)
        function create_fixwindow(obj)
            if isempty(obj.Threshold), return, end
            destroy_fixwindow(obj);
            
            threshold_in_pixels = obj.Threshold * obj.Tracker.Screen.PixelsPerDegree;
            obj.FixWindowID = mgladdcircle(obj.Color,threshold_in_pixels*2,10);
            obj.ThresholdInPixels = threshold_in_pixels^2;
            mglactivategraphic(obj.FixWindowID,false);
        end
        function destroy_fixwindow(obj)
            if ~isempty(obj.FixWindowID), mgldestroygraphic(obj.FixWindowID); obj.FixWindowID = []; end
        end
        function calculate_displacement(obj)
            if isempty(obj.Origin) || isempty(obj.Direction) || isempty(obj.Speed), return, end
            obj.ScrOrigin = obj.Tracker.CalFun.deg2pix(obj.Origin);
            obj.ScrDisplacement = [cosd(obj.Direction) -sind(obj.Direction)] * obj.Speed * obj.Tracker.Screen.PixelsPerDegree / obj.Tracker.Screen.RefreshRate;
        end
    end
end
