classdef TrackerAggregate < handle
    properties (Access = protected)
        Tracker
    end
    
    methods
        function add(obj,tracker)
            if ~isa(tracker,'Tracker'), error('The 1st argument must be a Tracker'); end
            obj.Tracker{end+1} = tracker;
        end
        function init(obj,p)
            for m=1:length(obj.Tracker), obj.Tracker{m}.tracker_init(p); end
        end
        function fini(obj,p)
            for m=1:length(obj.Tracker), obj.Tracker{m}.tracker_fini(p); end
        end
        function acquire(obj,p)
            for m=1:length(obj.Tracker), obj.Tracker{m}.acquire(p); end
        end
    end
end
