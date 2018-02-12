classdef CurveTracer < mladapter
    properties
        Target                 % TaskObject number
        Trajectory             % [x y], n-by-2
        AnalysisWindow = 1000  % msec
        Step = 1               % every n frames
    end
    properties (SetAccess = protected)
        TargetLocation
    end
    properties (Access = protected)
        TargetID
        PaddedTrajectory
        ScrPaddedTrajectory
        MaxFrame
    end
    
    methods
        function obj = CurveTracer(varargin)
            obj = obj@mladapter(varargin{:});
        end
        
        function set.Target(obj,val)
            if ~isscalar(val), error('Target must be a TaskObject number'); end
            modality = obj.Tracker.TaskObject.Modality(val);
            if 1~=modality && 2~=modality, error('Target #%d is not visual',val); end
            obj.Target = val;
            obj.TargetID = obj.Tracker.TaskObject.ID(val); %#ok<*MCSUP>
        end
        function set.Trajectory(obj,val)
            if 2~=size(val,2), error('Trajectory must be a n-by-2 matrix'); end
            obj.Trajectory = val;
            pad_trajectory(obj);
        end
        function set.AnalysisWindow(obj,val)
            if ~isscalar(val), error('AnalysisWindow must be a scalar'); end
            if val <= 0, error('AnalysisWindow must be a positive integer'); end
            obj.AnalysisWindow = val;
            pad_trajectory(obj);
        end
        function set.Step(obj,val)
            if ~isscalar(val), error('Step must be a scalar'); end
            if val <= 0, error('Step must be a positive integer'); end
            obj.Step = val;
            pad_trajectory(obj);
        end
        
        function continue_ = analyze(obj,p)
            analyze@mladapter(obj,p);

            frame_no = p.scene_frame();  % 0-based
            continue_ = frame_no < obj.MaxFrame;
            if continue_
                frame_idx = floor(frame_no/obj.Step);
                if 0==frame_idx, obj.TargetLocation = obj.PaddedTrajectory(1,:); else obj.TargetLocation = obj.PaddedTrajectory(frame_idx,:); end
                mglsetorigin(obj.TargetID,obj.ScrPaddedTrajectory(frame_idx+1,:));
            end
        end
    end
    
    methods (Access = protected)
        function pad_trajectory(obj)
            if isempty(obj.Trajectory), return, end
            padding = ceil(obj.AnalysisWindow / obj.Tracker.Screen.FrameLength) / obj.Step;
            if round(padding)~=padding, error('AnalysisWindow is not a multiple of the screen update interval (FrameLength * Step)'); end
            obj.PaddedTrajectory = [repmat(obj.Trajectory(1,:),padding,1); obj.Trajectory];
            obj.ScrPaddedTrajectory = obj.Tracker.CalFun.deg2pix(obj.PaddedTrajectory);
            obj.MaxFrame = size(obj.PaddedTrajectory,1) * obj.Step;
        end
    end
end
