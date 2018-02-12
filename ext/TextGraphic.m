classdef TextGraphic < Graphic
    properties
        Text = ''
        FontSize = 10                 % in points
        FontColor = [1 1 1]           % [r g b]
        FontFace = 'Arial'
        FontStyle = 'normal'          % bold, italic, underline, strikeout
        HorizontalAlignment = 'left'  % center, right
        VerticalAlignment = 'top'     % middle, bottom
    end
    methods
        function obj = TextGraphic(varargin)
            obj = obj@Graphic(varargin{:});
        end
        function set.Text(obj,val)
            if ~ischar(val), error('Text must be string'); end
            obj.Text = val;
            create_graphic(obj);
        end
        function set.FontSize(obj,val)
            if ~isscalar(val), error('FontSize must be a scalar'); end
            obj.FontSize = val;
            create_graphic(obj);
        end
        function set.FontColor(obj,val)
            if 3~=numel(val), error('FontColor must be a 1-by-3 vector'); end
            obj.FontColor = val(:)';
            create_graphic(obj);
        end
        function set.FontFace(obj,val)
            if ~ischar(val), error('FontFace must be string'); end
            obj.FontFace = val;
            create_graphic(obj);
        end
        function set.FontStyle(obj,val)
            switch lower(val)
                case {'normal','bold','italic','underline','strikeout'}, obj.FontStyle = val;
                otherwise, error('Unknown FontStyle!!!');
            end
            create_graphic(obj);
        end
        function set.HorizontalAlignment(obj,val)
            obj.HorizontalAlignment = val;
            create_graphic(obj);
        end
        function set.VerticalAlignment(obj,val)
            obj.VerticalAlignment = val;
            create_graphic(obj);
        end
    end
    methods (Access = protected)
        function create_graphic(obj)
            destroy_graphic(obj);
            if isempty(obj.Text), return, end
            obj.GraphicID = mgladdtext(obj.Text);
            mglsetproperty(obj.GraphicID,obj.FontStyle,'font',obj.FontFace,obj.FontSize,'color',obj.FontColor, ...
                'halign',obj.HorizontalAlignment,'valign',obj.VerticalAlignment);
            mglsetorigin(obj.GraphicID,obj.ScrPosition);
            mglactivategraphic(obj.GraphicID,false);
        end
    end
end
