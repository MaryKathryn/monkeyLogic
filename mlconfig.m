classdef (ConstructOnLoad = true) mlconfig
    properties  % variables related to UI
        SubjectScreenDevice
        DiagonalSize
        ViewingDistance
        FallbackScreenRect
        ForcedUseOfFallbackScreen
        VsyncSpinlock
        SubjectScreenBackground
        FixationPointImage
        FixationPointShape
        FixationPointColor
        FixationPointDeg
        EyeTracerShape
        EyeTracerColor
        EyeTracerSize
        JoystickCursorImage
        JoystickCursorShape
        JoystickCursorColor
        JoystickCursorSize
        TouchCursorImage
        TouchCursorShape
        TouchCursorColor
        TouchCursorSize
        PhotoDiodeTrigger
        PhotoDiodeTriggerSize
        ErrorLogic
        CondLogic
        CondSelectFunction
        BlockLogic
        BlockSelectFunction
        BlockChangeFunction
        RemoteAlert
        InterTrialInterval
        SummarySceneDuringITI
        NonStopRecording
        UserPlotFunction
        IO
        Touchscreen
        RunMessageLoop
        USBJoystick
        EyeTracker
        AIConfiguration
        AISampleRate
        AIOnlineSmoothing
        AIOnlineSmoothingWindow
        StrobeTrigger
        StrobePulseSpec
        RewardFuncArgs
        RewardPolarity
        EyeCalibration
        EyeTransform
        EyeAutoDriftCorrection
        JoystickCalibration
        JoystickTransform
        NumberOfTrialsToRunInThisBlock
        CountOnlyCorrectTrials
        BlocksToRun
        FirstBlockToRun
        TotalNumberOfTrialsToRun
        TotalNumberOfBlocksToRun
        ExperimentName
        Investigator
        SubjectName
        FilenameFormat
        Filetype
        MinifyRuntime
        ControlScreenZoom
    end
    properties (Dependent = true)  % related to UI, but not edittable
        Resolution
        PixelsPerDegree
        FormattedName
    end
    properties (Transient = true)  % variables that are not saved in the config file
        MLVersion
        MLPath
        MLConditions
        DAQ
        Screen
        System
        IOList
    end
    properties (Constant = true, Hidden = true)
        Ver = 1.0;
        DependentFields = {'Resolution','PixelsPerDegree','FormattedName'}
        TransientFields = {'MLVersion','MLPath','MLConditions','DAQ','Screen','System','IOList'}
        DefaultNumberOfTrialsToRunInThisBlock = 1000;
        DefaultCountOnlyCorrectTrials = true;
    end

    methods (Static)
        function obj = loadobj(obj)
            if ~isfield(obj.RewardFuncArgs,'JuiceLine'), obj.RewardFuncArgs.JuiceLine = 1; end
        end
    end
    methods
        function field = fieldnames(obj)
            field = mlsetdiff(properties(obj),[obj.DependentFields obj.TransientFields]);
        end
        function obj = mlconfig()
            try
                obj.SubjectScreenDevice = mglgetadaptercount;
            catch
                obj.SubjectScreenDevice = size(get(0,'MonitorPositions'),1);
            end
            obj.DiagonalSize = 50.8;
            obj.ViewingDistance = 57;

            obj.FallbackScreenRect = '[0,0,1024,768]';
            obj.ForcedUseOfFallbackScreen = false;
            obj.VsyncSpinlock = 1;

            obj.SubjectScreenBackground = [0 0 0];

            obj.FixationPointImage = '';
            obj.FixationPointShape = 'Square';
            obj.FixationPointColor = [1 1 1];
            obj.FixationPointDeg = 0.2;

            obj.EyeTracerShape = 'Line';
            obj.EyeTracerColor = [1 0 0];
            obj.EyeTracerSize = 5;

            obj.JoystickCursorImage = '';
            obj.JoystickCursorShape = 'Circle';
            obj.JoystickCursorColor = [0 1 0];
            obj.JoystickCursorSize = 5;

            obj.TouchCursorImage = '';
            obj.TouchCursorShape = 'Circle';
            obj.TouchCursorColor = [1 1 0];
            obj.TouchCursorSize = 5;

            obj.PhotoDiodeTrigger = 1;
            obj.PhotoDiodeTriggerSize = 64;

            obj.ErrorLogic = 1;
            obj.CondLogic = 1;
            obj.CondSelectFunction = '';
            obj.BlockLogic = 1;
            obj.BlockSelectFunction = '';
            obj.BlockChangeFunction = '';

            obj.RemoteAlert = false;
            obj.InterTrialInterval = 2000;
            obj.SummarySceneDuringITI = true;
            obj.NonStopRecording = false;
            obj.UserPlotFunction = '';

            obj.IO = [];
            obj.Touchscreen = false;
            obj.RunMessageLoop = false;
            obj.USBJoystick = 'None';
            obj.EyeTracker = struct('Name','None','ID','','ViewPoint',[],'EyeLink',[]);

            obj.AIConfiguration = 'NonReferencedSingleEnded';
            obj.AISampleRate = 1000;
            obj.AIOnlineSmoothing = 1;
            obj.AIOnlineSmoothingWindow = 5;

            obj.StrobeTrigger = 1;
            obj.StrobePulseSpec = struct('T1',125,'T2',125);
            obj.RewardFuncArgs = struct('JuiceLine',1,'Duration',100,'NumReward',1,'PauseTime',40,'TriggerVal',5,'Custom','');
            obj.RewardPolarity = 1;

            obj.EyeCalibration = 1;
            obj.EyeTransform = cell(1,3);
            obj.EyeAutoDriftCorrection = 0;

            obj.JoystickCalibration = 1;
            obj.JoystickTransform = cell(1,3);

            obj.NumberOfTrialsToRunInThisBlock = obj.DefaultNumberOfTrialsToRunInThisBlock;
            obj.CountOnlyCorrectTrials = obj.DefaultCountOnlyCorrectTrials;
            obj.BlocksToRun = 1;
            obj.FirstBlockToRun = [];

            obj.TotalNumberOfTrialsToRun = 5000;
            obj.TotalNumberOfBlocksToRun = 1000;

            obj.ExperimentName = 'Experiment';
            obj.Investigator = 'Investigator';
            obj.SubjectName = '';

            obj.FilenameFormat = 'yymmdd_sname_cname';
            obj.Filetype = '.bhv2';
            obj.MinifyRuntime = true;
            
            obj.ControlScreenZoom = 90;

            obj.MLPath = mlpath;
            obj.MLConditions = mlconditions;
            obj.DAQ = mldaq;
            obj.Screen = mlscreen;
            obj.System = mlsystem;
        end
        function export_to_file(obj,filename,varname)
            if ~exist('varname','var'), varname = 'MLConfig'; end
            try
                dest = [];
                field = [mlsetdiff(properties(obj),obj.TransientFields); 'MLVersion'; 'MLPath'; 'Ver'];
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
%         function import_from_file(obj,filename,varname)
%             if ~exist('varname','var'), varname = 'MLConfig'; end
%             try
%                 [~,~,e] = fileparts(filename);
%                 switch lower(e)
%                     case '.bhv2', fid = mlbhv2(filename,'r'); 
%                     case '.h5', fid = mlhdf5(filename,'r');
%                     otherwise, fid = mlmat(filename);
%                 end
%                 src = fid.read(varname);
%                 close(fid);
%                 field = intersect(fieldnames(obj),fieldnames(src));
%                 for m=1:length(field)
%                     if isa(obj.(field{m}),'function_handle'), continue; end
%                     obj.(field{m}) = src.(field{m});
%                 end
%             catch err
%                 if exist('fid','var'), close(fid); end
%                 rethrow(err);
%             end
%         end
        function delete(obj)
            delete(obj.DAQ);
            delete(obj.Screen);
        end
        
        function tf = isequal(obj,val)
            if ~strcmp(class(obj),class(val)), tf = false; return, end
            field = fieldnames(obj);
            tf = true; for m=1:length(field), if ~isequal(obj.(field{m}),val.(field{m})), tf = false; break, end, end
        end
        
        function val = get.Resolution(obj)
            try
                [width,height,refreshrate] = mglgetadapterdisplaymode(obj.SubjectScreenDevice);
                val = sprintf('%d x %d %d Hz',width,height,refreshrate);
            catch
                val = '';
            end
        end
        function val = get.PixelsPerDegree(obj)
            try
                [width,height] = mglgetadapterdisplaymode(obj.SubjectScreenDevice);
                pixels_in_diagonal = sqrt(width^2 + height^2);
                viewing_deg = 2 * atan2(obj.DiagonalSize / 2, obj.ViewingDistance) * 180 / pi;
                val = [1 -1] * pixels_in_diagonal / viewing_deg;
            catch
                val = NaN(1,2);
            end
        end
        function val = get.FormattedName(obj)
            try
                val = obj.FilenameFormat;
                format = {'yyyy','yy','mmm','mm','ddd','dd','HH','MM','SS'};
                for m=1:length(format), val = regexprep(val,format{m},datestr(now,format{m})); end
                val = regexprep(val,'expname|ename',obj.ExperimentName);
                val = regexprep(val,'yourname|yname',obj.Investigator);
                [~,filename] = fileparts(obj.MLPath.ConditionsFile);
                val = regexprep(val,'condname|cname',filename);
                val = regexprep(val,'subjname|sname',obj.SubjectName);
            catch
                val = '';
            end
        end
    end
end
