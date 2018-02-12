classdef mltrialrecord < handle
    properties (SetAccess = protected)
        CurrentTrialNumber
        CurrentTrialWithinBlock
        CurrentCondition
        CurrentBlock
        CurrentBlockCount
        CurrentConditionInfo
        CurrentConditionStimulusInfo
        ConditionsPlayed
        ConditionsThisBlock
        BlocksPlayed
        BlockCount
        BlockOrder
        BlocksSelected
        TrialErrors
        ReactionTimes
        LastTrialAnalogData
        LastTrialCodes
    end
    properties
        SimulationMode
        BlockChange
        Pause
        Quit
        User
    end
    properties (Hidden = true)
        TestTrial
        DataFile
        TaskInfo
    end
    properties (SetAccess = protected, Hidden = true)
        ErrorLogic
        CondLogic
        BlockLogic
        CondSelectFunction
        BlockSelectFunction
        BlockChangeFunction
        NumberOfTrialsToRunInThisBlock
        CountOnlyCorrectTrials
        BlocksToRun
        TotalNumberOfTrialsToRun
        TotalNumberOfBlocksToRun
        MLConditions
        
        NextBlock
        NextCondition
        CompletedTrialsInThisBlock
        Editable
    end
    properties (Constant, Hidden = true)
        MLConfigFields = {'ErrorLogic','CondLogic','BlockLogic','NumberOfTrialsToRunInThisBlock','CountOnlyCorrectTrials',...
            'BlocksToRun','TotalNumberOfTrialsToRun','TotalNumberOfBlocksToRun','MLConditions'};
    end
    
    methods
        function export_to_file(obj,filename,varname)
            if ~exist('varname','var'), varname = 'TrialRecord'; end
            try
                dest = [];
                field = [properties(obj); 'DataFile'; 'TaskInfo'];
                for m=1:length(field), dest.(field{m}) = obj.(field{m}); end
                [~,~,e] = fileparts(filename);
                switch lower(e)
                    case '.bhv2', fid = mlbhv2(filename,'a');
                    case '.h5', fid = mlhdf5(filename,'a');
                    otherwise, fid = mlmat(filename);
                end
                fid.write(dest,varname);
                close(fid);
            catch err
                if exist('fid','var'), close(fid); end
                rethrow(err);
            end
        end
        
        function obj = mltrialrecord(MLConfig)
            init_properties(obj);
            if exist('MLConfig','var') && isa(MLConfig,'mlconfig'), init(obj,MLConfig); end
        end
        
        function next_block(obj,val)
            if obj.MLConditions.isconditionsfile()
                if isempty(find(val==obj.BlocksSelected,1)), error('Block #%d doesn''t exist',val); end
                obj.BlockChange = true;
            else
                obj.BlockChange = obj.BlockChange | val ~= obj.CurrentBlock;
            end
            obj.NextBlock = val;
        end
        function next_condition(obj,val)
            if obj.MLConditions.isuserloopfile()
                obj.NextCondition = val;
            else
                obj.NextCondition = [];
            end
        end
        
        function new_trial(obj)
            if obj.MLConditions.isconditionsfile()  % conditions file 
                update_block(obj);
                obj.CurrentTrialNumber = obj.CurrentTrialNumber + 1;
                obj.CurrentTrialWithinBlock = obj.CurrentTrialWithinBlock + 1;
                get_new_condition = true;
                if isempty(obj.ConditionsThisBlock)
                    for m=1:length(obj.MLConditions.Conditions)
                        if all(obj.CurrentBlock~=obj.MLConditions.Conditions(m).Block), continue, end
                        obj.ConditionsThisBlock = [obj.ConditionsThisBlock repmat(obj.MLConditions.Conditions(m).Condition,1,obj.MLConditions.Conditions(m).Frequency)];
                    end
                end
                if ~isempty(obj.TrialErrors) && 0~=obj.TrialErrors(end)
                    switch obj.ErrorLogic
                        case 1  % ignore
                        case 2  % repeat immediately
                            get_new_condition = false;
                        case 3  % repeat delayed
                            if 1<obj.CondLogic && obj.CondLogic<5, obj.ConditionsThisBlock = sort([obj.ConditionsThisBlock obj.CurrentCondition]);  end
                    end
                end
                if get_new_condition
                    switch obj.CondLogic
                        case 1  % random with replacement
                            obj.CurrentCondition = obj.ConditionsThisBlock(ceil(rand*length(obj.ConditionsThisBlock)));
                        case 2  % random without replacement
                            idx = ceil(rand*length(obj.ConditionsThisBlock));
                            obj.CurrentCondition = obj.ConditionsThisBlock(idx);
                            obj.ConditionsThisBlock(idx) = [];
                        case 3  % increasing
                            obj.CurrentCondition = obj.ConditionsThisBlock(1);
                            obj.ConditionsThisBlock(1) = [];
                        case 4  % decreasing
                            obj.CurrentCondition = obj.ConditionsThisBlock(end);
                            obj.ConditionsThisBlock(end) = [];
                        case 5  % user-defined
                            if isempty(obj.CondSelectFunction), error('Condition-selection function is not defined'); end
                            obj.CurrentCondition = obj.CondSelectFunction(obj);
                            idx = find(obj.ConditionsThisBlock==obj.CurrentCondition,1);
                            if isempty(idx), error('Condition #%d doesn''t exist',obj.CurrentCondition); end
                    end
                end
                obj.CurrentConditionInfo = obj.MLConditions.Conditions(obj.CurrentCondition).Info;
            else  % userloop file
                if obj.BlockChange
                    obj.CurrentTrialWithinBlock = 0;
                    if isempty(obj.NextBlock), obj.CurrentBlock = obj.CurrentBlock + 1; else obj.CurrentBlock = obj.NextBlock; obj.NextBlock = []; end
                    obj.CurrentBlockCount = obj.CurrentBlockCount + 1;
                    obj.BlockOrder(end+1) = obj.CurrentBlock;
                    obj.CompletedTrialsInThisBlock = 0;
                    obj.BlockChange = false;
                end
                obj.CurrentTrialNumber = obj.CurrentTrialNumber + 1;
                obj.CurrentTrialWithinBlock = obj.CurrentTrialWithinBlock + 1;
                if isempty(obj.NextCondition), obj.CurrentCondition = 1; else obj.CurrentCondition = obj.NextCondition; obj.NextCondition = []; end
            end
        end
        
        function update_trial_result(obj,trialdata)
            obj.ConditionsPlayed(end+1) = obj.CurrentCondition;
            obj.BlocksPlayed(end+1) = obj.CurrentBlock;
            obj.BlockCount(end+1) = obj.CurrentBlockCount;
            obj.TrialErrors(end+1) = trialdata.TrialError;
            obj.ReactionTimes(end+1) = trialdata.ReactionTime;
            obj.LastTrialAnalogData = trialdata.AnalogData;
            obj.LastTrialCodes = trialdata.BehavioralCodes;
            block_idx = find(obj.CurrentBlock==obj.MLConditions.UIVars.BlockList,1);
            if obj.CountOnlyCorrectTrials(block_idx)
                if 0==obj.TrialErrors(end), obj.CompletedTrialsInThisBlock = obj.CompletedTrialsInThisBlock + 1; end
            else
                obj.CompletedTrialsInThisBlock = obj.CompletedTrialsInThisBlock + 1;
            end
            if obj.NumberOfTrialsToRunInThisBlock(block_idx)<=obj.CompletedTrialsInThisBlock, obj.BlockChange = true; end
            if ~isempty(obj.BlockChangeFunction)
                val = obj.BlockChangeFunction(obj);
                obj.BlockChange = obj.BlockChange | 0<val;
                if ~isempty(obj.BlockSelectFunction) && strcmp(func2str(obj.BlockSelectFunction),func2str(obj.BlockChangeFunction)), next_block(obj,val); end
            end
            if obj.BlockChange && obj.TotalNumberOfBlocksToRun<=obj.CurrentBlockCount, obj.Pause = true; end
            if obj.TotalNumberOfTrialsToRun<=obj.CurrentTrialNumber, obj.Pause = true; end
        end
        
        function set_errorlogic(obj,val)
            if 0<val && val<4, obj.ErrorLogic = val; end
        end
        
        function obj = simulate_1st_trial(obj)
            obj.CurrentTrialNumber = 1;
            obj.CurrentTrialWithinBlock = 1;
            obj.CurrentCondition = 1;
            obj.CurrentBlock = 1;
            obj.CurrentBlockCount = 1;
            obj.ConditionsThisBlock = 1;
            obj.BlockOrder = 1;
            obj.BlocksSelected = 1;
        end
    end
    
    methods (Hidden = true)
        function set_stimulus_info(obj,val), obj.CurrentConditionStimulusInfo = val; end
        function set_editable(obj,val), obj.Editable = val; end
    end

    methods (Access = protected)
        function init(obj,MLConfig)
            init_properties(obj);
            for m=obj.MLConfigFields, obj.(m{1}) = MLConfig.(m{1}); end
            obj.CondSelectFunction = get_function_handle(MLConfig.CondSelectFunction);
            obj.BlockSelectFunction = get_function_handle(MLConfig.BlockSelectFunction);
            obj.BlockChangeFunction = get_function_handle(MLConfig.BlockChangeFunction);
            obj.BlocksSelected = obj.BlocksToRun;
            if ~isempty(MLConfig.FirstBlockToRun), next_block(obj,MLConfig.FirstBlockToRun); end
        end
        function init_properties(obj)
            obj.CurrentTrialNumber = 0;
            obj.CurrentTrialWithinBlock = 0;
            obj.CurrentCondition = 0;
            obj.CurrentBlock = 0;
            obj.CurrentBlockCount = 0;
            obj.CurrentConditionStimulusInfo = [];
            obj.ConditionsPlayed = [];
            obj.ConditionsThisBlock = [];
            obj.BlocksPlayed = [];
            obj.BlockCount = [];
            obj.BlockOrder = [];
            obj.BlocksSelected = [];
            obj.TrialErrors = [];
            obj.ReactionTimes = [];
            obj.LastTrialAnalogData = struct('EyeSignal',[],'Joystick',[]);
            obj.LastTrialCodes = struct('CodeNumbers',[],'CodeTimes',[]);
            
            obj.SimulationMode = false;
            obj.BlockChange = true;
            obj.Pause = true;
            obj.Quit = false;
            obj.TestTrial = false;
            
            obj.NextBlock = [];
            obj.CompletedTrialsInThisBlock = 0;
        end
        function update_block(obj)
            block_changed = false;
            if isempty(obj.BlocksSelected), obj.BlocksSelected = obj.BlocksToRun; end
            if ~isempty(obj.NextBlock)
                idx = find(obj.BlocksSelected==obj.NextBlock,1);
                if isempty(idx), error('Block #%d doesn''t exist',obj.NextBlock); end
                obj.CurrentBlock = obj.NextBlock;
                obj.NextBlock = [];
                if 1<obj.BlockLogic && obj.BlockLogic<5, obj.BlocksSelected(idx) = []; end
                block_changed = true;
            elseif obj.BlockChange
                switch obj.BlockLogic
                    case 1  % random with replacement
                        obj.CurrentBlock = obj.BlocksSelected(ceil(rand*length(obj.BlocksSelected)));
                    case 2  % random without replacement
                        NextBlock = obj.CurrentBlock; %#ok<*PROP>
                        while obj.CurrentBlock == NextBlock
                            idx = ceil(rand*length(obj.BlocksSelected));
                            NextBlock = obj.BlocksSelected(idx);
                        end
                        obj.CurrentBlock = NextBlock;
                        obj.BlocksSelected(idx) = [];
                    case 3  % increasing
                        obj.CurrentBlock = obj.BlocksSelected(1);
                        obj.BlocksSelected(1) = [];
                    case 4  % decreasing
                        obj.CurrentBlock = obj.BlocksSelected(end);
                        obj.BlocksSelected(end) = [];
                    case 5  % user-defined
                        if isempty(obj.BlockSelectFunction), error('Block-selection function is not defined'); end
                        obj.CurrentBlock = obj.BlockSelectFunction(obj);
                        idx = find(obj.BlocksSelected==obj.CurrentBlock,1);
                        if ~isempty(idx), obj.BlocksSelected(idx) = []; end
                end
                block_changed = true;
            end
            if block_changed
                obj.CurrentTrialWithinBlock = 0;
                obj.CurrentBlockCount = obj.CurrentBlockCount + 1;
                obj.BlockOrder(end+1) = obj.CurrentBlock;
                obj.CompletedTrialsInThisBlock = 0;
                obj.ConditionsThisBlock = [];
            end
            obj.BlockChange = false;
        end
    end
end
