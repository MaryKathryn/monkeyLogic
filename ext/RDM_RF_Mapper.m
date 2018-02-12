classdef RDM_RF_Mapper < RandomDotMotion
    properties (Access = protected)
        LB_Hold
        RB_Hold
        Picked
        ApertureResize
        PickedPosition
        PickedRadius
    end
    methods
        function obj = RDM_RF_Mapper(varargin)
            obj = obj@RandomDotMotion(varargin{:});
        end
        function init(obj,p)
            init@mladapter(obj,p);
            mglactivategraphic(obj.DotID,true);
            obj.LB_Hold = false;
            obj.RB_Hold = false;
            obj.Picked = false;
            obj.ApertureResize = false;
        end
        function continue_ = analyze(obj,p)
            continue_ = analyze@mladapter(obj,p);
            obj.Success = obj.Adapter.Success;
            
            % get the mouse position and calculate its polar coordinates
            xydeg = obj.Tracker.CalFun.pix2deg(obj.Tracker.MouseData(end,:));
            r = realsqrt(sum((xydeg-obj.Position).^2));
            theta = sign(xydeg(2)-obj.Position(2)) * acosd((xydeg(1)-obj.Position(1))/r);
            
            LB_Down = obj.Tracker.ClickData{1}(end);
            if ~obj.LB_Hold && LB_Down, obj.Picked = true;  obj.LB_Hold = true; obj.PickedPosition = xydeg - obj.Position; end
            if obj.LB_Hold && ~LB_Down, obj.Picked = false; obj.LB_Hold = false; end
            if obj.Picked, obj.Position = xydeg - obj.PickedPosition; end
            
            RB_Down = obj.Tracker.ClickData{2}(end);
            if ~obj.RB_Hold && RB_Down, obj.ApertureResize = true;  obj.RB_Hold = true; obj.PickedRadius = r - obj.Radius; end
            if obj.RB_Hold && ~RB_Down, obj.ApertureResize = false; obj.RB_Hold = false; end
            if obj.ApertureResize
                apsize = r - obj.PickedRadius;
                if 0<apsize, obj.Radius = apsize; end
            end

            if ~obj.Picked && ~obj.ApertureResize && ~isnan(theta), obj.Direction = theta; end
            
            if 0<=r, obj.Speed = r; end

            % display some information on the control screen
            p.dashboard(1,sprintf('Position = [%.1f %.1f]',obj.Position));
            p.dashboard(2,sprintf('Direction = %.1f',obj.Direction));
            p.dashboard(3,sprintf('Speed = %.1f',obj.Speed));
        end
    end
end
