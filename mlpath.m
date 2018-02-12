classdef mlpath < matlab.mixin.Copyable
    properties
        BaseDirectory
        ConditionsFile
        DataFile
    end
    properties (Dependent = true)
        ExperimentDirectory
        RunTimeDirectory
        ConfigurationFile
        BehavioralCodesFile
        AlertFunction
        RewardFunction
    end
    properties (Constant, Hidden)
        BehavioralCodesFileName = 'codes.txt';
        AlertFunctionName = 'alert_function.m';
        RewardFunctionName = 'reward_function.m';
    end
    
    methods (Access = protected)
        function cp = copyElement(obj)
            cp = copyElement@matlab.mixin.Copyable(obj);
        end
    end
    
    methods
        function obj = mlpath(BaseDirectory)
            if ~exist('BaseDirectory','var'), BaseDirectory = ''; end
            obj.BaseDirectory = BaseDirectory;
            obj.ConditionsFile = '';
            obj.DataFile = '';
        end
        
        function set.BaseDirectory(obj,val)
            if exist(val,'dir')
                if filesep~=val(end), val(end+1) = filesep; end
            elseif exist(val,'file')
                p = fileparts(val);
                if isempty(p), val = fileparts(which(val)); else val = p; end
                val = [val filesep];
            else
                obj.BaseDirectory = '';
                return
            end
            if ~exist([val 'monkeylogic.m'],'file'), error('mlpath:fileNotFound','''monkeylogic.m'' is not found in ''%s''',val(1:end-1)); end
            obj.BaseDirectory = val;
        end
        function set.ConditionsFile(obj,val)
            if 2~=exist(val,'file'), obj.ConditionsFile = ''; return, end
            if isempty(fileparts(val)), val = which(val); end
            obj.ConditionsFile = val;
        end
        function set.DataFile(obj,val)
            [~,n,e] = fileparts(val);
            obj.DataFile = [n e];
        end
        
%         function val = get.DataFile(obj)
%             if ~isempty(obj.ConditionsFile), val = [obj.ExperimentDirectory obj.DataFile]; else val = obj.DataFile; end
%         end
        function val = get.ExperimentDirectory(obj)
            if isempty(obj.ConditionsFile), val = ''; else val = [fileparts(obj.ConditionsFile) filesep]; end
        end
        function val = get.RunTimeDirectory(~)
            val = tempdir;
        end
        function val = get.ConfigurationFile(obj)
            if ~isempty(obj.ConditionsFile)
                [p,n] = fileparts(obj.ConditionsFile); val = [p filesep n '_cfg2.mat'];
            elseif ~isempty(obj.BaseDirectory)
                val = [tempdir 'monkeylogic_cfg2.mat'];
            else
                val = '';
            end
        end
        function val = get.BehavioralCodesFile(obj)
            val = validate_path(obj,obj.BehavioralCodesFileName);
        end
        function val = get.AlertFunction(obj)
            val = validate_path(obj,obj.AlertFunctionName);
        end
        function val = get.RewardFunction(obj)
            val = validate_path(obj,obj.RewardFunctionName);
        end
        
        function filepath = validate_path(obj,filepath)
            if isempty(filepath), return, end
%             [p,n,e] = fileparts(filepath);
%             if ~isempty(p) && 2==exist(filepath,'file'), return, end
            [~,n,e] = fileparts(filepath);
            filepath = [obj.ExperimentDirectory n e];
            if ~isempty(obj.ExperimentDirectory) && 2==exist(filepath,'file'), return, end
            filepath = [obj.BaseDirectory n e];
            if ~isempty(obj.BaseDirectory) && 2==exist(filepath,'file'), return, end
            filepath = '';
        end
    end
end
