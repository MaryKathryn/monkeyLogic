classdef Graphic < mladapter
    properties
        EdgeColor = [1 1 1]
        FaceColor = [1 1 1]
        Size = [0 0]
        Position = [0 0]
    end
    properties (Access = protected)
        GraphicID
        ScrSize = [0 0]
        ScrPosition = [0 0]
    end
    
    methods (Abstract, Access = protected)
        create_graphic(obj)
    end
    
    methods
        function obj = Graphic(varargin)
            obj = obj@mladapter(varargin{:});
        end
        function delete(obj)
            destroy_graphic(obj);
        end
        
        function set.EdgeColor(obj,val)
            if 3~=numel(val), error('EdgeColor must be a 1-by-3 vector'); end
            if isempty(val) || any(val<0) || any(isnan(val)), val = [NaN NaN NaN]; end
            obj.EdgeColor = val(:)';
            create_graphic(obj);
        end
        function set.FaceColor(obj,val)
            if 3~=numel(val), error('FaceColor must be a 1-by-3 vector'); end
            if isempty(val) || any(val<0) || any(isnan(val)), val = [NaN NaN NaN]; end
            obj.FaceColor = val(:)';
            create_graphic(obj);
        end
        function set.Size(obj,val)
            if 1~=numel(val) && 2~=numel(val), error('Size must be a scalar or a 1-by-2 vector'); end
            if isscalar(val), obj.Size = [val val]; else, obj.Size = val(:)'; end
            obj.ScrSize = obj.Size * obj.Tracker.Screen.PixelsPerDegree; %#ok<*MCSUP>
            create_graphic(obj);
        end
        function set.Position(obj,val)
            if 2~=numel(val), error('Position must be a 1-by-2 vector'); end
            obj.Position = val;
            obj.ScrPosition = obj.Tracker.CalFun.deg2pix(val(:)');
            create_graphic(obj);
        end
        
        function init(obj,p)
            init@mladapter(obj,p);
            if isempty(obj.GraphicID), create_graphic(obj); end
            mglactivategraphic(obj.GraphicID,true);
        end
        function fini(obj,p)
            fini@mladapter(obj,p);
            mglactivategraphic(obj.GraphicID,false);
        end
        function continue_ = analyze(obj,p)
            continue_ = analyze@mladapter(obj,p);
            obj.Success = obj.Adapter.Success;
        end
    end
    
    methods (Access = protected)
        function destroy_graphic(obj)
            if ~isempty(obj.GraphicID), mgldestroygraphic(obj.GraphicID); obj.GraphicID = []; end
        end
    end
end
