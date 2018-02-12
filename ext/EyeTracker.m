classdef EyeTracker < Tracker
    properties
        TracerShape
        TracerColor
        TracerSize
    end
    properties (SetAccess = protected)
        XYData
        LastSamplePosition
    end
    
    methods
        function obj = EyeTracker(varargin)  % MLConfig, TaskObject, CalFun, datasource
            obj = obj@Tracker(varargin{:});
            if 4~=nargin, return, end
            
            MLConfig = varargin{1};
            if 0==obj.DataSource && ~MLConfig.DAQ.eye_present, error('No eye signal input defined!!!'); end
            
            obj.Signal = 'Eye';
            obj.TracerShape = MLConfig.EyeTracerShape;
            obj.TracerColor = MLConfig.EyeTracerColor;
            obj.TracerSize = MLConfig.EyeTracerSize;
        end
        
        function set.TracerShape(obj,shape)
            switch lower(shape)
                case {1,'line'}, shape = 'Line';
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
        
        function tracker_init(obj,~)
            mglactivategraphic(obj.Screen.EyeTracer,true);
        end
        function tracker_fini(obj,~)
            mglactivategraphic(obj.Screen.EyeTracer,false);
        end
        function acquire(obj,p)
            switch obj.DataSource
                case 0, data = p.DAQ.Eye;          if ~isempty(data), obj.XYData = obj.CalFun.sig2pix(data,p.EyeOffset); end, obj.LastSamplePosition = p.DAQ.LastSamplePosition;
                case 1, data = getsample(p.Mouse); if ~isempty(data), obj.XYData = obj.CalFun.control2pix(data); end, obj.LastSamplePosition = floor(p.trialtime()-1);
                case 2, data = p.DAQ.Eye;          if ~isempty(data), obj.XYData = obj.CalFun.deg2pix(data); end, obj.LastSamplePosition = floor(p.trialtime() - size(data,1));
                otherwise, error('Unknown data source!!!');
            end
            
            if ~isempty(obj.XYData)
                obj.Success = true;
                if obj.Screen.EyeLineTracer
                    mglsetproperty(obj.Screen.EyeTracer,'addpoint',obj.XYData);
                else
                    mglsetorigin(obj.Screen.EyeTracer,obj.XYData(end,:));
                end
            else
                obj.Success = false;
            end
        end
    end
    
    methods (Access = protected)
        function create_tracer(obj)
            if isempty(obj.TracerShape) || isempty(obj.TracerColor) || isempty(obj.TracerSize), return, end
            switch obj.TracerShape
                case 'Line'
                    if 1==obj.DataSource, npoint = 10; else, npoint = 50; end
                    obj.Screen.EyeTracer = mgladdline(obj.TracerColor,npoint,1,10);
                otherwise
                    obj.Screen.EyeTracer = load_cursor('',obj.TracerShape,obj.TracerColor,obj.TracerSize,10);
            end
            mglactivategraphic(obj.Screen.EyeTracer,false);
        end
    end
end
