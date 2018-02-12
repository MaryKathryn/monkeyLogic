%This script is to create an Adapter that sends a command to UDK and wait
%for its execution

%For example sending the PreStartTrialEvent

classdef UE_SendMessage < mladapter
    properties
        PendingMessage = [];
    end
    properties (SetAccess = protected)
        Running
        Time
    end
    properties (Access = protected)
       
    end
    
    methods
        function obj = UE_SendMessage(varargin)
            obj = obj@mladapter(varargin{:});
        end
        function delete(obj) %#ok<*INUSD>
            % Nothing
        end
        
        function set.PendingMessage(obj,message)
            
            %Send pending message to send to TCP Tracker
            obj.PendingMessage = message;
            
        end
        
        function init(obj,p)
            obj.Adapter.init(p);
            obj.Success = [];
            obj.Running = true;
        end
        
        function fini(obj,p)
            obj.Adapter.fini(p);
        end
        
        function continue_ = analyze(obj,p)
            obj.Adapter.analyze(p);
            if ~obj.Running, continue_ = false; return, end
            
            if ~isempty(p.SceneStartTime) % SCENE has started
                out = obj.Tracker.TrackerMessage(obj.PendingMessage);
            else
               out = 0; 
            end
            
            if out
                continue_ = 0;
                obj.Success = 1;
            else
                continue_ = 1;
                obj.Success = 0;
            end
            
        end
        function stop(obj)
            obj.Running = false;
        end
    end
    
    methods (Access = protected)
        
    end
end
