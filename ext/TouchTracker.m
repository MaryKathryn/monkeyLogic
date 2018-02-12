classdef TouchTracker < Tracker
    properties
        TracerImage
        TracerShape
        TracerColor
        TracerSize
    end
    properties (SetAccess = protected)
        XYData
        ClickData
        MouseData
        LastSamplePosition
    end
    
    methods
        function obj = TouchTracker(varargin)  % MLConfig, TaskObject, CalFun, datasource
            obj = obj@Tracker(varargin{:});
            if 4~=nargin, return, end
            
            MLConfig = varargin{1};
            if 0==obj.DataSource && ~MLConfig.DAQ.mouse_present, error('Enable Touch first!!!'); end

            obj.Signal = 'Touch';
            obj.TracerImage = MLConfig.TouchCursorImage;
            obj.TracerShape = MLConfig.TouchCursorShape;
            obj.TracerColor = MLConfig.TouchCursorColor;
            obj.TracerSize = MLConfig.TouchCursorSize;
        end

        function set.TracerImage(obj,filepath)
            filepath = char(filepath);
            if ~isempty(filepath) && 2~=exist(filepath,'file'), error('Imagefile does not exist'); end
            obj.TracerImage = filepath;
            create_tracer(obj);
        end
        function set.TracerShape(obj,shape)
            switch lower(shape)
                case {2,'circle'}, shape = 'Circle';
                case {3,'square'}, shape = 'Square';
                otherwise, error('Unknown TracerShape!!!');
            end
            if strcmp(obj.TracerShape,shape), return, end
            obj.TracerShape = shape;
            create_tracer(obj);
        end
        function set.TracerColor(obj,color)
            if 3~=numel(color), error('TracerColor must be a 1-by-3 vector'); end
            color = color(:)';
            if ~isempty(obj.TracerColor) && all(color==obj.TracerColor), return, end
            obj.TracerColor = color;
            create_tracer(obj);
        end
        function set.TracerSize(obj,sz)
            if ~isscalar(sz), error('TracerSize must be a scalar'); end
            if sz==obj.TracerSize, return, end
            obj.TracerSize = sz;
            create_tracer(obj);
        end
        
        function tracker_init(~,~)
        end
        function tracker_fini(obj,~)
            mglactivategraphic(obj.Screen.TouchCursor,false);
        end
        function acquire(obj,p)
            switch obj.DataSource
                case 0
                    if ~isempty(p.DAQ.Mouse)
                        obj.XYData = obj.CalFun.subject2pix(p.DAQ.Mouse);
                        obj.MouseData = obj.XYData;
                        obj.ClickData{1} = p.DAQ.MouseButton(:,1);
                        obj.ClickData{2} = p.DAQ.MouseButton(:,2);
                        obj.XYData(~obj.ClickData{1},:) = NaN;
                    end
                    obj.LastSamplePosition = p.DAQ.LastSamplePosition;
                case 1
                    [mouse,button] = getsample(p.Mouse);
                    if ~isempty(mouse)
                        obj.XYData = obj.CalFun.control2pix(mouse);
                        obj.MouseData = obj.XYData;
                        obj.ClickData{1} = button(1);
                        obj.ClickData{2} = button(2);
                        obj.XYData(~obj.ClickData{1},:) = NaN;
                    end
                    obj.LastSamplePosition = floor(p.trialtime());
                case 2
                    if ~isempty(p.DAQ.Mouse)
                        obj.XYData = obj.CalFun.deg2pix(p.DAQ.Mouse);
                        obj.MouseData = obj.XYData;
                        obj.ClickData{1} = p.DAQ.MouseButton(:,1);
                        obj.ClickData{2} = p.DAQ.MouseButton(:,2);
                        obj.XYData(~obj.ClickData{1},:) = NaN;
                    end
                    obj.LastSamplePosition = floor(p.trialtime() - size(obj.ClickData{1},1));
                otherwise, error('Unknown data source!!!');
            end
            
            if ~isempty(obj.XYData)
                obj.Success = true;
                if any(isnan(obj.XYData(end,:)))
                    mglactivategraphic(obj.Screen.TouchCursor,false);
                else
                    mglactivategraphic(obj.Screen.TouchCursor,true);
                    mglsetorigin(obj.Screen.TouchCursor,obj.XYData(end,:));
                end
            else
                obj.Success = false;
            end
        end
    end
    
    methods (Access = protected)
        function create_tracer(obj)
            if isempty(obj.TracerImage) && (isempty(obj.TracerShape) || isempty(obj.TracerColor) || isempty(obj.TracerSize)), return, end
            destroy_tracer(obj);
            obj.Screen.TouchCursor = load_cursor(obj.TracerImage,obj.TracerShape,obj.TracerColor,obj.TracerSize,10);
            mglactivategraphic(obj.Screen.TouchCursor,false);
        end
        function destroy_tracer(obj)
            if ~isempty(obj.Screen.TouchCursor), mgldestroygraphic(obj.Screen.TouchCursor); obj.Screen.TouchCursor = []; end
        end
    end
end
