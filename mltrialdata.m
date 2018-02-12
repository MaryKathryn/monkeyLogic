classdef mltrialdata < handle
    properties
        Trial
        Block
        TrialWithinBlock
        Condition
        TrialError
        ReactionTime
        AbsoluteTrialStartTime
        TrialDateTime
        BehavioralCodes
        AnalogData
        ObjectStatusRecord
        RewardRecord
        UserVars
        VariableChanges
        TaskObject
        CycleRate
        Ver
    end
    properties (Transient = true, Hidden = true)
        InterTrialInterval
        UserMessage
        NewEyeTransform
    end
    
    methods
        function obj = mltrialdata()
            obj.Ver = 1;
        end
        function export_to_file(obj,filename,varname)
            if ~exist('varname','var'), varname = sprintf('Trial%d',obj.Trial); end
            try
                [~,~,e] = fileparts(filename);
                switch lower(e)
                    case '.bhv2', fid = mlbhv2(filename,'a');
                    case '.h5', fid = mlhdf5(filename,'a');
                    otherwise, fid = mlmat(filename);
                end
                fid.write(obj,varname);
                close(fid);
            catch err
                if exist('fid','var'), close(fid); end
                rethrow(err);
            end
        end            
    end
end
