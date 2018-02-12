classdef NullTracker < Tracker
    methods
        function obj = NullTracker(varargin)  % MLConfig, TaskObject, CalFun
            obj = obj@Tracker(varargin{:});
            obj.Signal = 'Null';
        end
        function tracker_init(~,~), end
        function tracker_fini(~,~), end
        function acquire(~,~), end
    end
end
