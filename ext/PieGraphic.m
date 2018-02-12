classdef PieGraphic < Graphic
    properties
        StartDegree = 0
        CenterAngle = 0
    end
    
    methods
        function obj = PieGraphic(varargin)
            obj = obj@Graphic(varargin{:});
        end
        function set.StartDegree(obj,val)
            if ~isscalar(val), error('StartDegree must be a scalar'); end
            obj.StartDegree = val;
            create_graphic(obj);
        end
        function set.CenterAngle(obj,val)
            if ~isscalar(val), error('CenterAngle must be a scalar'); end
            obj.CenterAngle = val;
            create_graphic(obj);
        end
    end
    
    methods (Access = protected)
        function create_graphic(obj)
            destroy_graphic(obj);
            obj.GraphicID = mgladdpie([obj.EdgeColor; obj.FaceColor],obj.ScrSize,obj.StartDegree,obj.CenterAngle);
            mglsetorigin(obj.GraphicID,obj.ScrPosition);
            mglactivategraphic(obj.GraphicID,false);
        end
    end
end
