%This object is an interface between the task specific adapters (e.g.
%UE_GoalTouch, UE_SendMessage) and the mltcp object holding the python link
%with the UE. Most of its functions are relay to send task specific
%commands, events or info to the Python link. 

classdef TcpTracker < Tracker
    properties
        %Sampling properties
        currentData = {};
    end
    properties (SetAccess = protected)
        TCP_holder
    end
    properties (Access = protected)

    end
    
    methods
        %Creator function =================================================
        function obj = TcpTracker(varargin)  % MLConfig, TaskObject
            
            %creates the TcpTracker object from the superclass "Tracker"
            obj = obj@Tracker(varargin{:});
            if 2~=nargin, return, end
            
            MLConfig = varargin{1};
            obj.TCP_holder = MLConfig.TCP; %holds the pointer to mltcp object
            obj.Signal = 'UE';
            
        end
        
        %Gets executed at the start of each scene
        %(trialholder_v2::run_scene())
        function tracker_init(obj,~)
            
            %clear Unreal Engine data
            obj.currentData = {};

        end
        
        %gets executed at the end of each scene
        %(trialholder_v2::run_scene())
        function tracker_fini(obj,p)
            %clear Unreal Engine data
            obj.currentData = {};
        end

        %called during run_scene to acquire data from the mltcp object
        function acquire(obj,p)
            
            obj.currentData = obj.TCP_holder.getLatestSample();
        end
        
        %relays the message to mltcp
        function out = SendMessage(obj, Message)
           [out] = obj.TCP_holder.SendMessage(Message);
        end
        
        %Map change function. The reconnection is handled by the python
        %bridge
        function out = MapChange(obj, Map)
            [out] = obj.TCP_holder.MapChange(Map);
        end
        
        %Toggle Fixaiton point and speed change
        function out = SetFixAndSpeed(obj, Fix, Speed)
            [out] = obj.TCP_holder.SetFixAndSpeed(Fix, Speed);
        end
        
        %Sends subject to black
        function OnBlack(obj)
            obj.TCP_holder.OnBlack();
        end
        
        %PreStartTrial
        function out = TrackerMessage(obj, PreStartMessage)
            out = obj.TCP_holder.TrackerMessage(PreStartMessage);
        end
        
        %End of trial event in UE
        function out = EndTrial(obj)
            out = obj.TCP_holder.EndTrial();
            obj.currentData = {};
        end
        
        %Clears current data
        function ClearData(obj)
           obj.currentData = {}; 
        end
    end
end
