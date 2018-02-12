classdef Tracker < mladapter
    properties (SetAccess = protected)
        Signal = ''
        Screen
        DAQ
        TaskObject
        CalFun
        DataSource
    end
    
    methods (Abstract)
        tracker_init(obj,p)
        tracker_fini(obj,p)
        acquire(obj,p)
    end
    
    methods
        function obj = Tracker(varargin)  % MLConfig, TaskObject, CalFun
            if 4~=nargin, return, end
            MLConfig = varargin{1};
            TaskObject = varargin{2};
            CalFun = varargin{3};
            DataSource = double(varargin{4});
            
            obj.Success = true;
            obj.Screen = MLConfig.Screen;
            obj.DAQ = MLConfig.DAQ;
            obj.TaskObject = TaskObject;
            obj.CalFun = CalFun;
            obj.DataSource = DataSource;
        end
        
        function init(~,~), end
        function fini(~,~), end
        function continue_ = analyze(~,~), continue_ = true; end
        function draw(~,~), end

        function o = get_adapter(obj,name)
            if isa(obj,name), o = obj; else, o = []; end
        end
        function o = tracker(obj)
            o = obj;
        end
        function info(obj,s)
            s.AdapterList{end+1} = class(obj);
            s.AdapterArgs{end+1} = obj.export();
        end
    end
end
