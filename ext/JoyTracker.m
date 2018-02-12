classdef JoyTracker < Tracker
    properties
        TracerImage
        TracerShape
        TracerColor
        TracerSize
    end
    properties (SetAccess = protected)
        XYData
        LastSamplePosition
    end
    
    methods
        function obj = JoyTracker(varargin)  % MLConfig, TaskObject, CalFun, datasource
            obj = obj@Tracker(varargin{:});
            if 4~=nargin, return, end
            
            MLConfig = varargin{1};
            if 0==obj.DataSource && ~MLConfig.DAQ.joystick_present, error('No joystick input defined!!!'); end

            obj.Signal = 'Joystick';
            obj.TracerImage = MLConfig.JoystickCursorImage;
            obj.TracerShape = MLConfig.JoystickCursorShape;
            obj.TracerColor = MLConfig.JoystickCursorColor;
            obj.TracerSize = MLConfig.JoystickCursorSize;
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
        
        function tracker_init(obj,p)
            mglactivategraphic(obj.Screen.JoystickCursor,[p.ShowJoyCursor ~p.SimulationMode|p.ShowJoyCursor]);
        end
        function tracker_fini(obj,~)
            mglactivategraphic(obj.Screen.JoystickCursor,false);
        end
        function acquire(obj,p)
            switch obj.DataSource
                case 0, data = p.DAQ.Joystick;          if ~isempty(data), obj.XYData = obj.CalFun.sig2pix(data,p.JoyOffset); end, obj.LastSamplePosition = p.DAQ.LastSamplePosition;
                case 1, data = p.DAQ.SimulatedJoystick; if ~isempty(data), obj.XYData = obj.CalFun.deg2pix(data); end, obj.LastSamplePosition = floor(p.trialtime()-1);
                case 2, data = p.DAQ.Joystick;          if ~isempty(data), obj.XYData = obj.CalFun.deg2pix(data); end, obj.LastSamplePosition = floor(p.trialtime() - size(data,1));
                otherwise, error('Unknown data source!!!');
            end
            
            if ~isempty(obj.XYData)
                obj.Success = true;
                mglsetorigin(obj.Screen.JoystickCursor,obj.XYData(end,:));
            else
                obj.Success = false;
            end
        end
    end
    
    methods (Access = protected)
        function create_tracer(obj)
            if isempty(obj.TracerImage) && (isempty(obj.TracerShape) || isempty(obj.TracerColor) || isempty(obj.TracerSize)), return, end
            destroy_tracer(obj);
            obj.Screen.JoystickCursor = [load_cursor(obj.TracerImage,obj.TracerShape,obj.TracerColor,obj.TracerSize,9) ...
                load_cursor(obj.TracerImage,obj.TracerShape,obj.TracerColor,obj.TracerSize,10)];
            mglactivategraphic(obj.Screen.JoystickCursor,false);
        end
        function destroy_tracer(obj)
            if ~isempty(obj.Screen.JoystickCursor), mgldestroygraphic(obj.Screen.JoystickCursor); obj.Screen.JoystickCursor = []; end
        end
    end
end
