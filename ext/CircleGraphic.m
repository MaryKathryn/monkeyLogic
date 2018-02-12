classdef CircleGraphic < Graphic
    methods
        function obj = CircleGraphic(varargin)
            obj = obj@Graphic(varargin{:});
        end
    end
    methods (Access = protected)
        function create_graphic(obj)
            destroy_graphic(obj);
            obj.GraphicID = mgladdcircle([obj.EdgeColor; obj.FaceColor],obj.ScrSize);
            mglsetorigin(obj.GraphicID,obj.ScrPosition);
            mglactivategraphic(obj.GraphicID,false);
        end
    end
end
