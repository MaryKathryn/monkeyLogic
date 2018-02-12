classdef PolygonGraphic < Graphic
    properties
        Vertex = [0 0; 0 1; 1 1; 1 0]
    end
    
    methods
        function obj = PolygonGraphic(varargin)
            obj = obj@Graphic(varargin{:});
        end
        function set.Vertex(obj,val)
            [m,n] = size(val);
            if m<2 || 2~=n, error('Vertex must be a n-by-2 vector (1<n)'); end
            obj.Vertex = val;
            create_graphic(obj);
        end
    end
    
    methods (Access = protected)
        function create_graphic(obj)
            destroy_graphic(obj);
            obj.GraphicID = mgladdpolygon([obj.EdgeColor; obj.FaceColor],obj.ScrSize,[obj.Vertex(:,1) 1-obj.Vertex(:,2)]);
            mglsetorigin(obj.GraphicID,obj.ScrPosition);
            mglactivategraphic(obj.GraphicID,false);
        end
    end
end
