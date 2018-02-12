function monkeylogic()
% MonkeyLogic main menu
%
% Created by WA, July, 2006
% Modified 7/28/08 -WA (to include "User Plot" button)
% Modified 8/13/08 -WA (to include display of movies in stimulus menu)
% Modified 8/27/08 -WA (to allow pre-processing of visual stimuli)
% Modified 9/08/08 -SM (to use appropriate analog input-type when testing those inputs)
% Modified 2/01/12 -WA (to remove overwrite_hardware_cfg subfunction - had broken the ability to write new cfg files when none present)
% Modified 2/28/14 -ER (to allow the user to select multiple analog channels for I/O testing)
% Modified 3/20/14 -ER (started looking into modifying the DAQ toolbox function calls to handle 64 bit Windows/Matlab)
% Modified 2015-04-23 -SL (minor change to datestr and numerical suffix)
% 2015-04-24 -SL (formatting)

%   Dec 31, 2016    This file is renamed from 'mlmenu.m' to 'monkeylogic.m'
%                   and completely re-written by Jaewon Hwang

MLConfig = mlconfig;
old_MLConfig = MLConfig;
MLPath = MLConfig.MLPath;
MLConditions = MLConfig.MLConditions;
DAQ = MLConfig.DAQ;
Screen = MLConfig.Screen;
System = MLConfig.System;

% temporary variables
hFig = [];
hVideo = [];
hIO = [];
hTask = [];
hMessagebox = [];
IOBoard = [];      % DAQ board list
IOName = [];       % IO names on the GUI menu
io = [];           % IO panel user input cache
trials_per_block = MLConfig.NumberOfTrialsToRunInThisBlock;
datafilename_manually_typed = false;
all_DAQ_accounted = true;
hNonDAQ = struct;
eyetrackers = {'None',''; 'Arrington ViewPoint EyeTracker','viewpoint'; 'SR Research EyeLink','eyelink'};

% figure
load('mlimagedata.mat','earth_image','ioheader_image','runbutton_image','runbuttondim_image','taskheader_image','threemonkeys_image','ttl_icon','videoheader_image','expand_icon','collapse_icon');
fontsize = 9;
callbackfunc = @UIcallback;
figure_bgcolor = [.65 .70 .80];
frame_bgcolor = [0.9255 0.9137 0.8471];
purple_bgcolor = [.8 .76 .82];
collapsed_menu = false;
calibration_method = {'Raw Signal (Precalibrated)','Origin & Gain','2-D Spatial Transformation'};
init();

    function update_UI()
        float0 = {'VsyncSpinlock'};
        float1 = {'DiagonalSize','ViewingDistance','FixationPointDeg'};
        int0 = {'EyeTracerSize','JoystickCursorSize','TouchCursorSize','PhotoDiodeTriggerSize','EyeAutoDriftCorrection','InterTrialInterval'};
        int1 = {'AIOnlineSmoothingWindow','TotalNumberOfTrialsToRun','TotalNumberOfBlocksToRun'};
        arr1 = {'NumberOfTrialsToRunInThisBlock'};
        for m=float0, if isnan(MLConfig.(m{1})) || MLConfig.(m{1})<0, mlmessage('''%s'' must be 0 or a positive number',m{1},'e'); MLConfig.(m{1}) = old_MLConfig.(m{1}); end, end
        for m=float1, if isnan(MLConfig.(m{1})) || MLConfig.(m{1})<=0, mlmessage('''%s'' must be a positive number',m{1},'e'); MLConfig.(m{1}) = old_MLConfig.(m{1}); end, end
        for m=int0, MLConfig.(m{1}) = round(MLConfig.(m{1})); if isnan(MLConfig.(m{1})) || MLConfig.(m{1})<0, mlmessage('''%s'' must be 0 or a positive number',m{1},'e'); MLConfig.(m{1}) = round(old_MLConfig.(m{1})); end, end
        for m=int1, MLConfig.(m{1}) = round(MLConfig.(m{1})); if isnan(MLConfig.(m{1})) || MLConfig.(m{1})<=0, mlmessage('''%s'' must be a positive number',m{1},'e'); MLConfig.(m{1}) = round(old_MLConfig.(m{1})); end, end
        for m=arr1, MLConfig.(m{1}) = round(MLConfig.(m{1})); if any(isnan(MLConfig.(m{1}))) || any(MLConfig.(m{1})<1), mlmessage('''%s'' must be 1 or a positive number',m{1},'e'); MLConfig.(m{1}) = trials_per_block; end, end
        
        if ~isempty(hVideo), update_videoUI(); end
        if ~isempty(hIO), update_ioUI(); end
        if ~isempty(hTask), update_taskUI(); end
        
        set(findobj(hFig,'tag','ConfigurationFile'),'string',strip_path(MLPath.ConfigurationFile));
        set(findobj(hFig,'tag','OpenConfigurationFolder'),'enable',fi(2==exist(MLPath.ConfigurationFile,'file'),'on','off'));
        
        set(findobj(hFig,'tag','LoadConditionsFile'),'string',fi(isempty(MLPath.ConditionsFile),'To start, load a conditions file',strip_path(MLPath.ConditionsFile)));
        set(findobj(hFig,'tag','EditConditionsFile'),'enable',fi(isempty(MLPath.ConditionsFile),'off','on'));
        
        vars = MLConditions.UIVars;
        enable = fi(isconditionsfile(MLConditions),'on','off');
        set(findobj(hFig,'tag','TotalNumberOfConditions'),'string',num2str(vars.TotalNumberOfConditions));
        if isconditionsfile(MLConditions), str = {vars.StimulusList.Label}; else, str = vars.StimulusList; end
        set(findobj(hFig,'tag','StimulusList'),'enable',fi(isempty(vars.StimulusList),'off','on'),'string',str);
        set(findobj(hFig,'tag','StimulusTest'),'enable',enable);
        set(findobj(hFig,'tag','BlockList'),'enable',enable,'string',num2cell(vars.BlockList));
        set(findobj(hFig,'tag','ChooseBlocksToRun'),'enable',enable);
        set(findobj(hFig,'tag','ChooseFirstBlockToRun'),'enable',enable);
        if isconditionsfile(MLConditions)
            chosen_block = get(findobj(hFig,'tag','BlockList'),'value');
            set(findobj(hFig,'tag','TotalNumberOfConditionsInThisBlock'),'string',num2str(vars.TotalNumberOfConditionsInThisBlock(chosen_block)));
            set(findobj(hFig,'tag','NumberOfTrialsToRunInThisBlock'),'enable',enable,'string',num2str(MLConfig.NumberOfTrialsToRunInThisBlock(chosen_block)));
            set(findobj(hFig,'tag','CountOnlyCorrectTrials'),'enable',enable,'value',MLConfig.CountOnlyCorrectTrials(chosen_block));
            set(findobj(hFig,'tag','BlocksToRun'),'string',['[' num2range(MLConfig.BlocksToRun) ']']);
            set(findobj(hFig,'tag','FirstBlockToRun'),'string',fi(isempty(MLConfig.FirstBlockToRun),'TBD',num2str(MLConfig.FirstBlockToRun)));
        else
            set(findobj(hFig,'tag','TotalNumberOfConditionsInThisBlock'),'string','');
            set(findobj(hFig,'tag','NumberOfTrialsToRunInThisBlock'),'enable',enable,'string','');
            set(findobj(hFig,'tag','CountOnlyCorrectTrials'),'enable',enable,'value',false);
            set(findobj(hFig,'tag','BlocksToRun'),'string','');
            set(findobj(hFig,'tag','FirstBlockToRun'),'string','');
        end
        
        set(findobj(hFig,'tag','ChartBlocks'),'enable',enable);
        set(findobj(hFig,'tag','ApplyToAll'),'enable',enable);
        set(findobj(hFig,'tag','TimingFiles'),'enable',fi(isempty(vars.TimingFiles),'off','on'),'string',vars.TimingFiles);
        set(findobj(hFig,'tag','EditTimingFiles'),'enable',enable);
        
        set(findobj(hFig,'tag','TotalNumberOfTrialsToRun'),'string',num2str(MLConfig.TotalNumberOfTrialsToRun));
        set(findobj(hFig,'tag','TotalNumberOfBlocksToRun'),'string',num2str(MLConfig.TotalNumberOfBlocksToRun));
        
        set(findobj(hFig,'tag','ExperimentName'),'string',MLConfig.ExperimentName);
        set(findobj(hFig,'tag','Investigator'),'string',MLConfig.Investigator);
        set(findobj(hFig,'tag','SubjectName'),'string',MLConfig.SubjectName);
        set(findobj(hFig,'tag','FilenameFormat'),'string',MLConfig.FilenameFormat);
        
        set(findobj(hFig,'tag','DataFile'),'string',MLPath.DataFile);
        set(findobj(hFig,'tag','MinifyRuntime'),'value',MLConfig.MinifyRuntime);
        MLConfig.Filetype = set_listbox_value(findobj(hFig,'tag','Filetype'),MLConfig.Filetype);
        set(findobj(hFig,'tag','OpenRuntimeFolder'),'enable',fi(7==exist(MLPath.RunTimeDirectory,'file'),'on','off'));
        
        if isloaded(MLConditions)
            set(findobj(hFig,'tag','RunButton'),'enable','on','cdata',runbutton_image);
        else
            set(findobj(hFig,'tag','RunButton'),'enable','inactive','cdata',runbuttondim_image);
        end
        
        set(findobj(hFig,'tag','SaveSettings'),'enable',fi(2==exist(MLPath.ConfigurationFile,'file') && isequal(MLConfig,old_MLConfig),'off','on'));
    end

    function update_videoUI()
        if System.NumberOfScreenDevices < MLConfig.SubjectScreenDevice
            mlmessage('Can''t find the subject screen device #%d. Changed to #%d.',MLConfig.SubjectScreenDevice,System.NumberOfScreenDevices,'e');
            MLConfig.SubjectScreenDevice = System.NumberOfScreenDevices;
        end
        if 4~=length(regexp(MLConfig.FallbackScreenRect,'[0-9]+'))
            mlmessage('Fallback screen rect: %s is not a 1-by-4 vector. Changed back to %s.',MLConfig.FallbackScreenRect,old_MLConfig.FallbackScreenRect,'e');
            MLConfig.FallbackScreenRect = old_MLConfig.FallbackScreenRect;
        end
        if isempty(regexp(MLConfig.FallbackScreenRect,'^[ \t]*\[[ \t]*[0-9]+(,|[ \t]+)[0-9]+(,|[ \t]+)[0-9]+(,|[ \t]+)[0-9]+[ \t]*\][ \t]*$','match'))
            mlmessage('Fallback screen rect: %s is not a format of [left,top,right,bottom]. Changed back to %s.',MLConfig.FallbackScreenRect,old_MLConfig.FallbackScreenRect,'e');
            MLConfig.FallbackScreenRect = old_MLConfig.FallbackScreenRect;
        end
        
        set(findobj(hVideo,'tag','SubjectScreenDevice'),'value',MLConfig.SubjectScreenDevice);
        set(findobj(hVideo,'tag','Resolution'),'string',MLConfig.Resolution);
        set(findobj(hVideo,'tag','DiagonalSize'),'string',num2str(MLConfig.DiagonalSize));
        set(findobj(hVideo,'tag','ViewingDistance'),'string',num2str(MLConfig.ViewingDistance));
        set(findobj(hVideo,'tag','PixelsPerDegree'),'string',sprintf('%.3f',MLConfig.PixelsPerDegree(1)));
        
        set(findobj(hVideo,'tag','FallbackScreenRect'),'string',MLConfig.FallbackScreenRect);
        set(findobj(hVideo,'tag','ForcedUseOfFallbackScreen'),'value',MLConfig.ForcedUseOfFallbackScreen);
        set(findobj(hVideo,'tag','VsyncSpinlock'),'string',num2str(MLConfig.VsyncSpinlock));
        
        set_button_color(findobj(hVideo,'tag','SubjectScreenBackground'),MLConfig.SubjectScreenBackground);
        
        MLConfig.FixationPointImage = MLPath.validate_path(MLConfig.FixationPointImage);
        set(findobj(hVideo,'tag','FixationPointImage'),'string',strip_path(MLConfig.FixationPointImage,'Select a(n) image/movie'));
        enable = fi(isempty(MLConfig.FixationPointImage),'on','off');
        MLConfig.FixationPointShape = set_listbox_value(findobj(hVideo,'tag','FixationPointShape'),MLConfig.FixationPointShape,'enable',enable);
        set_button_color(findobj(hVideo,'tag','FixationPointColor'),MLConfig.FixationPointColor,'enable',enable);
        set(findobj(hVideo,'tag','FixationPointDeg'),'string',num2str(MLConfig.FixationPointDeg),'enable',enable);
        
        MLConfig.EyeTracerShape = set_listbox_value(findobj(hVideo,'tag','EyeTracerShape'),MLConfig.EyeTracerShape);
        set_button_color(findobj(hVideo,'tag','EyeTracerColor'),MLConfig.EyeTracerColor);
        set(findobj(hVideo,'tag','EyeTracerSize'),'string',num2str(MLConfig.EyeTracerSize),'enable',fi(strcmp(MLConfig.EyeTracerShape,'Line'),'off','on'));
        
        MLConfig.JoystickCursorImage = MLPath.validate_path(MLConfig.JoystickCursorImage);
        set(findobj(hVideo,'tag','JoystickCursorImage'),'string',strip_path(MLConfig.JoystickCursorImage,'Select a(n) image/movie'));
        enable = fi(isempty(MLConfig.JoystickCursorImage),'on','off');
        MLConfig.JoystickCursorShape = set_listbox_value(findobj(hVideo,'tag','JoystickCursorShape'),MLConfig.JoystickCursorShape,'enable',enable);
        set_button_color(findobj(hVideo,'tag','JoystickCursorColor'),MLConfig.JoystickCursorColor,'enable',enable);
        set(findobj(hVideo,'tag','JoystickCursorSize'),'string',num2str(MLConfig.JoystickCursorSize),'enable',enable);
        
        MLConfig.TouchCursorImage = MLPath.validate_path(MLConfig.TouchCursorImage);
        set(findobj(hVideo,'tag','TouchCursorImage'),'string',strip_path(MLConfig.TouchCursorImage,'Select a(n) image/movie'));
        enable = fi(isempty(MLConfig.TouchCursorImage),'on','off');
        MLConfig.TouchCursorShape = set_listbox_value(findobj(hVideo,'tag','TouchCursorShape'),MLConfig.TouchCursorShape,'enable',enable);
        set_button_color(findobj(hVideo,'tag','TouchCursorColor'),MLConfig.TouchCursorColor,'enable',enable);
        set(findobj(hVideo,'tag','TouchCursorSize'),'string',num2str(MLConfig.TouchCursorSize),'enable',enable);
        
        set(findobj(hVideo,'tag','PhotoDiodeTrigger'),'value',MLConfig.PhotoDiodeTrigger);
        set(findobj(hVideo,'tag','PhotoDiodeTriggerSize'),'string',num2str(MLConfig.PhotoDiodeTriggerSize));
    end

    function update_ioUI()
        set(findobj(hIO,'tag','EditBehavioralCodesFile'),'enable',fi(isempty(MLPath.BehavioralCodesFile),'off','on'));
        
        MLConfig.AIConfiguration = set_listbox_value(findobj(hIO,'tag','AIConfiguration'),MLConfig.AIConfiguration);
        MLConfig.AISampleRate = str2double(set_listbox_value(findobj(hIO,'tag','AISampleRate'),num2str(fi(MLConfig.NonStopRecording,1000,MLConfig.AISampleRate))));
        set(findobj(hIO,'tag','AIOnlineSmoothing'),'value',MLConfig.AIOnlineSmoothing);
        set(findobj(hIO,'tag','AIOnlineSmoothingWindow'),'string',num2str(MLConfig.AIOnlineSmoothingWindow));
        
        set(findobj(hIO,'tag','RewardFuncArgs'),'string',sprintf('%d ms, %d time(s)',MLConfig.RewardFuncArgs.Duration,MLConfig.RewardFuncArgs.NumReward));
        
        set(findobj(hIO,'tag','EditRewardArgs'),'enable',fi(isempty(MLPath.RewardFunction),'off','on'));
        set(findobj(hIO,'tag','EditRewardFunc'),'enable',fi(isempty(MLPath.RewardFunction),'off','on'));
        set(findobj(hIO,'tag','RewardPolarity'),'value',MLConfig.RewardPolarity);
        set(findobj(hIO,'tag','StrobeTrigger'),'value',MLConfig.StrobeTrigger);
        
        set(findobj(hIO,'tag','EyeCalibration'),'value',MLConfig.EyeCalibration);
        if 1==MLConfig.EyeCalibration
            enable = 'off'; string = 'Calibrate Eye'; color = [0 0 0];
        else
            enable = 'on';
            string = fi(isempty(MLConfig.EyeTransform{MLConfig.EyeCalibration}),'Calibrate Eye','Re-calibrate');
            color = fi(isempty(MLConfig.EyeTransform{MLConfig.EyeCalibration}),[1 0 0],[0 0.5 0]);
        end
        set(findobj(hIO,'tag','ResetEyeCalibration'),'enable',fi(isempty(MLConfig.EyeTransform{MLConfig.EyeCalibration}),'off','on'));
        set(findobj(hIO,'tag','EyeCalibrationButton'),'enable',enable,'string',string,'foregroundcolor',color);
        set(findobj(hIO,'tag','EyeCalibrationImportButton'),'enable',enable);
        set(findobj(hIO,'tag','EyeAutoDriftCorrection'),'string',num2str(MLConfig.EyeAutoDriftCorrection));
        set(findobj(hIO,'tag','JoystickCalibration'),'value',MLConfig.JoystickCalibration);
        if 1==MLConfig.JoystickCalibration
            enable = 'off'; string = 'Calibrate Joy'; color = [0 0 0];
        else
            enable = 'on';
            string = fi(isempty(MLConfig.JoystickTransform{MLConfig.JoystickCalibration}),'Calibrate Joy','Re-calibrate');
            color = fi(isempty(MLConfig.JoystickTransform{MLConfig.JoystickCalibration}),[1 0 0],[0 0.5 0]);
        end
        set(findobj(hIO,'tag','ResetJoystickCalibration'),'enable',fi(isempty(MLConfig.JoystickTransform{MLConfig.JoystickCalibration}),'off','on'));
        set(findobj(hIO,'tag','JoystickCalibrationButton'),'enable',enable,'string',string,'foregroundcolor',color);
        set(findobj(hIO,'tag','JoystickCalibrationImportButton'),'enable',enable);
    end

    function update_taskUI()
        set(findobj(hTask,'tag','ErrorLogic'),'value',MLConfig.ErrorLogic);
        MLConfig.CondSelectFunction = MLPath.validate_path(MLConfig.CondSelectFunction);
        MLConfig.CondLogic = fi(5==MLConfig.CondLogic && isempty(MLConfig.CondSelectFunction),1,MLConfig.CondLogic);
        set(findobj(hTask,'tag','CondLogic'),'value',MLConfig.CondLogic);
        set(findobj(hTask,'tag','CondSelectFunction'),'string',strip_path(MLConfig.CondSelectFunction,'Choose a user-defined function'),'enable',fi(5==MLConfig.CondLogic,'on','off'));
        MLConfig.BlockSelectFunction = MLPath.validate_path(MLConfig.BlockSelectFunction);
        MLConfig.BlockLogic = fi(5==MLConfig.BlockLogic && isempty(MLConfig.BlockSelectFunction),1,MLConfig.BlockLogic);
        set(findobj(hTask,'tag','BlockLogic'),'value',MLConfig.BlockLogic);
        set(findobj(hTask,'tag','BlockSelectFunction'),'string',strip_path(MLConfig.BlockSelectFunction,'Choose a user-defined function'),'enable',fi(5==MLConfig.BlockLogic,'on','off'));
        MLConfig.BlockChangeFunction = MLPath.validate_path(MLConfig.BlockChangeFunction);
        set(findobj(hTask,'tag','BlockChangeFunction'),'string',strip_path(MLConfig.BlockChangeFunction,'Block change function'));
        
        enable = fi(isempty(MLPath.AlertFunction),'off','on');
        set(findobj(hTask,'tag','RemoteAlert'),'enable',enable,'string',fi(MLConfig.RemoteAlert,'Alert ON','Alert OFF'),'foregroundcolor',fi(MLConfig.RemoteAlert,[1 0 0],[0 0 0]));
        set(findobj(hTask,'tag','EditAlertFunc'),'enable',enable);
        set(findobj(hTask,'tag','InterTrialInterval'),'string',num2str(MLConfig.InterTrialInterval));
        set(findobj(hTask,'tag','SummarySceneDuringITI'),'value',MLConfig.SummarySceneDuringITI);
        set(findobj(hTask,'tag','NonStopRecording'),'value',MLConfig.NonStopRecording);
        MLConfig.UserPlotFunction = MLPath.validate_path(MLConfig.UserPlotFunction);
        set(findobj(hTask,'tag','UserPlotFunction'),'string',strip_path(MLConfig.UserPlotFunction,'User plot function'));
    end

    function UIcallback(hObject,~)
        obj_tag = get(hObject,'tag');
        switch obj_tag
            case {'SubjectScreenDevice','ForcedUseOfFallbackScreen','PhotoDiodeTrigger', ...
                    'ErrorLogic','SummarySceneDuringITI','NonStopRecording', ...
                    'Touchscreen','AIOnlineSmoothing','RewardPolarity','StrobeTrigger','EyeCalibration','JoystickCalibration'}
                MLConfig.(obj_tag) = get(gcbo,'value');
            case {'CondLogic','BlockLogic'}
                MLConfig.(obj_tag) = get(gcbo,'value');
                switch obj_tag
                    case 'CondLogic', filename = MLConfig.CondSelectFunction;
                    case 'BlockLogic', filename = MLConfig.BlockSelectFunction;
                end
                if 5==MLConfig.(obj_tag) && isempty(MLPath.validate_path(filename))
                    [filename,filepath] = uigetfile({'*.m','MATLAB Files'; '*.*','All Files'},'Select a MATLAB script');
                    switch obj_tag
                        case 'CondLogic', MLConfig.CondSelectFunction = fi(0==filename,'',[filepath filename]);
                        case 'BlockLogic', MLConfig.BlockSelectFunction = fi(0==filename,'',[filepath filename]);
                    end
                end
            case 'FallbackScreenRect'
                MLConfig.(obj_tag) = get(gcbo,'string');
            case {'DiagonalSize','ViewingDistance','VsyncSpinlock', ...
                    'FixationPointDeg','EyeTracerSize','JoystickCursorSize','TouchCursorSize','PhotoDiodeTriggerSize', ...
                    'InterTrialInterval','AIOnlineSmoothingWindow','EyeAutoDriftCorrection', ...
                    'TotalNumberOfTrialsToRun','TotalNumberOfBlocksToRun'}
                MLConfig.(obj_tag) = str2double(get(gcbo,'string'));
            case {'FixationPointShape','EyeTracerShape','JoystickCursorShape','TouchCursorShape','USBJoystick','AIConfiguration'}
                items = get(gcbo,'string');
                MLConfig.(obj_tag) = items{get(gcbo,'value')};
                preview();
            case {'AISampleRate'}
                items = get(gcbo,'string');
                MLConfig.(obj_tag) = str2double(items{get(gcbo,'value')});
            case {'SubjectScreenBackground','FixationPointColor','EyeTracerColor','JoystickCursorColor','TouchCursorColor'}
                MLConfig.(obj_tag) = uisetcolor(MLConfig.(obj_tag),'Pick up a color');
                preview();
            case {'FixationPointImage','JoystickCursorImage','TouchCursorImage'}
                [filename,filepath] = uigetfile({'*.bmp;*.gif;*.jpg;*.jpeg;*.tif;*.tiff;*.png;*.avi;*.mpg;*.mpeg','Image/Movie Files'; '*.*','All Files'},'Select a(n) image/movie file',fileparts(MLConfig.(obj_tag)));
                MLConfig.(obj_tag) = fi(0==filename,'',[filepath filename]);
                preview();
            case {'CondSelectFunction','BlockSelectFunction','BlockChangeFunction','UserPlotFunction'}
                [filename,filepath] = uigetfile({'*.m','MATLAB Files'; '*.*','All Files'},'Select a MATLAB script',fileparts(MLConfig.(obj_tag)));
                MLConfig.(obj_tag) = fi(0==filename,'',[filepath filename]);
            case 'LoadSettings'
                check_cfg_change();
                [filename,filepath] = uigetfile({'*_cfg2.mat','MonkeyLogic 2 Configuration'; '*_cfg.mat','MonkeyLogic Configuration'},'Select a config file');
                if 0~=filename
                    try
                        a = whos('-file',[filepath filename]);
                        b = regexp({a.name},'MLConfig_(\S+)','tokens');
                        b = b(~cellfun(@isempty,b));
                        
                        config_by_subject = 'MLConfig';
                        if ~isempty(b)
                            nb = length(b);
                            c = cell(1,nb); for m=1:length(b), c{m} = regexprep(b{m}{1}{1},'(^\S)','${upper($1)}'); end

                            w = 250 ; h = 200 + nb*16;
                            pos = get(hFig,'Position');
                            pos = pos(1:2) + pos(3:4)/2;
                            x = pos(1) - w/2;
                            y = pos(2) - h/2;

                            hDlg = figure;
                            bgcolor = [0.9255 0.9137 0.8471];
                            set(hDlg,'position',[x y w h],'menubar','none','numbertitle','off','name','Choose the config to import','color',bgcolor,'windowstyle','modal');

                            uicontrol('parent',hDlg,'style','pushbutton','position',[w-80 10 70 25],'string','Done','fontsize',fontsize,'callback','uiresume(gcbf);');
                            uicontrol('parent',hDlg,'style','text','position',[10 h-30 230 25],'string','Choose a configuration to import','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','center');
                            uicontrol('parent',hDlg,'style','listbox','position',[10 48 230 125+nb*16],'tag','ConfigList','string',c,'fontsize',fontsize);
                            uiwait(hDlg);

                            if ishandle(hDlg)
                                config_by_subject = ['MLConfig_' b{get(findobj(hDlg,'tag','ConfigList'),'value')}{1}{1}];
                                close(hDlg);
                            end
                        end
                        
                        old_Config = MLConfig;
                        loadcfg([filepath filename],config_by_subject);
                        MLConfig.NumberOfTrialsToRunInThisBlock = old_Config.NumberOfTrialsToRunInThisBlock;
                        MLConfig.CountOnlyCorrectTrials = old_Config.CountOnlyCorrectTrials;
                        MLConfig.BlocksToRun = old_Config.BlocksToRun;
                        if ~isempty(old_Config.SubjectName), old_MLConfig = old_Config; MLConfig.SubjectName = old_Config.SubjectName; end
                        if ~datafilename_manually_typed, MLPath.DataFile = MLConfig.FormattedName; end
                        
                        mlmessage('New config loaded: %s (%s)',filename,filepath);
                    catch err
                        mlmessage('%s (%s, Line %d)',err.message,err.stack(1).name,err.stack(1).line,'e');
                    end
                end
            case 'SaveSettings'
                savecfg(MLPath.ConfigurationFile);
                [p,n,e] = fileparts(MLPath.ConfigurationFile);
                mlmessage('Config saved: %s (%s)',[n e],p);
            case 'LatencyTest'
                try
                    set(gcbo,'enable','off');
                    old_MLConditions = MLConditions;
                    MLConfig.MLConditions = mlconditions([MLPath.BaseDirectory 'mltimetest.m']);
                    create(DAQ,MLConfig,true);
                    create(Screen,MLConfig);
                    result = run_trial(MLConfig);
                catch err
                    mlmessage('%s (%s, Line %d)',err.message,err.stack(1).name,err.stack(1).line,'e');
                end
                set(gcbo,'enable','on');
                % destroy(Screen);
                MLConfig.MLConditions = old_MLConditions;
                if exist('result','var')
                    pos = get(hFig,'position');
                    screen_pos = GetMonitorPosition(Pos2Rect(pos));

                    fw = 800;
                    fh = 600;
                    fx = pos(1) + 0.5 * (pos(3) - fw);
                    if fx < screen_pos(1), fx = screen_pos(1) + 8; end
                    fy = min(pos(2) + 0.5 * (pos(4) - fh),sum(screen_pos([2 4])) - fh - 84);
                    fig_pos = [fx fy fw fh];

                    figure;
                    set(gcf,'position',fig_pos,'color',[0 0 0],'numbertitle','off','name','MonkeyLogic Latency Test');
                    
                    maxtime = 1000;
                    color = { [.8 .8 0],[.8 .8 0] };
                    
                    subplot(2,1,1); hold on;
                    ymax = 0;
                    for m=2
                        x = result{1,m}{1}(3:end) - result{1,m}{1}(2);
                        x = x(x<=maxtime);
                        y = diff(result{1,m}{1}(2:length(x)+2));
                        plot(x, y,'-','LineWidth',1,'Color',color{m});
                        ymax = max([ymax ceil(max(y))]);
                    end
                    set(gca,'box','on','color',[0 0 0],'xlim',[-10 maxtime],'ylim',[-0.1 ymax],'xcolor',[1 1 1],'ycolor',[1 1 1],'yscale','linear');
                    xlabel('Cycle Number');
                    ylabel('Cycle Latency (milliseconds)');
                    htxt = title('Static Picture Display Results');
                    set(htxt,'color',[1 1 1]);
                    
                    subplot(2,1,2); hold on;
                    ymax = 0;
                    for m=2
                        x = result{2,m}{1}(3:end) - result{2,m}{1}(2);
                        x = x(x<=maxtime);
                        y = diff(result{2,m}{1}(2:length(x)+2));
                        plot(x, y,'-','LineWidth',1,'Color',color{m});
                        ymax = max([ymax ceil(max(y))]);
                    end
                    for m=2
                        x = result{2,m}{2}(2:end) - result{2,m}{1}(2);
                        x = x(x<=maxtime);
                        y = ymax*ones(size(x));
                        stem(x,y,'Marker','none','LineWidth',0.5,'Color',[1 0 0]);
                    end
                    set(gca,'box','on','color',[0 0 0],'xlim',[-10 maxtime],'ylim',[-0.1 ymax],'xcolor',[1 1 1],'ycolor',[1 1 1],'yscale','linear');
                    xlabel('Cycle Number');
                    ylabel('Cycle Latency (milliseconds)');
                    htxt = title('Movie Display Results');
                    set(htxt,'color',[1 1 1]);
                end
            case 'EditBehavioralCodesFile', system(MLPath.BehavioralCodesFile);
            case 'EditRewardFunc', system(MLPath.RewardFunction);
            case 'EditAlertFunc', system(MLPath.AlertFunction);
            case 'RemoteAlert', MLConfig.(obj_tag) = ~MLConfig.(obj_tag);
            case {'ExperimentName','Investigator','FilenameFormat'}
                MLConfig.(obj_tag) = get(gcbo,'string');
                if ~datafilename_manually_typed, MLPath.DataFile = MLConfig.FormattedName; end
            case 'DataFile'
                MLPath.DataFile = get(gcbo,'string');
                datafilename_manually_typed = ~isempty(MLPath.DataFile) & ~strcmp(MLPath.DataFile,MLConfig.FormattedName);
                if ~datafilename_manually_typed, MLPath.DataFile = MLConfig.FormattedName; end
            case 'SignalType', update_boards(true);
            case 'IOBoards', update_subsystem();
            case 'Subsystem', update_channels();
            case 'VideoTest'
                try
                    set(gcbo,'enable','off');
                    create(Screen,MLConfig);
                    
                    halfx = Screen.SubjectScreenHalfSize(1);
                    halfy = Screen.SubjectScreenHalfSize(2);
                    [x,y] = meshgrid(-halfx:halfx-1, -halfy:halfy-1);
                    dist = sqrt((x.^2) + (y.^2));
                    
                    numcycles = 10;
                    buffer = NaN(numcycles, 1);
                    for m = 1:numcycles
                        rpat = cos(dist./m+2);
                        gpat = cos(dist./(m+5));
                        bpat = cos(dist./(m+8));
                        testpattern = cat(3, rpat, gpat, bpat);
                        testpattern = (testpattern + 1)/2;
                        testpattern = round(255*testpattern);
                        buffer(m) = mgladdbitmap(testpattern,1);
                    end
                    
                    for n = 1:numcycles
                        for m = 1:numcycles
                            mglactivategraphic([0 buffer(m)],[false true]);
                            mglrendergraphic;
                            mglpresent(1);
                        end
                        for m = numcycles:-1:1
                            mglactivategraphic([0 buffer(m)],[false true]);
                            mglrendergraphic;
                            mglpresent(1);
                        end
                    end
                    mgldestroygraphic(buffer);
                catch err
                    mlmessage('%s (%s, Line %d)',err.message,err.stack(1).name,err.stack(1).line,'e');
                end
                set(gcbo,'enable','on');
                destroy(Screen);
            case 'IOAssign'
                items = get(findobj(hIO,'tag','Channels'),'string');
                val = get(findobj(hIO,'tag','Channels'),'value');
                io.Channel = cellfun(@str2double,items(val));
                
                entry.SignalType = io.Spec{1};
                entry.Adaptor = IOBoard(io.Board).Adaptor;
                entry.DevID = IOBoard(io.Board).DevID;
                entry.Subsystem = io.SubsystemLabel;
                entry.Channel = io.Channel;
                entry.DIOInfo = [];
                if 3==io.Subsystem
                    nport = length(io.Channel);
                    npanel = 5;
                    if 2 < ceil(nport/npanel), npanel = 10; end
                    w = 100 + 55 * fi(0==floor(nport/npanel),nport,npanel) - 50 * fi(1==nport,0,1); h = 60 + 120 * ceil(nport/npanel);
                    xymouse = get(0,'PointerLocation');
                    x = xymouse(1) - fi(325<w,w-325,w);
                    y = xymouse(2) + 170 - h;
                    
                    hDlg = figure;
                    bgcolor = [0.9255 0.9137 0.8471];
                    set(hDlg,'position',[x y w h],'menubar','none','numbertitle','off','name','Line panel','color',bgcolor,'windowstyle','modal');
                    
                    hListbox = zeros(1,nport);
                    for m=1:nport
                        x = w - 55 * mod(m-1,npanel) - 55; y = 45 + 120 * floor((m-1)/npanel);
                        lines = IOBoard(io.Board).DIOInfo{io.Channel(m)+1,1};
                        if 1==mod(m,5), uicontrol('parent',hDlg,'style','text','position',[10 y+35 40 22],'string','Lines','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left'); end
                        uicontrol('parent',hDlg,'style','text','position',[x-5-45*fi(1==nport,1,0) y+90 55 22],'string',sprintf('Port%d',io.Channel(m)),'backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold');
                        hListbox(m) = uicontrol('parent',hDlg,'style','listbox','position',[x-45*fi(1==nport,1,0) y 45 95],'string',num2cell(lines),'fontsize',fontsize,'min',1,'max',fi(1==io.Spec{3}(2),length(lines),1));
                    end
                    uicontrol('parent',hDlg,'style','pushbutton','position',[w-140 10 60 25],'string','Done','fontsize',fontsize,'callback','uiresume(gcbf);');
                    uicontrol('parent',hDlg,'style','pushbutton','position',[w-70 10 60 25],'string','Cancel','fontsize',fontsize,'callback','close(gcbf);');
                    if 1<nport, uicontrol('parent',hDlg,'style','text','position',[0 h-25 w 20],'string',fi(2==nport,'<- Most sig. bit | Least sig. bit ->','<- Most significant bit | Least significant bit ->'),'backgroundcolor',bgcolor,'fontsize',7); end
                    uiwait(hDlg);
                    
                    if ~ishandle(hDlg), return, end
                    entry.DIOInfo = cell(nport,2);
                    for m=1:nport
                        str = get(hListbox(m),'string');
                        val = get(hListbox(m),'value');
                        entry.DIOInfo{m,1} = cellfun(@str2double,str(val))';
                        entry.DIOInfo{m,2} = fi(1==io.Spec{3}(1),'out','in');
                    end
                    close(hDlg);
                end
                if assign_IO(entry)
                    if ~isempty(MLConfig.IO) && any(strcmp({MLConfig.IO.SignalType},io.Spec{1})), clear_IO(io.Spec{1},false); end
                    if isempty(MLConfig.IO), MLConfig.IO = entry; else MLConfig.IO(end+1,1) = entry; end
                    [~,I] = sort({MLConfig.IO.SignalType}); MLConfig.IO = MLConfig.IO(I);
                    update_boards();
                end
            case 'IOClear'
                clear_IO(io.Spec{1});
                update_boards();
            case 'NonDAQDevices'
                if any(strcmpi('joystick',daqhwinfo('all'))), info = daqhwinfo('joystick'); joyid = ['None'; info.InstalledBoardIds']; else, joyid = {'None'}; end
                if isempty(MLConfig.EyeTracker.ViewPoint)
                    MLConfig.EyeTracker.ViewPoint.IP_address = '169.254.110.159';
                    MLConfig.EyeTracker.ViewPoint.Port = '5000';
                    MLConfig.EyeTracker.ViewPoint.Source = [ 0,2,0.5,20; 0,10,0.5,-20; 0,1,0,1; 0,1,0,1; 0,1,0,1; 0,1,0,1; 0,1,0,1; 0,1,0,1 ];
                end
                if isempty(MLConfig.EyeTracker.EyeLink)
                    MLConfig.EyeTracker.EyeLink.IP_address = '100.1.1.1';
                    MLConfig.EyeTracker.EyeLink.Filter = 0;     % 0: off, 1: std, 2: extra
                    MLConfig.EyeTracker.EyeLink.PupilSize = 2;  % 1: area, 2: diameter
                    MLConfig.EyeTracker.EyeLink.Source = [ 2,2,0,-0.0005; 2,5,0,0.0005; 2,1,0,1; 2,1,0,1; 2,1,0,1; 2,1,0,1 ];
                end
                supported = mdqmex(50,2);
                ntracker = size(eyetrackers,1);
                row = true(ntracker,1);
                for m=2:ntracker, row(m) = ismember(eyetrackers{m,2},supported); end
                eyetrackers = eyetrackers(row,:);

                w = 345 ; h = 510;
                xymouse = get(0,'PointerLocation');
                x = xymouse(1) - w;
                y = xymouse(2) - 310;
                
                hDlg = figure;
                bgcolor = [0.9255 0.9137 0.8471];
                set(hDlg,'tag','NonDAQSettings','position',[x y w h],'menubar','none','numbertitle','off','name','Non-DAQ Device Settings','color',bgcolor,'windowstyle','modal');
                callback = @update_nondaqUI;

                x0 = 10;
                y0 = h;
                uicontrol('parent',hDlg,'style','text','position',[x0 y0-40 200 25],'string','Touchscreen','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
                hNonDAQ.Touchscreen(1) = uicontrol('parent',hDlg,'style','checkbox','position', [x0+125 y0-30 15 15],'value',MLConfig.Touchscreen,'backgroundcolor',bgcolor,'callback',callback);
                hNonDAQ.Touchscreen(2) = uicontrol('parent',hDlg,'style','text','position',[x0+160 y0-40 200 25],'string','Run Message Loop','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
                hNonDAQ.Touchscreen(3) = uicontrol('parent',hDlg,'style','checkbox','position', [x0+280 y0-30 15 15],'value',MLConfig.RunMessageLoop,'backgroundcolor',bgcolor);
                uicontrol('parent',hDlg,'style','text','position',[x0 y0-70 200 25],'string','USB Joystick','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
                hNonDAQ.USBJoystick = uicontrol('parent',hDlg,'style','popupmenu','position',[x0+125 y0-62 55 22],'string',joyid,'fontsize',fontsize);
                uicontrol('parent',hDlg,'style','text','position',[x0 y0-100 200 25],'string','TCP/IP Eye Tracker','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
                hNonDAQ.EyeTracker = uicontrol('parent',hDlg,'style','popupmenu','position',[x0+125 y0-92 200 22],'string',eyetrackers(:,1),'fontsize',fontsize,'callback',callback);
                MLConfig.USBJoystick = set_listbox_value(hNonDAQ.USBJoystick,MLConfig.USBJoystick);
                MLConfig.EyeTracker.Name = set_listbox_value(hNonDAQ.EyeTracker,MLConfig.EyeTracker.Name);

                hNonDAQ.ViewPoint.IP_address(1) = uicontrol('parent',hDlg,'style','text','position',[x0+125 y0-130 200 25],'string','IP address','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
                hNonDAQ.ViewPoint.IP_address(2) = uicontrol('parent',hDlg,'style','edit','position',[x0+195 y0-123 130 25],'string',MLConfig.EyeTracker.ViewPoint.IP_address,'fontsize',fontsize);
                hNonDAQ.ViewPoint.Port(1) = uicontrol('parent',hDlg,'style','text','position',[x0+125 y0-160 200 25],'string','Port','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
                hNonDAQ.ViewPoint.Port(2) = uicontrol('parent',hDlg,'style','edit','position',[x0+195 y0-153 130 25],'string',MLConfig.EyeTracker.ViewPoint.Port,'fontsize',fontsize);
                x1 = x0;
                y1 = y0-185;
                viewpoint_eye = {'Eye A','Eye B'};
                viewpoint_source = {'None', ...
                    'X Gaze Point','X Gaze Point Smoothed','X Gaze Point Corrected','X Gaze Angle','X Gaze Angle Smoothed','X Gaze Angle Corrected','X Pupil Size','X Velocity', ...
                    'Y Gaze Point','Y Gaze Point Smoothed','Y Gaze Point Corrected','Y Gaze Angle','Y Gaze Angle Smoothed','Y Gaze Angle Corrected','Y Pupil Size','Y Velocity', ...
                    'Pupil Angle','Pupil Aspect Ratio','Total Velocity','Torsion','Drift','Fixation Time','Data Quality'};
                hNonDAQ.ViewPoint.Source(1,1) = uicontrol('parent',hDlg,'style','text','position',[x1 y1 60 22],'string','Eye','backgroundcolor',bgcolor,'fontsize',fontsize);
                hNonDAQ.ViewPoint.Source(1,2) = uicontrol('parent',hDlg,'style','text','position',[x1+65 y1 170 22],'string','Source','backgroundcolor',bgcolor,'fontsize',fontsize);
                hNonDAQ.ViewPoint.Source(1,3) = uicontrol('parent',hDlg,'style','text','position',[x1+235 y1 50 22],'string','Offset','backgroundcolor',bgcolor,'fontsize',fontsize);
                hNonDAQ.ViewPoint.Source(1,4) = uicontrol('parent',hDlg,'style','text','position',[x1+280 y1 50 22],'string','Gain','backgroundcolor',bgcolor,'fontsize',fontsize);
                for m=1:8
                    for n=1:4
                        x2 = x1;
                        y2 = y1 - 30*m + 10;
                        if 2==m, enable = 'off'; else, enable = 'on'; end
                        switch n
                            case 1
                                switch m
                                    case 1, hNonDAQ.ViewPoint.Source(m+1,n) = uicontrol('parent',hDlg,'style','popupmenu','position',[x2 y2 60 22],'string',viewpoint_eye,'fontsize',fontsize,'enable',enable,'callback',callback);
                                    otherwise, hNonDAQ.ViewPoint.Source(m+1,n) = uicontrol('parent',hDlg,'style','popupmenu','position',[x2 y2 60 22],'string',viewpoint_eye,'fontsize',fontsize,'enable',enable);
                                end
                            case 2
                                switch m
                                    case 1, hNonDAQ.ViewPoint.Source(m+1,n) = uicontrol('parent',hDlg,'style','popupmenu','position',[x2+65 y2 170 22],'string',viewpoint_source(2:4),'fontsize',fontsize,'enable',enable,'callback',callback);
                                    case 2, hNonDAQ.ViewPoint.Source(m+1,n) = uicontrol('parent',hDlg,'style','popupmenu','position',[x2+65 y2 170 22],'string',viewpoint_source(10:12),'fontsize',fontsize,'enable',enable);
                                    otherwise, hNonDAQ.ViewPoint.Source(m+1,n) = uicontrol('parent',hDlg,'style','popupmenu','position',[x2+65 y2 170 22],'string',viewpoint_source,'fontsize',fontsize,'enable',enable);
                                end
                            case 3, hNonDAQ.ViewPoint.Source(m+1,n) = uicontrol('parent',hDlg,'style','edit','position',[x2+240 y2-1 40 24],'fontsize',fontsize);
                            case 4, hNonDAQ.ViewPoint.Source(m+1,n) = uicontrol('parent',hDlg,'style','edit','position',[x2+285 y2-1 40 24],'fontsize',fontsize);
                        end
                    end
                end
                hNonDAQ.ViewPoint.Note(1) = uicontrol('parent',hDlg,'style','text','position',[x2 y2-30 400 22],'string','Note 1. Output = (Raw - Offset) * Gain','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
                hNonDAQ.ViewPoint.Note(2) = uicontrol('parent',hDlg,'style','text','position',[x2 y2-50 400 22],'string','Note 2. To invert output, put a negative gain.','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
                for m=1:8
                    for n=1:4
                        switch n
                            case 1, set(hNonDAQ.ViewPoint.Source(m+1,n),'value',MLConfig.EyeTracker.ViewPoint.Source(m,n)+1);
                            case 2
                                switch m
                                    case 1, set(hNonDAQ.ViewPoint.Source(m+1,n),'value',MLConfig.EyeTracker.ViewPoint.Source(m,n)-1);
                                    case 2, set(hNonDAQ.ViewPoint.Source(m+1,n),'value',MLConfig.EyeTracker.ViewPoint.Source(m,n)-9);
                                    otherwise, set(hNonDAQ.ViewPoint.Source(m+1,n),'value',MLConfig.EyeTracker.ViewPoint.Source(m,n));
                                end
                            case {3,4}, set(hNonDAQ.ViewPoint.Source(m+1,n),'string',MLConfig.EyeTracker.ViewPoint.Source(m,n));
                        end
                    end
                end
                hNonDAQ.ViewPoint.Test(1) = uicontrol('parent',hDlg,'style','text','position',[x0+10 y0-130 80 25],'string','','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold');
                hNonDAQ.ViewPoint.Test(2) = uicontrol('parent',hDlg,'style','pushbutton','position',[x0+25 y0-155 50 25],'string','Test','fontsize',fontsize,'callback',@test_eyetracker_connection);
                
                hNonDAQ.EyeLink.IP_address(1) = uicontrol('parent',hDlg,'style','text','position',[x0+125 y0-130 200 25],'string','IP address','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
                hNonDAQ.EyeLink.IP_address(2) = uicontrol('parent',hDlg,'style','edit','position',[x0+195 y0-123 130 25],'string',MLConfig.EyeTracker.EyeLink.IP_address,'fontsize',fontsize);
                hNonDAQ.EyeLink.Filter(1) = uicontrol('parent',hDlg,'style','text','position',[x0+125 y0-160 200 25],'string','Filter','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
                hNonDAQ.EyeLink.Filter(2) = uicontrol('parent',hDlg,'style','popupmenu','position',[x0+195 y0-153 130 25],'string',{'Off','Standard','Extra'},'value',MLConfig.EyeTracker.EyeLink.Filter+1,'fontsize',fontsize);
                hNonDAQ.EyeLink.PupilSize(1) = uicontrol('parent',hDlg,'style','text','position',[x0+125 y0-190 200 25],'string','Pupil Size','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
                hNonDAQ.EyeLink.PupilSize(2) = uicontrol('parent',hDlg,'style','popupmenu','position',[x0+195 y0-183 130 25],'string',{'Area','Diameter'},'value',MLConfig.EyeTracker.EyeLink.PupilSize,'fontsize',fontsize);
                x1 = x0;
                y1 = y0-215;
                eyelink_eye = {'Left','Right','Auto'};
                eyelink_source = {'None','X Raw','X Head Referenced','X Gaze','Y Raw','Y Head Referenced','Y Gaze','Pupil Size'};
                hNonDAQ.EyeLink.Source(1,1) = uicontrol('parent',hDlg,'style','text','position',[x1 y1 60 22],'string','Eye','backgroundcolor',bgcolor,'fontsize',fontsize);
                hNonDAQ.EyeLink.Source(1,2) = uicontrol('parent',hDlg,'style','text','position',[x1+65 y1 150 22],'string','Source','backgroundcolor',bgcolor,'fontsize',fontsize);
                hNonDAQ.EyeLink.Source(1,3) = uicontrol('parent',hDlg,'style','text','position',[x1+215 y1 60 22],'string','Offset','backgroundcolor',bgcolor,'fontsize',fontsize);
                hNonDAQ.EyeLink.Source(1,4) = uicontrol('parent',hDlg,'style','text','position',[x1+270 y1 60 22],'string','Gain','backgroundcolor',bgcolor,'fontsize',fontsize);
                for m=1:6
                    for n=1:4
                        x2 = x1;
                        y2 = y1 - 30*m + 10;
                        if 2==m, enable = 'off'; else, enable = 'on'; end
                        switch n
                            case 1
                                switch m
                                    case 1, hNonDAQ.EyeLink.Source(m+1,n) = uicontrol('parent',hDlg,'style','popupmenu','position',[x2 y2 60 22],'string',eyelink_eye,'fontsize',fontsize,'enable',enable,'callback',callback);
                                    otherwise, hNonDAQ.EyeLink.Source(m+1,n) = uicontrol('parent',hDlg,'style','popupmenu','position',[x2 y2 60 22],'string',eyelink_eye,'fontsize',fontsize,'enable',enable);
                                end
                            case 2
                                switch m
                                    case 1, hNonDAQ.EyeLink.Source(m+1,n) = uicontrol('parent',hDlg,'style','popupmenu','position',[x2+65 y2 150 22],'string',eyelink_source(2),'fontsize',fontsize,'enable','off');
                                    case 2, hNonDAQ.EyeLink.Source(m+1,n) = uicontrol('parent',hDlg,'style','popupmenu','position',[x2+65 y2 150 22],'string',eyelink_source(5),'fontsize',fontsize,'enable','off');
                                    otherwise, hNonDAQ.EyeLink.Source(m+1,n) = uicontrol('parent',hDlg,'style','popupmenu','position',[x2+65 y2 150 22],'string',eyelink_source,'fontsize',fontsize,'enable',enable);
                                end
                            case 3, hNonDAQ.EyeLink.Source(m+1,n) = uicontrol('parent',hDlg,'style','edit','position',[x2+220 y2-1 50 24],'fontsize',fontsize);
                            case 4, hNonDAQ.EyeLink.Source(m+1,n) = uicontrol('parent',hDlg,'style','edit','position',[x2+275 y2-1 50 24],'fontsize',fontsize);
                        end
                    end
                end
                hNonDAQ.EyeLink.Note(1) = uicontrol('parent',hDlg,'style','text','position',[x2 y2-30 400 22],'string','Note 1. In the binocular setting, ''Auto'' will be the Left eye.','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
                hNonDAQ.EyeLink.Note(2) = uicontrol('parent',hDlg,'style','text','position',[x2 y2-50 400 22],'string','Note 2. Output = (Raw - Offset) * Gain','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
                hNonDAQ.EyeLink.Note(3) = uicontrol('parent',hDlg,'style','text','position',[x2 y2-70 400 22],'string','Note 3. To invert output, put a negative gain.','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
                for m=1:6
                    for n=1:4
                        switch n
                            case 1, set(hNonDAQ.EyeLink.Source(m+1,n),'value',MLConfig.EyeTracker.EyeLink.Source(m,n)+1);
                            case 2
                                switch m
                                    case 1, set(hNonDAQ.EyeLink.Source(m+1,n),'value',MLConfig.EyeTracker.EyeLink.Source(m,n)-1);
                                    case 2, set(hNonDAQ.EyeLink.Source(m+1,n),'value',MLConfig.EyeTracker.EyeLink.Source(m,n)-4);
                                    otherwise, set(hNonDAQ.EyeLink.Source(m+1,n),'value',MLConfig.EyeTracker.EyeLink.Source(m,n));
                                end
                            case {3,4}, set(hNonDAQ.EyeLink.Source(m+1,n),'string',MLConfig.EyeTracker.EyeLink.Source(m,n));
                        end
                    end
                end
                hNonDAQ.EyeLink.Test(1) = uicontrol('parent',hDlg,'style','text','position',[x0+10 y0-130 80 25],'string','','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold');
                hNonDAQ.EyeLink.Test(2) = uicontrol('parent',hDlg,'style','pushbutton','position',[x0+25 y0-155 50 25],'string','Test','fontsize',fontsize,'callback',@test_eyetracker_connection);
                
                uicontrol('parent',hDlg,'style','pushbutton','position',[w-160 10 70 25],'string','Done','fontsize',fontsize,'callback','uiresume(gcbf);');
                uicontrol('parent',hDlg,'style','pushbutton','position',[w-80 10 70 25],'string','Cancel','fontsize',fontsize,'callback','close(gcbf);');
                update_nondaqUI();
                uiwait(hDlg);
                
                if ~ishandle(hDlg), return, end
                MLConfig.Touchscreen = logical(get(hNonDAQ.Touchscreen(1),'value'));
                MLConfig.RunMessageLoop = logical(get(hNonDAQ.Touchscreen(3),'value'));
                MLConfig.USBJoystick = get_listbox_value(hNonDAQ.USBJoystick);
                MLConfig.EyeTracker.Name = get_listbox_value(hNonDAQ.EyeTracker);
                MLConfig.EyeTracker.ID = eyetrackers{get(hNonDAQ.EyeTracker,'value'),2};

                MLConfig.EyeTracker.ViewPoint.IP_address = get(hNonDAQ.ViewPoint.IP_address(2),'string');
                MLConfig.EyeTracker.ViewPoint.Port = get(hNonDAQ.ViewPoint.Port(2),'string');
                for m=1:8
                    for n=1:4
                        switch n
                            case 1, MLConfig.EyeTracker.ViewPoint.Source(m,n) = get(hNonDAQ.ViewPoint.Source(m+1,n),'value')-1;
                            case 2
                                switch m
                                    case 1, MLConfig.EyeTracker.ViewPoint.Source(m,n) = get(hNonDAQ.ViewPoint.Source(m+1,n),'value')+1;
                                    case 2, MLConfig.EyeTracker.ViewPoint.Source(m,n) = get(hNonDAQ.ViewPoint.Source(m+1,n),'value')+9;
                                    otherwise, MLConfig.EyeTracker.ViewPoint.Source(m,n) = get(hNonDAQ.ViewPoint.Source(m+1,n),'value');
                                end
                            case {3,4}, MLConfig.EyeTracker.ViewPoint.Source(m,n) = str2double(get(hNonDAQ.ViewPoint.Source(m+1,n),'string'));
                        end
                    end
                end
                MLConfig.EyeTracker.EyeLink.IP_address = get(hNonDAQ.EyeLink.IP_address(2),'string');
                MLConfig.EyeTracker.EyeLink.Filter = get(hNonDAQ.EyeLink.Filter(2),'value')-1;
                MLConfig.EyeTracker.EyeLink.PupilSize = get(hNonDAQ.EyeLink.PupilSize(2),'value');
                for m=1:6
                    for n=1:4
                        switch n
                            case 1, MLConfig.EyeTracker.EyeLink.Source(m,n) = get(hNonDAQ.EyeLink.Source(m+1,n),'value')-1;
                            case 2
                                switch m
                                    case 1, MLConfig.EyeTracker.EyeLink.Source(m,n) = get(hNonDAQ.EyeLink.Source(m+1,n),'value')+1;
                                    case 2, MLConfig.EyeTracker.EyeLink.Source(m,n) = get(hNonDAQ.EyeLink.Source(m+1,n),'value')+4;
                                    otherwise, MLConfig.EyeTracker.EyeLink.Source(m,n) = get(hNonDAQ.EyeLink.Source(m+1,n),'value');
                                end
                            case {3,4}, MLConfig.EyeTracker.EyeLink.Source(m,n) = str2double(get(hNonDAQ.EyeLink.Source(m+1,n),'string'));
                        end
                    end
                end
                close(hDlg);
            case 'IOTestButton'
                set(gcbo,'enable','off');
                try
                    old_MLConditions = MLConditions;
                    MLConfig.MLConditions = mlconditions([MLPath.BaseDirectory 'mliotest.m']);
                    create(DAQ,MLConfig,true);
                    create(Screen,MLConfig);
                    run_trial(MLConfig);
                catch err
                    mlmessage('%s (%s, Line %d)',err.message,err.stack(1).name,err.stack(1).line,'e');
                end
                % destroy(Screen);
                MLConfig.MLConditions = old_MLConditions;
                set(gcbo,'enable','on');
            case 'StrobePulseSpec'
                w = 435 ; h = 305;
                xymouse = get(0, 'PointerLocation');
                x = xymouse(1) - w;
                y = xymouse(2);
                
                hDlg = figure;
                bgcolor = [0.9255 0.9137 0.8471];
                set(hDlg, 'position',[x y w h],'menubar','none','numbertitle','off','name','Strobe timing specification','color',bgcolor,'windowstyle','modal');
                
                load('mlimagedata.mat','strobe_timing');
                uicontrol('style','pushbutton','position',[0 0 265 305],'tag','StrobeTiming','enable','inactive','cdata',strobe_timing);
                uicontrol('parent',hDlg,'style','pushbutton','position',[w-160 10 70 25],'string','Done','fontsize',fontsize,'callback','uiresume(gcbf);');
                uicontrol('parent',hDlg,'style','pushbutton','position',[w-80 10 70 25],'string','Cancel','fontsize',fontsize,'callback','close(gcbf);');
                uicontrol('parent',hDlg,'style','text','position',[280 260 20 25],'string','T1','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','right');
                uicontrol('parent',hDlg,'style','text','position',[280 230 20 25],'string','T2','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','right');
                uicontrol('parent',hDlg,'style','edit','position',[310 260+4 50 25],'tag','T1','string',num2str(MLConfig.StrobePulseSpec.T1),'fontsize',fontsize);
                uicontrol('parent',hDlg,'style','edit','position',[310 230+4 50 25],'tag','T2','string',num2str(MLConfig.StrobePulseSpec.T2),'fontsize',fontsize);
                uicontrol('parent',hDlg,'style','text','position',[365 260 40 25],'string','usec','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
                uicontrol('parent',hDlg,'style','text','position',[365 230 40 25],'string','usec','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
                uicontrol('parent',hDlg,'style','pushbutton','position',[280 200 90 25],'string','Set default','fontsize',fontsize,'callback','set([findobj(''tag'',''T1'') findobj(''tag'',''T2'')],''string'',''125'')');
                uiwait(hDlg);
                
                if ~ishandle(hDlg), return, end
                MLConfig.StrobePulseSpec.T1 = str2double(get(findobj(hDlg,'tag','T1'),'string'));
                MLConfig.StrobePulseSpec.T2 = str2double(get(findobj(hDlg,'tag','T2'),'string'));
                close(hDlg);
            case 'StrobeTest'
                try
                    set(gcbo,'enable','off');
                    create(DAQ,MLConfig,true);
                    if ~DAQ.strobe_present
                        switch MLConfig.StrobeTrigger
                            case {1,2}, error('Either ''Behavioral Codes'' or ''Strobe Bit'' is not assigned');
                            case 3, error('''Behavioral Codes'' is not assigned');
                        end
                    end
                    
                    numline = length(DAQ.BehavioralCodes.Line);
                    mlmessage('Sending 10 cycles of 2.^(0:%d)',numline);
                    for m=1:10
                        for n=0:numline-1
                            DAQ.eventmarker(2^n);
                            timer = tic; while toc(timer)<0.01, end
                        end
                        timer = tic; while toc(timer)<0.1, end
                    end
                    mlmessage('Strobe test is done');
                catch err
                    mlmessage('%s (%s, Line %d)',err.message,err.stack(1).name,err.stack(1).line,'e');
                end
                set(gcbo,'enable','on');
            case 'EditRewardArgs'
                w = 250 ; h = 235;
                xymouse = get(0, 'PointerLocation');
                x = xymouse(1) - w;
                y = xymouse(2);
                
                hDlg = figure;
                bgcolor = [0.9255 0.9137 0.8471];
                set(hDlg, 'position',[x y w h],'menubar','none','numbertitle','off','name','Reward variables','color',bgcolor,'windowstyle','modal');
                
                uicontrol('parent',hDlg,'style','pushbutton','position',[w-160 10 70 25],'string','Done','fontsize',fontsize,'callback','uiresume(gcbf);');
                uicontrol('parent',hDlg,'style','pushbutton','position',[w-80 10 70 25],'string','Cancel','fontsize',fontsize,'callback','close(gcbf);');
                uicontrol('parent',hDlg,'style','text','position',[10 195 120 25],'string','JuiceLine','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
                uicontrol('parent',hDlg,'style','text','position',[10 165 120 25],'string','Duration (ms)','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
                uicontrol('parent',hDlg,'style','text','position',[10 135 120 25],'string','Number of Pulses','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
                uicontrol('parent',hDlg,'style','text','position',[10 105 140 25],'string','Time b/w Pulses (ms)','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
                uicontrol('parent',hDlg,'style','text','position',[10 75 120 25],'string','Trigger Voltage','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
                uicontrol('parent',hDlg,'style','text','position',[10 45 120 25],'string','Custom Variables','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
                uicontrol('parent',hDlg,'style','edit','position',[140 198 100 25],'tag','RewardJuiceLine','string',num2str(MLConfig.RewardFuncArgs.JuiceLine),'fontsize',fontsize);
                uicontrol('parent',hDlg,'style','edit','position',[140 168 100 25],'tag','RewardDuration','string',num2str(MLConfig.RewardFuncArgs.Duration),'fontsize',fontsize);
                uicontrol('parent',hDlg,'style','edit','position',[140 138 100 25],'tag','RewardNumReward','string',num2str(MLConfig.RewardFuncArgs.NumReward),'fontsize',fontsize);
                uicontrol('parent',hDlg,'style','edit','position',[140 108 100 25],'tag','RewardPauseTime','string',num2str(MLConfig.RewardFuncArgs.PauseTime),'fontsize',fontsize);
                uicontrol('parent',hDlg,'style','edit','position',[140 78 100 25],'tag','RewardTriggerVal','string',num2str(MLConfig.RewardFuncArgs.TriggerVal),'fontsize',fontsize);
                uicontrol('parent',hDlg,'style','edit','position',[120 48 120 25],'tag','RewardCustom','string',MLConfig.RewardFuncArgs.Custom,'fontsize',fontsize);
                uiwait(hDlg);
                
                if ~ishandle(hDlg), return, end
                MLConfig.RewardFuncArgs.JuiceLine = str2double(get(findobj(hDlg,'tag','RewardJuiceLine'),'string'));
                MLConfig.RewardFuncArgs.Duration = str2double(get(findobj(hDlg,'tag','RewardDuration'),'string'));
                MLConfig.RewardFuncArgs.NumReward = str2double(get(findobj(hDlg,'tag','RewardNumReward'),'string'));
                MLConfig.RewardFuncArgs.PauseTime = str2double(get(findobj(hDlg,'tag','RewardPauseTime'),'string'));
                MLConfig.RewardFuncArgs.TriggerVal = str2double(get(findobj(hDlg,'tag','RewardTriggerVal'),'string'));
                MLConfig.RewardFuncArgs.Custom = get(findobj(hDlg,'tag','RewardCustom'),'string');
                close(hDlg);
            case 'RewardTest'
                try
                    set(gcbo,'enable','off'); drawnow;
                    create(DAQ,MLConfig,true);
                    if ~DAQ.reward_present, error('''Reward'' is not assigned'); end
                    r = MLConfig.RewardFuncArgs;
                    kbdflush;
                    for m=1:r.NumReward
                        DAQ.goodmonkey(r.Duration,'juiceline',r.JuiceLine,'numreward',1,'eval',r.Custom);
                        fprintf('JuiceLine %d, Duration %d ms (%d/%d)\n',r.JuiceLine,r.Duration,m,r.NumReward);
                        ml_kb = kbdgetkey; if 1==ml_kb, mlmessage('Reward Test: aborted by user','e'); break, end
                        if m < r.NumReward, mdqmex(102,r.PauseTime); end
                    end
                catch err
                    mlmessage('%s (%s, Line %d)',err.message,err.stack(1).name,err.stack(1).line,'e');
                end
                set(gcbo,'enable','on');
            case 'ResetEyeCalibration'
                if ~isempty(MLConfig.EyeTransform{MLConfig.EyeCalibration})
                    options.Interpreter = 'tex';
                    options.Default = 'Yes';
                    qstring = ['\fontsize{10}This will delete your eye calibration values' char(10) ...
                        'with [' calibration_method{MLConfig.EyeCalibration} '].' char(10) ...
                        'Do you want to proceed?'];
                    button = questdlg(qstring,'Eye calibration will be reset.','Yes','No',options);
                    if strcmp(button,'Yes'), MLConfig.EyeTransform{MLConfig.EyeCalibration} = []; end
                end
            case 'EyeCalibrationButton'
                try
                    create(DAQ,MLConfig,true);
                    if ~DAQ.eye_present, error('''Eye X & Y'' are not assigned yet.'); end
                    create(Screen,MLConfig);
                    switch MLConfig.EyeCalibration
                        case 2, MLConfig.EyeTransform{MLConfig.EyeCalibration} = mlcalibrate_origin_gain(1,MLConfig);
                        case 3, MLConfig.EyeTransform{MLConfig.EyeCalibration} = mlcalibrate_spatial_transform(1,MLConfig);
                    end
                catch err
                    mlmessage('%s (%s, Line %d)',err.message,err.stack(1).name,err.stack(1).line,'e');
                end
                destroy(Screen);
            case 'EyeCalibrationImportButton'
                [filename,filepath] = uigetfile({'*_cfg2.mat','MonkeyLogic Configuration'},'Select a config file');
                if 0~=filename
                    content = load([filepath filename]);
                    if isfield(content,'MLConfig') && isa(content.MLConfig,'mlconfig')
                        MLConfig.EyeTransform{MLConfig.EyeCalibration} = content.MLConfig.EyeTransform{MLConfig.EyeCalibration};
                    end
                end
            case 'ResetJoystickCalibration'
                if ~isempty(MLConfig.JoystickTransform{MLConfig.JoystickCalibration})
                    options.Interpreter = 'tex';
                    options.Default = 'Yes';
                    qstring = ['\fontsize{10}This will delete your joystick calibration values' char(10) ...
                        'with [' calibration_method{MLConfig.JoystickCalibration} '].' char(10) ...
                        'Do you want to proceed?'];
                    button = questdlg(qstring,'Joystick calibration will be reset.','Yes','No',options);
                    if strcmp(button,'Yes'), MLConfig.JoystickTransform{MLConfig.JoystickCalibration} = []; end
                end
            case 'JoystickCalibrationButton'
                try
                    create(DAQ,MLConfig,true);
                    if ~DAQ.joystick_present, error('''Joystick X & Y'' are not assigned yet.'); end
                    create(Screen,MLConfig);
                    switch MLConfig.JoystickCalibration
                        case 2, MLConfig.JoystickTransform{MLConfig.JoystickCalibration} = mlcalibrate_origin_gain(2,MLConfig);
                        case 3, MLConfig.JoystickTransform{MLConfig.JoystickCalibration} = mlcalibrate_spatial_transform(2,MLConfig);
                    end
                catch err
                    mlmessage('%s (%s, Line %d)',err.message,err.stack(1).name,err.stack(1).line,'e');
                end
                destroy(Screen);
            case 'JoystickCalibrationImportButton'
                [filename,filepath] = uigetfile({'*_cfg2.mat','MonkeyLogic Configuration'},'Select a config file');
                if 0~=filename
                    content = load([filepath filename]);
                    if isfield(content,'MLConfig') && isa(content.MLConfig,'mlconfig')
                        MLConfig.JoystickTransform{MLConfig.JoystickCalibration} = content.MLConfig.JoystickTransform{MLConfig.JoystickCalibration};
                    end
                end
            case 'OpenConfigurationFolder', system(['explorer ' fileparts(MLPath.ConfigurationFile)]);
            case 'LoadConditionsFile'
                try
                    if isempty(MLPath.ConditionsFile) && ispref('NIMH_MonkeyLogic','ConditionsFile')
                        ConditionsFile = getpref('NIMH_MonkeyLogic','ConditionsFile');
                        if 2==exist(ConditionsFile,'file')
                            Path = mlpath;
                            Path.ConditionsFile = ConditionsFile;
                            cd(Path.ExperimentDirectory);
                        end
                    end
                    
                    if ~isempty(MLPath.ConditionsFile), check_cfg_change(); end
                    [n,p] = uigetfile({'*.txt','Conditions files (*.txt)'; '*.m','User-loop files (*.m)'},'Select a Conditions File');
                    if 0==n
                        MLConditions.init();
                        MLPath.ConditionsFile = '';
                        try loadcfg(MLPath.ConfigurationFile); catch, end
                        if ~datafilename_manually_typed, MLPath.DataFile = MLConfig.FormattedName; end
                    else
                        cd(p);
                        set(gcbo,'enable','inactive','string','Loading...');
                        set(findobj(hFig,'tag','RunButton'),'enable','inactive','cdata',runbuttondim_image);
                        drawnow;
                        Conditions = mlconditions(MLPath);
                        Conditions.load_file([p n],gcbo);
                        if isloaded(Conditions)
                            try loadcfg(Conditions.MLPath.ConfigurationFile); catch, end
                            MLConfig.MLConditions = Conditions;
                            MLConditions = MLConfig.MLConditions;
                            mlmessage('New conditions loaded: %s (%s)',n,p);
                            
                            MLPath.ConditionsFile = [p n];
                            addpath(MLPath.ExperimentDirectory);
                            setpref('NIMH_MonkeyLogic','ConditionsFile',MLPath.ConditionsFile);
                            if ~datafilename_manually_typed, MLPath.DataFile = MLConfig.FormattedName; end
                            
                            old_nblock = length(MLConfig.NumberOfTrialsToRunInThisBlock); new_nblock = length(MLConditions.UIVars.BlockList);
                            if 0==new_nblock
                                MLConfig.NumberOfTrialsToRunInThisBlock = [];
                                MLConfig.CountOnlyCorrectTrials = false;
                            elseif 0==old_nblock
                                MLConfig.NumberOfTrialsToRunInThisBlock = repmat(MLConfig.DefaultNumberOfTrialsToRunInThisBlock,1,new_nblock);
                                MLConfig.CountOnlyCorrectTrials = repmat(MLConfig.DefaultCountOnlyCorrectTrials,1,new_nblock);
                            elseif old_nblock < new_nblock
                                MLConfig.NumberOfTrialsToRunInThisBlock(old_nblock+1:new_nblock) = MLConfig.NumberOfTrialsToRunInThisBlock(old_nblock);
                                MLConfig.CountOnlyCorrectTrials(old_nblock+1:new_nblock) = MLConfig.CountOnlyCorrectTrials(old_nblock);
                            else
                                MLConfig.NumberOfTrialsToRunInThisBlock = MLConfig.NumberOfTrialsToRunInThisBlock(1:new_nblock);
                                MLConfig.CountOnlyCorrectTrials = MLConfig.CountOnlyCorrectTrials(1:new_nblock);
                            end
                            trials_per_block = MLConfig.NumberOfTrialsToRunInThisBlock;
                            MLConfig.BlocksToRun = MLConditions.UIVars.BlockList;
                            set(findobj(hFig,'tag','StimulusList'),'value',1);
                            set(findobj(hFig,'tag','BlockList'),'value',1);
                            set(findobj(hFig,'tag','TimingFiles'),'value',1);
                        end
                    end
                    preview();
                catch err
                    mlmessage('%s (%s, Line %d)',err.message,err.stack(1).name,err.stack(1).line,'e');
                end
                set(gcbo,'enable','on');
            case 'EditConditionsFile', system(MLPath.ConditionsFile);
            case 'StimulusList', preview();
            case 'StimulusTest'
                try
                    set([findobj(hFig,'tag','StimulusList') gcbo],'enable','off');
                    mouse = pointingdevice;
                    val = get(findobj(hFig,'tag','StimulusList'),'value');
                    taskobj = MLConditions.UIVars.StimulusList(val);
                    switch lower(taskobj.Attribute{1})
                        case {'gen','fix','dot','pic','crc','sqr','mov'}
                            create(Screen,MLConfig);
                            TaskObject = mltaskobject(taskobj,MLConfig);
                            id = TaskObject.ID;
                            mglsetorigin(id,Screen.SubjectScreenHalfSize);
                            mglactivategraphic(id);  % taskobject is created inactive for userloop
                            
                            mlmessage('Press any key to quit %s...',taskobj.Label);
                            if strcmp(mglgettype(id),'MOVIE')
                                mglsetproperty(id,'looping',true);
                                movie_playback(id);
                            else
                                mglrendergraphic;
                                mglpresent();
                                keypress = []; kbdinit; [~,button] = getsample(mouse);
                                while isempty(keypress) && ~any(button), keypress = kbdgetkey; [~,button] = getsample(mouse); end
                            end
                            destroy(Screen);
                        case 'snd'
                            TaskObject = mltaskobject(taskobj,MLConfig);
                            id = TaskObject.ID;
                            mglactivatesound(id);  % taskobject is created inactive for userloop
                            
                            mlmessage('%s playing...',taskobj.Label);
                            mglplaysound(id);
                            keypress = []; kbdinit; [~,button] = getsample(mouse);
                            while mglgetproperty(id,'isplaying') && isempty(keypress) && ~any(button), keypress = kbdgetkey; [~,button] = getsample(mouse); end
                            mgldestroysound(id);
                            mlmessage('%s done',taskobj.Label);
                        case 'stm'
                            create(DAQ,MLConfig,true);
                            TaskObject = mltaskobject(taskobj,MLConfig);
                            o = DAQ.Stimulation{TaskObject.ID};
                            
                            trigger(o);
                            mlmessage('%s sending...',taskobj.Label);
                            while o.Sending, end
                            mlmessage('%s done',taskobj.Label);
                        case 'ttl'
                            create(DAQ,MLConfig,true);
                            TaskObject = mltaskobject(taskobj,MLConfig);
                            o = DAQ.TTL{TaskObject.ID};
                            
                            for m=1:3
                                putvalue(o,1); mlmessage('%s HI',taskobj.Label);
                                timer = tic; while toc(timer)<0.3, end
                                putvalue(o,0); mlmessage('%s LO',taskobj.Label);
                                timer = tic; while toc(timer)<0.3, end
                            end
                            mlmessage('%s done',taskobj.Label);
                    end
                catch err
                    mlmessage('%s: %s',upper(taskobj.Attribute{1}),err.message,'e');
                end
                set([findobj(hFig,'tag','StimulusList') gcbo],'enable','on');
            case 'NumberOfTrialsToRunInThisBlock'
                trials_per_block = MLConfig.(obj_tag);
                chosen_block = get(findobj(hFig,'tag','BlockList'),'value');
                MLConfig.(obj_tag)(chosen_block) = str2double(get(gcbo,'string'));
            case 'CountOnlyCorrectTrials'
                chosen_block = get(findobj(hFig,'tag','BlockList'),'value');
                MLConfig.(obj_tag)(chosen_block) = get(gcbo,'value');
            case 'ChartBlocks', chart_blocks();
            case 'ApplyToAll'
                MLConfig.NumberOfTrialsToRunInThisBlock(:) = str2double(get(findobj(hFig,'tag','NumberOfTrialsToRunInThisBlock'),'string'));
                MLConfig.CountOnlyCorrectTrials(:) = get(findobj(hFig,'tag','CountOnlyCorrectTrials'),'value');
            case 'ChooseBlocksToRun', val = choose_block(); if ~isempty(val), MLConfig.BlocksToRun = val; end
            case 'ChooseFirstBlockToRun', MLConfig.FirstBlockToRun = choose_block(MLConfig.FirstBlockToRun);
            case 'EditTimingFiles'
                hobj = findobj(hFig,'tag','TimingFiles');
                items = get(hobj,'string');
                val = get(hobj,'value');
                system([MLPath.ExperimentDirectory items{val}]);
            case 'SubjectName'
                val = get(gcbo,'string');
                namelengthlimit = namelengthmax()-length('MLEditable_');
                if isempty(regexp(val,'^[A-Za-z0-9_]+$','once'))
                    mlmessage('Subject Name must use letters, digits and underscores only','e');
                elseif namelengthlimit < length(val)
                    mlmessage('Subject Name must be %d characters or shorter',namelengthlimit,'e');
                else
                    check_cfg_change();
                    MLConfig.(obj_tag) = val;
                    if ~isempty(MLConfig.(obj_tag)), loadcfg(MLPath.ConfigurationFile,['MLConfig_' lower(MLConfig.(obj_tag))]); end
                    if ~datafilename_manually_typed, MLPath.DataFile = MLConfig.FormattedName; end
                end
            case 'MinifyRuntime', MLConfig.MinifyRuntime = get(gcbo,'value');
            case 'Filetype'
                items = get(gcbo,'string');
                MLConfig.(obj_tag) = items{get(gcbo,'value')};
            case 'OpenRuntimeFolder', if exist(MLPath.RunTimeDirectory,'dir'), system(['explorer ' fileparts(MLPath.RunTimeDirectory)]); end
            case 'RunButton'
                set(gcbo,'enable','off');
                try
                    if 1<MLConfig.EyeCalibration && isempty(MLConfig.EyeTransform{MLConfig.EyeCalibration})
                        error('Eye signals are not calibrated yet. Calibrate them first or choose ''Raw Signal''');
                    end
                    if 1<MLConfig.JoystickCalibration && isempty(MLConfig.JoystickTransform{MLConfig.JoystickCalibration})
                        error('Joystick signals are not calibrated yet. Calibrate them first or choose ''Raw Signal''');
                    end
                    
                    datafile = [MLPath.ExperimentDirectory MLConfig.FormattedName MLConfig.Filetype];
                    if 2==exist(datafile,'file')
                        newfilepath = datafile;
                        fileno = 0;
                        while 2==exist(newfilepath,'file')
                            fileno = fileno + 1;
                            newfilename = [MLConfig.FormattedName sprintf('(%d)',fileno) MLConfig.Filetype];
                            newfilepath = [MLPath.ExperimentDirectory newfilename];
                        end
                        options.Interpreter = 'tex';
                        options.Default = 'No';
                        qstring = ['\fontsize{10}Overwrite the existing data file?' char(10) ...
                            'If yes, the old file will be moved to Recycle Bin.' char(10) ...
                            'If no, the new filename will be ' regexprep(newfilename,'([\^_\\])','\\$1')];
                        button = questdlg(qstring,'Data file already exists','Yes','No','Cancel',options);
                        switch button
                            case {'Cancel',''}, error('RunButton:doNothing','Task cancelled');
                            case 'Yes'
                                reviousState = recycle('on');
                                delete(datafile);
                                recycle(reviousState);
                                if 2==exist(datafile,'file'), error('Can''t delete the file. Please choose a different name.'); end
                            case 'No'
                                datafile = newfilepath;
                        end
                    end
                    
                    adapter_dir = [MLPath.BaseDirectory 'ext'];
                    mlminifier([tempdir 'mladapters'],adapter_dir);
                    
                    create(DAQ,MLConfig);
                    create(Screen,MLConfig);
                    if all_DAQ_accounted, savecfg(MLPath.ConfigurationFile); end  % ensure the existence of the configuration file
                    cd(MLPath.ExperimentDirectory);
                    result = run_trial(MLConfig,datafile);
                    if isa(result,'mlconfig')  % MLConfig could be modified during the task, so save it again
                        MLConfig = result;
                        if all_DAQ_accounted, savecfg(MLPath.ConfigurationFile); end
                    end
                    behaviorsummary(datafile);
                catch err
                    if ~strncmpi(err.message,'mgl::Wait4VBlank',16) && ~strcmp(err.identifier,'RunButton:doNothing')
                        mlmessage('%s (%s, Line %d)',err.message,err.stack(1).name,err.stack(1).line,'e');
                        %destroy(Screen);
                        set(gcbo,'enable','on');
                        rethrow(err);
                    end
                end
                %destroy(Screen);
                set(gcbo,'enable','on');
            case 'CollapsedMenu', collapsed_menu = true; setpref('NIMH_MonkeyLogic','CollapsedMenu',collapsed_menu); init_menu();
            case 'ExpandedMenu', collapsed_menu = false; setpref('NIMH_MonkeyLogic','CollapsedMenu',collapsed_menu); init_menu();
            case 'VideoSetting'
			    hVideo = findobj('tag','VideoSettingWindow');
                if isempty(hVideo)
                    mlmainmenu = get(findobj('tag','mlmainmenu'),'position');
                    screen_pos = GetMonitorPosition(Pos2Rect(mlmainmenu));
                    w = 288 ; h = 507;
                    x = mlmainmenu(1) - w - 13;
                    top = mlmainmenu(2) + mlmainmenu(4);
                    y = top - h;
                    if x < screen_pos(1), x = screen_pos(1); end
                    screen_top = screen_pos(2) + screen_pos(4);
                    if screen_top < top, y = screen_top - h - 30; end
					hVideo = figure;
                    set(hVideo,'position',[x y w h],'tag','VideoSettingWindow','closerequestfcn',@close_video_setting,'menubar','none','numbertitle','off','name','Video Settings','color',figure_bgcolor);
                    menu_video(5,505);
                    set(findobj(hFig,'tag','VideoSetting'),'string','Close');
                else
                    close(hVideo);
                end
            case 'IOSetting'
			    hIO = findobj('tag','IOSettingWindow');
                if isempty(hIO)
                    mlmainmenu = get(findobj('tag','mlmainmenu'),'position');
                    screen_pos = GetMonitorPosition(Pos2Rect(mlmainmenu));
                    w = 308 ; h = 603;
                    x = mlmainmenu(1) + mlmainmenu(3) + 13;
                    top = mlmainmenu(2) + mlmainmenu(4);
                    y = top - h;
                    screen_right = screen_pos(1) + screen_pos(3) - w; 
                    if screen_right < x, x = screen_right; end
                    screen_top = screen_pos(2) + screen_pos(4);
                    if screen_top < top, y = screen_top - h - 30; end
					hIO = figure;
                    set(hIO,'position',[x y w h],'tag','IOSettingWindow','closerequestfcn',@close_io_setting,'menubar','none','numbertitle','off','name','I/O Settings','color',figure_bgcolor);
                    menu_io(5,600);
                    set(findobj(hFig,'tag','IOSetting'),'string','Close');
                else
                    close(hIO);
                end
            case 'TaskSetting'
			    hTask = findobj('tag','TaskSettingWindow');
                if isempty(hTask)
                    mlmainmenu = get(findobj('tag','mlmainmenu'),'position');
                    screen_pos = GetMonitorPosition(Pos2Rect(mlmainmenu));
                    w = 593 ; h = 165;
                    x = mlmainmenu(1);
                    y = mlmainmenu(2) - h - 30;
                    if x < screen_pos(1), x = screen_pos(1); end
                    screen_right = screen_pos(1) + screen_pos(3) - w; 
                    if screen_right < x, x = screen_right; end
                    if y < screen_pos(2), y = screen_pos(2); end
					hTask = figure;
                    set(hTask,'position',[x y w h],'tag','TaskSettingWindow','closerequestfcn',@close_task_setting,'menubar','none','numbertitle','off','name','Task Settings','color',figure_bgcolor);
                    menu_task(5,163);
                    set(findobj(hFig,'tag','TaskSetting'),'string','Close');
                else
                    close(hTask);
                end
        end
        update_UI();
    end

    function update_nondaqUI(varargin)
        eyetracker = eyetrackers{get(hNonDAQ.EyeTracker,'value'),2};
        set(hNonDAQ.Touchscreen(2:3),'enable',fi(get(hNonDAQ.Touchscreen(1),'value'),'on','off'));
        set(hNonDAQ.Touchscreen(3),'value',fi(get(hNonDAQ.Touchscreen(1),'value'),get(hNonDAQ.Touchscreen(3),'value'),0));
        for m=fieldnames(hNonDAQ.ViewPoint)', set(hNonDAQ.ViewPoint.(m{1}),'visible','off'); end
        for m=fieldnames(hNonDAQ.EyeLink)', set(hNonDAQ.EyeLink.(m{1}),'visible','off'); end
        switch eyetracker
            case 'viewpoint'
                for m=fieldnames(hNonDAQ.ViewPoint)', set(hNonDAQ.ViewPoint.(m{1}),'visible','on'); end
                set(hNonDAQ.ViewPoint.Source(3,1),'value',get(hNonDAQ.ViewPoint.Source(2,1),'value'));
                set(hNonDAQ.ViewPoint.Source(3,2),'value',get(hNonDAQ.ViewPoint.Source(2,2),'value'));
            case 'eyelink'
                for m=fieldnames(hNonDAQ.EyeLink)', set(hNonDAQ.EyeLink.(m{1}),'visible','on'); end
                set(hNonDAQ.EyeLink.Source(3,1),'value',get(hNonDAQ.EyeLink.Source(2,1),'value'));
        end
    end
    function test_eyetracker_connection(varargin)
        id = eyetrackers{get(hNonDAQ.EyeTracker,'value'),2};
        if isempty(id), return, end
            
        eye = eyetracker(id);
        switch id
            case 'viewpoint'
                eye.setting('Port',get(hNonDAQ.ViewPoint.Port(2),'string'));
                eye.IP_address = get(hNonDAQ.ViewPoint.IP_address(2),'string');
                try
                    eye.Source = [ 0,2,0.5,20 ];
                    connected = eye.Connected;
                catch
                    connected = false;
                end
                set(hNonDAQ.ViewPoint.Test(1),'string',fi(connected,'Connected!!!','Failed!!!'),'foregroundcolor',fi(connected,[0 1 0],[1 0 0]));
            case 'eyelink'
                eye.IP_address = get(hNonDAQ.EyeLink.IP_address(2),'string');
                try
                    eye.Source = [ 2,2,0,-0.00004 ];
                    connected = eye.Connected;
                catch
                    connected = false;
                end
                set(hNonDAQ.EyeLink.Test(1),'string',fi(connected,'Connected!!!','Failed!!!'),'foregroundcolor',fi(connected,[0 1 0],[1 0 0]));
            otherwise, error('Unknown TCP/IP eye tracker type!!!');
        end
        delete(eye);
    end

    function valid = assign_IO(entry)
        valid = [];
        if ~isempty(entry)
            nentry = length(entry);
            valid = true(nentry,1);
            for m=1:nentry
                signaltype = strcmp(MLConfig.IOList(:,1),entry(m).SignalType);
                if ~any(signaltype), valid(m) = false; mlmessage('''%s'': no such signal type',entry(m).SignalType,'e'); continue, end
                board = find(strcmp({IOBoard.Adaptor},entry(m).Adaptor) & strcmp({IOBoard.DevID},entry(m).DevID),1);
                if isempty(board), valid(m) = false; mlmessage('''%s'': can''t find %s:%s',entry(m).SignalType,entry(m).Adaptor,entry(m).DevID,'e'); continue, end
                subsystem = find(strcmp(IOBoard(board).Subsystem,entry(m).Subsystem),1);
                if isempty(subsystem), valid(m) = false; mlmessage('''%s'': %s:%s doesn''t support %s',entry(m).SignalType,entry(m).Adaptor,entry(m).DevID,entry(m).Subsystem,'e'); continue, end
                subsystem = find(strcmp(entry(m).Subsystem,{'AnalogInput','AnalogOutput','DigitalIO'}),1);
                channels = IOBoard(board).Channel{subsystem};
                ch_str = fi(3==subsystem,'Port','Ch');
                no_chan = ~ismember(entry(m).Channel,channels);
                if any(no_chan), valid(m) = false; mlmessage(['''%s'': %s ' ch_str '%s doesn''t exist on %s:%s or is assigned already'],entry(m).SignalType,entry(m).Subsystem,sprintf(' %d',entry(m).Channel(no_chan)),entry(m).Adaptor,entry(m).DevID,'e'); continue, end
                if 3==subsystem
                    nport = length(entry(m).Channel);
                    for n=1:nport
                        no_line = ~ismember(entry(m).DIOInfo{n,1},IOBoard(board).DIOInfo{entry(m).Channel(n)+1,1});
                        if any(no_chan), valid(m) = false; mlmessage('''%s'': Port%d Line%s is(are) assigned already',entry(m).SignalType,entry(m).Channel,sprintf(' %d',entry(m).DIOInfo{n,1}(no_line)),'e'); break, end
                    end
                    if ~valid(m), continue, end
                    
                    for n=1:nport
                        IOBoard(board).DIOInfo{entry(m).Channel(n)+1,1} = mlsetdiff(IOBoard(board).DIOInfo{entry(m).Channel(n)+1,1},entry(m).DIOInfo{n,1});
                        IOBoard(board).DIOInfo{entry(m).Channel(n)+1,2} = entry(m).DIOInfo{n,2};
                    end
                else
                    IOBoard(board).Channel{subsystem} = mlsetdiff(channels,entry(m).Channel);
                end
                IOName{signaltype} = ['{ ' MLConfig.IOList{signaltype,1} ' }'];
            end
        end
        set(findobj(hIO,'tag','SignalType'),'string',IOName);
    end

    function clear_IO(signaltype,update)
        if ~exist('update','var'), update = true; end
        if ischar(signaltype), signaltype = {signaltype}; end
        nentry = length(signaltype);
        for m=1:nentry
            row = strcmp({MLConfig.IO.SignalType},signaltype{m});
            if ~any(row), continue, end
            
            board = find(strcmp({IOBoard.Adaptor},MLConfig.IO(row).Adaptor) & strcmp({IOBoard.DevID},MLConfig.IO(row).DevID),1);
            subsystem = find(strcmp(MLConfig.IO(row).Subsystem,{'AnalogInput','AnalogOutput','DigitalIO'}),1);
            channels = MLConfig.IO(row).Channel;
            IOBoard(board).Channel{subsystem} = union(IOBoard(board).Channel{subsystem},channels);
            if 3==subsystem
                for n=1:length(channels)
                    IOBoard(board).DIOInfo{channels(n)+1,1} = union(IOBoard(board).DIOInfo{channels(n)+1,1},MLConfig.IO(row).DIOInfo{n,1});
                    if length(IOBoard(board).DIOInfo{channels(n)+1,1})==IOBoard(board).DIOInfo{channels(n)+1,3}, IOBoard(board).DIOInfo{channels(n)+1,2} = IOBoard(board).DIOInfo{channels(n)+1,4}; end
                end
            end
            MLConfig.IO(row) = [];
            if isempty(MLConfig.IO), MLConfig.IO = []; end
            
            if update
                row = strcmp(MLConfig.IOList(:,1),signaltype{m});
                IOName{row} = MLConfig.IOList{row,1};
            end
        end
        set(findobj(hIO,'tag','SignalType'),'string',IOName);
    end

    function update_boards(err_display)
        if ~exist('err_display','var'), err_display = false; end

        h = findobj(hIO,'tag','SignalType');
        if isempty(h), return, end
        io.SignalType = get(h,'value');
        io.Spec = MLConfig.IOList(io.SignalType,:);  % label, subsystems, [dio_out multilines]
        if ~iscell(io.Spec{2}), io.Spec{2} = io.Spec(2); end
        
        if ~isempty(MLConfig.IO) && any(strcmp({MLConfig.IO.SignalType},io.Spec{1}))
            row = strcmp({MLConfig.IO.SignalType},io.Spec{1});
            board_status = sprintf('%s:%s',MLConfig.IO(row).Adaptor,MLConfig.IO(row).DevID);
            subsystem_status = MLConfig.IO(row).Subsystem;
            switch subsystem_status
                case {'AnalogInput','AnalogOutput'}, channels_status = ['Channel' sprintf(' %d',MLConfig.IO(row).Channel)];
                case 'DigitalIO'
                    subsystem_status = [subsystem_status sprintf(': ''%s''',MLConfig.IO(row).DIOInfo{1,2})];
                    switch length(MLConfig.IO(row).Channel)
                        case 1, channels_status = ['Port ' sprintf('%d',MLConfig.IO(row).Channel) ', Line ' num2range(MLConfig.IO(row).DIOInfo{1})];
                        otherwise, channels_status = ['Port ' num2range(MLConfig.IO(row).Channel)];
                    end
            end
        else
            board_status = '';
            subsystem_status = 'Not assigned';
            channels_status = '';
        end
        set(findobj(hIO,'tag','IOSignalType'),'string',io.Spec{1});
        set(findobj(hIO,'tag','IOStatusBoard'),'string',board_status);
        set(findobj(hIO,'tag','IOStatusSubsystem'),'string',subsystem_status);
        set(findobj(hIO,'tag','IOStatusChannels'),'string',channels_status);
        
        nboard = length(IOBoard);
        supported_subsystem = cell(nboard,1);
        for m=1:nboard, supported_subsystem{m} = intersect(IOBoard(m).Subsystem,io.Spec{2}); end
        board = {IOBoard(~cellfun(@isempty,supported_subsystem)).DevString};
        set(findobj(hIO,'tag','IOBoards'),'string',board,'value',1);
        if isempty(board)
            if err_display, mlmessage('No IO board supports %sfor %s',sprintf('%s ',io.Spec{2}{:}),io.Spec{1},'e'); end
        else
            update_subsystem();
        end
    end

    function update_subsystem()
        items = get(findobj(hIO,'tag','IOBoards'),'string');
        if isempty(items), return, end
        val = get(findobj(hIO,'tag','IOBoards'),'value');
        io.Board = find(strcmp(items{val},{IOBoard.DevString}),1);
        
        subsystem_supported = intersect(IOBoard(io.Board).Subsystem,io.Spec{2});
        set(findobj(hIO,'tag','Subsystem'),'string',subsystem_supported,'value',1);
        update_channels();
    end

    function update_channels()
        items = get(findobj(hIO,'tag','Subsystem'),'string');
        if isempty(items), return, end
        val = get(findobj(hIO,'tag','Subsystem'),'value');
        io.SubsystemLabel = items{val};
        io.Subsystem = find(strcmp(io.SubsystemLabel,{'AnalogInput','AnalogOutput','DigitalIO'}),1);
        
        channels = IOBoard(io.Board).Channel{io.Subsystem};
        if 3==io.Subsystem
            direction = fi(1==io.Spec{3}(1),'out','in');
            channels = channels(~cellfun(@isempty,IOBoard(io.Board).DIOInfo(:,1)) & ~cellfun(@isempty,strfind(IOBoard(io.Board).DIOInfo(:,2),direction))); %#ok<STRCLFH>
        end
        set(findobj(hIO,'tag','Channels'),'string',num2cell(channels),'value',1,'min',1,'max',fi(3==io.Subsystem & 1==io.Spec{3}(2),length(channels),1));
    end

    function preview()
        hobj = findobj(hFig,'tag','StimulusFigure'); figure(hFig); axis(hobj);
        if ~isconditionsfile(MLConditions), mglimage(earth_image); return, end
        selected = get(findobj(hFig,'tag','StimulusList'),'value');
        if isempty(selected), return, end  % sometimes selected becomes empty because of mouse-clicking timing
        stim = MLConditions.UIVars.StimulusList(get(findobj(hFig,'tag','StimulusList'),'value')).Attribute;
        try
            switch lower(stim{1})
                case {'fix','dot'}, mglimage(load_cursor(MLConfig.FixationPointImage,MLConfig.FixationPointShape,MLConfig.FixationPointColor,MLConfig.FixationPointDeg*MLConfig.PixelsPerDegree(1)));
                case {'pic','mov'}, mglimage(mglimread(stim{2}));
                case 'crc', mglimage(make_circle(MLConfig.PixelsPerDegree(1)*stim{2},stim{3},stim{4}));
                case 'sqr', mglimage(make_rectangle(MLConfig.PixelsPerDegree(1)*stim{2},stim{3},stim{4}));
                case 'snd', plot(load_waveform(stim));
                case 'stm', plot(load_waveform(stim{3}));
                case 'ttl', mglimage(ttl_icon);
                case 'gen'
                    [~,n] = fileparts(stim{2});
                    trialrecord = mltrialrecord;
                    imdata = feval(n,trialrecord.simulate_1st_trial());
                    if ischar(imdata), imdata = mglimread(imdata); end
                    mglimage(imdata);
            end
            set(gca,'Color',MLConfig.SubjectScreenBackground);
        catch err
            mlmessage('%s: %s',upper(stim{1}),err.message,'e');
        end
    end

    function movie_playback(id)
        mouse = pointingdevice;
        mov = mglgetproperty(id);
        line_interval = 15 * Screen.DPI_ratio;
        mglsetorigin(mgladdtext(sprintf('Size: %d x %d',mov.Size),9),[10 0]);
        txt_frame  = mgladdtext('',9); mglsetorigin(txt_frame, [10 line_interval]);
        mglsetorigin(mgladdtext(sprintf('Time per frame: %f s',mov.TimePerFrame),9),[10 line_interval*2]);
        txt_buf    = mgladdtext('',9); mglsetorigin(txt_buf,   [10 line_interval*3]);
        txt_render = mgladdtext('',9); mglsetorigin(txt_render,[10 line_interval*4]);
        txt_cur    = mgladdtext('',9); mglsetorigin(txt_cur,   [10 line_interval*5]);
        
        frame_number = 0; rendering_time = 0; keypress = []; kbdinit; [~,button] = getsample(mouse);
        while isempty(keypress) && ~any(button)
            mov = mglgetproperty(id);
            mglsetproperty(txt_frame, 'text',sprintf('Frame number: %07d / %07d',floor(mov.CurrentPosition/mov.TimePerFrame)+1,mov.TotalFrames));
            mglsetproperty(txt_buf,   'text',sprintf('Buffered frames: %d',mov.BufferedFrames));
            mglsetproperty(txt_render,'text',sprintf('Rendering time: %0.3f ms',rendering_time));
            mglsetproperty(txt_cur,   'text',sprintf('Current position: %0.3f s / %0.3f s',mov.CurrentPosition,mov.Duration));
            tic;
            mglrendergraphic(frame_number);
            rendering_time = toc * 1000;
            mglpresent();
            frame_number = frame_number + 1;
            keypress = kbdgetkey;
            [~,button] = getsample(mouse);
        end
    end

    function chart_blocks(hObject,~) %#ok<INUSD>
        if exist('hObject','var')
            cp = get(gca, 'currentpoint');
            cond = max(1,min(floor(cp(1,1)),length(MLConditions.Conditions)));
            label{1} = sprintf('Condition #%d',cond);
            label{2} = sprintf('Timing File: %s',MLConditions.Conditions(cond).TimingFile);
            label{3} = sprintf('Relative Frequency: %d',MLConditions.Conditions(cond).Frequency);
            label{4} = '';
            taskobj =  {MLConditions.Conditions(cond).TaskObject.Label};
            for m = 1:length(taskobj)
                label{m+4} = sprintf('%d: %s',m,taskobj{m});
            end
            set(findobj(gcf,'tag','taskobjects'),'string',label);
        else
            cvals = fi(1==length(MLConditions.UIVars.TimingFiles),1,linspace(0.5,1.5,length(MLConditions.UIVars.TimingFiles)));
            numblocks = length(MLConditions.UIVars.BlockList);
            numconds = length(MLConditions.Conditions);
            bc = NaN(numblocks+1,numconds+1);
            for bnum = 1:numblocks
                usedconds = false(1,numconds);
                for cnum = 1:numconds, usedconds(cnum) = any(bnum==MLConditions.Conditions(cnum).Block); end
                bc(bnum,usedconds) = cvals(MLConditions.UIVars.TimingFilesNo(usedconds));
            end
            
            w = 635 ; h = 480;
            xymouse = get(0,'PointerLocation');
            x = xymouse(1);
            y = xymouse(2) - h/2;
            
            hDlg = figure;
            bgcolor = [0.9255 0.9137 0.8471];
            set(hDlg,'position',[x y w h],'menubar','none','numbertitle','off','name','Block Chart','color',bgcolor,'windowstyle','modal');
            
            h = pcolor(bc);
            set(h,'buttondownfcn',@chart_blocks);
            caxis([0 2]);
            yspace = ceil(numblocks/10);
            xspace = ceil(numconds/10);
            yticks = 1:yspace:numblocks;
            xticks = 1:xspace:numconds;
            if numconds*numblocks > 1000
                shading('flat');
            else
                shading('faceted');
            end
            set(gca,'units','pixel','position',[50 50 360 360],'xtick',1.5:xspace:numconds+0.5,'ytick',1.5:yspace:numblocks+0.5,'xticklabel',xticks,'yticklabel',yticks,'ydir','reverse','xaxislocation','top');
            h(1) = xlabel('Condition #');
            h(2) = ylabel('Block #');
            set(h,'fontsize',12,'fontweight','bold');
            
            uicontrol('parent',hDlg,'style','text','position',[425 385 200 60],'string',['Click on a condition to the left' char(10) 'for details'],'backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold');
            uicontrol('parent',hDlg,'style','listbox','position',[425 50 200 360],'tag','taskobjects','string','TaskObject List...','fontsize',fontsize);
            uicontrol('parent',hDlg,'style','pushbutton','position',[w-90 10 80 25],'string','Done','fontsize',fontsize,'callback','uiresume(gcbf);');
            uiwait(hDlg);
            if ~ishandle(hDlg), return, end
            close(hDlg);
        end
    end

    function val = choose_block(old_val)
        multiselect = fi(exist('old_val','var'),false,true);
        if ~exist('old_val','var'), old_val = []; end
        w = 155 ; h = 180;
        xymouse = get(0, 'PointerLocation');
        x = xymouse(1) - w;
        y = xymouse(2);
        
        hDlg = figure;
        bgcolor = [0.9255 0.9137 0.8471];
        set(hDlg,'position',[x y w h],'menubar','none','numbertitle','off','name','Reward variables','color',bgcolor,'windowstyle','modal');
        
        blocks = MLConditions.UIVars.BlockList;
        uicontrol('parent',hDlg,'style','pushbutton','position',[w-140 10 60 25],'string','Done','fontsize',fontsize,'callback','uiresume(gcbf);');
        uicontrol('parent',hDlg,'style','pushbutton','position',[w-70 10 60 25],'string','Cancel','fontsize',fontsize,'callback','close(gcbf);');
        uicontrol('parent',hDlg,'style','text','position',[0 45 155 126],'string',fi(multiselect,'Blocks to Run','First Block'),'backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold');
        hlist = uicontrol('parent',hDlg,'style','listbox','position',[50 45 60 106],'min',1,'max',fi(multiselect,length(blocks),1),'string',fi(multiselect,num2cell(blocks),['TBD' num2cell(blocks)]),'fontsize',fontsize);
        uiwait(hDlg);
        
        if ~ishandle(hDlg), val = old_val; return, end
        if multiselect
            val = blocks(get(hlist,'value'));
        else
            val = get(hlist,'value');
            if 1<val, val = blocks(val-1); else val = []; end
        end
        close(hDlg);
    end

    function boards = get_board_info()
        hwinfo = daqhwinfo();
        board_count = 0;
        for m=1:length(hwinfo.InstalledAdaptors)
            adaptor = daqhwinfo(hwinfo.InstalledAdaptors{m});
            board_count = board_count + length(adaptor.InstalledBoardIds);
        end
        boards(board_count).DevString = ''; idx = 0;
        for m=1:length(hwinfo.InstalledAdaptors)
            adaptor = daqhwinfo(hwinfo.InstalledAdaptors{m});
            for n=1:length(adaptor.InstalledBoardIds)
                idx = idx + 1;
                boards(idx).DevString = sprintf('%s:%s (%s)',hwinfo.InstalledAdaptors{m},adaptor.InstalledBoardIds{n},adaptor.BoardNames{n});
                boards(idx).Adaptor = hwinfo.InstalledAdaptors{m};
                boards(idx).DevID = adaptor.InstalledBoardIds{n};
                boards(idx).Subsystem = {'','',''}';
                boards(idx).Channel = {'','',''}';
                boards(idx).DIOInfo = [];
                for k=1:3
                    if ~isempty(adaptor.ObjectConstructorName{n,k})
                        obj = eval(adaptor.ObjectConstructorName{n,k});
                        obj_info = daqhwinfo(obj);
                        delete(obj);
                        boards(idx).Subsystem{k} = obj_info.SubsystemType;
                        switch k
                            case 1, boards(idx).Channel{k} = obj_info.SingleEndedIDs;
                            case 2, boards(idx).Channel{k} = obj_info.ChannelIDs;
                            case 3, boards(idx).Channel{k} = [obj_info.Port.ID];
                                boards(idx).DIOInfo = [{obj_info.Port.LineIDs}' {obj_info.Port.Direction}' num2cell(cellfun(@length,{obj_info.Port.LineIDs}')) {obj_info.Port.Direction}'];
                        end
                    end
                end
            end
        end
    end

    function init()
        hFig = findobj('tag','mlmainmenu');
        if ~isempty(hFig), figure(hFig); return, end
        
        if verLessThan('matlab','7.12'), error('NIMH MonkeyLogic requires MATLAB 7.12 (R2011a) or later. Please upgrade your MATLAB first.'); end
        if ~usejava('swing'), error('Java feature ''swing'' must be enabled.'); end
        
        adapter_dir = [tempdir 'mladapters'];
        if ~exist(adapter_dir,'dir'), mkdir(adapter_dir); end
        MLPath.BaseDirectory = mfilename('fullpath');
        addpath(MLPath.BaseDirectory,[MLPath.BaseDirectory 'daqtoolbox'],[MLPath.BaseDirectory 'mgl'],[MLPath.BaseDirectory 'kbd'], adapter_dir, ...
            [MLPath.BaseDirectory 'ext' filesep 'playback'],[MLPath.BaseDirectory 'ext' filesep 'SlackMatlab']);
        
        switch computer
            case 'PCWIN64', arch = { '64-bit', 'x64' };
            case 'PCWIN',   arch = { '32-bit', 'x86' };
            otherwise, error('NIMH MonkeyLogic currently supports Windows only.');
        end
        
        vc_runtime_found = false;
        switch computer
            case 'PCWIN64'
                try winqueryreg('name','HKEY_LOCAL_MACHINE','SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{A749D8E6-B613-3BE3-8F5F-045C84EBA29B}'); vc_runtime_found = true; catch, end  % 12.0.21005
                try winqueryreg('name','HKEY_LOCAL_MACHINE','SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{ABB19BB4-838D-3082-BDA4-87C6604181A2}'); vc_runtime_found = true; catch, end  % 12.0.40649.5
            case 'PCWIN'
                try winqueryreg('name','HKEY_LOCAL_MACHINE','SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{13A4EE12-23EA-3371-91EE-EFB36DDFFF3E}'); vc_runtime_found = true; catch, end  % 12.0.21005
        end
        if ~vc_runtime_found
            pref_value = uigetpref('NIMH_MonkeyLogic','download_vc2013','VC++ 2013 Redistributable is not detected', ...
                ['Visual C++ 2013 Redistributable is required to run MonkeyLogic.' char(10) ...
                'Would you like to download it from the Microsoft website?' char(10) char(10) ...
                'MonkeyLogic may not detect all VC++ 2013 Redistributable versions correctly.' char(10) ...
                'Check the box below before you say No, if you are sure that it is already installed.'], ...
                {'Yes','No'});
            if strcmpi(pref_value,'yes')
                web('https://www.microsoft.com/en-us/download/details.aspx?id=40784','-browser');
                msg = ['NIMH MonkeyLogic requires Microsoft Visual C++ 2013 Redistributable (%s).\n' ...
                    'Please download Visual C++ Redistributable (vcredist_%s.exe) from the following link and install.\n' ...
                    'https://www.microsoft.com/en-us/download/details.aspx?id=40784'];
                error(msg,arch{1},arch{2});
            end
        end
        
        if ~mglcheckdx9
            web('https://www.microsoft.com/en-us/download/details.aspx?displaylang=en&id=35','-browser');
            msg = ['NIMH MonkeyLogic requires DirectX 9.0c runtime which is not installed in this computer.' char(10) ...
                'Please update your DirectX runtime from the Microsoft website.' char(10) ...
                'https://www.microsoft.com/en-us/download/details.aspx?id=35' char(10) char(10) ...
                'If you need a downloadable package, use the following link.' char(10) ...
                'https://www.microsoft.com/en-us/download/details.aspx?id=8109'];
            error(msg);
        end
        
        if verLessThan('matlab','7.14'), RandStream.setDefaultStream(RandStream('mt19937ar','seed',sum(100*clock))); else RandStream.setGlobalStream(RandStream('mt19937ar','seed',sum(100*clock))); end
        
        daqreset; IOBoard = get_board_info();
        MLConfig.MLVersion = fileread([MLPath.BaseDirectory 'NIMH_MonkeyLogic_version.txt']);
        MLConfig.SubjectScreenDevice = System.NumberOfScreenDevices;
        MLConfig.TouchCursorImage = [MLPath.BaseDirectory 'hand_touch.png'];
        
        MLConfig.IOList = mliolist();
        IOName = MLConfig.IOList(:,1);  % for UI
        
        if ispref('NIMH_MonkeyLogic','CollapsedMenu'), collapsed_menu = getpref('NIMH_MonkeyLogic','CollapsedMenu'); end
        scr = GetMonitorPosition(mglgetcommandwindowrect());
        if scr(3) < 1152 || scr(4) < 864, collapsed_menu = true; end
        init_menu();
        
        fprintf('\n\n');
        if isempty(MLConfig.MLVersion), mlmessage('Failed to retrieve the MonkeyLogic version.','e'); else mlmessage('NIMH MonkeyLogic 2 (%s)',MLConfig.MLVersion); end
        if ~isempty(System.OperatingSystem), mlmessage('Operating System: %s',System.OperatingSystem); end
        if ~isempty(System.ComputerName), mlmessage('Computer Name: %s',System.ComputerName); end
        if ~isempty(System.UserName), mlmessage('Logged in as %s',System.UserName); end
        if ~isempty(System.NumberOfProcessors), mlmessage('Detected %s "%s" processors',System.NumberOfProcessors,System.ProcessorArchitecture,'i'); end
        mlmessage('Matlab version: %s', version);
        mlmessage('Found %i video device(s)...', System.NumberOfScreenDevices);
        hwinfo = daqhwinfo; daqdriver = daq.getVendors;
        mlmessage('%s %s', hwinfo.ToolboxName, hwinfo.ToolboxVersion);
        mlmessage('%s %s', daqdriver.FullName, daqdriver.DriverVersion);
        mlmessage('Found %d DAQ adaptor(s), %d board(s)', length(hwinfo.InstalledAdaptors), length(IOBoard));

%         try
%             today = floor(now);
%             check_interval = 1;  % in days
%             if ~ispref('NIMH_MonkeyLogic','LastUpdateCheck'), setpref('NIMH_MonkeyLogic','LastUpdateCheck',today-check_interval-1); end
%             last_check = getpref('NIMH_MonkeyLogic','LastUpdateCheck');
%             if last_check + check_interval < today
%                 tokens = regexpi(MLConfig.Version,'build (\d+)','tokens');
%                 current_build = str2double(tokens{1}{1});
%                 version_str = urlread('ftp://helix.nih.gov/lsn/monkeylogic/NIMH_MonkeyLogic_version.txt');
%                 tokens = regexpi(version_str,'build (\d+)','tokens');
%                 latest_build = str2double(tokens{1}{1});
%                 if current_build < latest_build
%                     setpref('NIMH_MonkeyLogic', 'LastUpdateCheck', today);
%                     mlmessage('A new version (%s) is available at ftp://helix.nih.gov/lsn/monkeylogic/',version_str,'w');
%                 end
%             end
%         catch err
%             mlmessage('Unable to check for MonkeyLogic updates (%s)', err.identifier, 'e');
%         end

        try
            loadcfg(MLPath.ConfigurationFile);
        catch err
            mlmessage('%s (%s, Line %d)',err.message,err.stack(1).name,err.stack(1).line,'e');
        end
        update_UI();
        old_MLConfig = MLConfig;
    end

    function init_menu()
        filetype = {'.bhv2','.h5'};
        message_str = []; if ~isempty(hMessagebox), message_str = get(hMessagebox,'string'); end

        if collapsed_menu
            fw = 593; fh = 528;   % figure size
            x0 = 5; y0 = fh-178;  % conditions file box
            x1 = 310; y1 = 267;   % run box
            x2 = 305; y2 = 29;    % config box
            d = 20;               % width adjustment
        else
            fw = 898; fh = 767;
            x0 = 5; y0 = fh-178;
            x1 = 5; y1 = 215;
            x2 = 595; y2 = 29;
            d = 0;
        end
        if isempty(hFig)
            pos = GetMonitorPosition(mglgetcommandwindowrect);
            fx = pos(1) + 0.5 * (pos(3) - fw);
            if fx < pos(1), fx = pos(1) + 8; end
            fy = min(pos(2) + 0.5 * (pos(4) + fh),pos(2)+pos(4)) - fh - 30;
        else
            pos = get(hFig,'position');
            fx = pos(1);
            fy = pos(2);
            if collapsed_menu, fy = fy + 239; else fy = fy - 239; end
            associated_figures = {'VideoSettingWindow','IOSettingWindow','TaskSettingWindow'};
            for m = 1:length(associated_figures)
                h = findobj('tag',associated_figures{m});
                if ~isempty(h), delete(h); end
            end
            set(hFig,'closerequestfcn','closereq');
            close(hFig);
        end
        
        figsize = [fx fy fw fh];
        hFig = figure;
        set(hFig,'tag','mlmainmenu','numbertitle','off','name',sprintf('NIMH MonkeyLogic 2 (%s)',MLConfig.MLVersion),'menubar','none','position',figsize,'resize','off','color',figure_bgcolor);
        set(hFig,'closerequestfcn',@closeDlg);
        
        x = x0 + 305; y = fh-94;
        uicontrol('style','pushbutton','position',[x y 280 90],'cdata',threemonkeys_image,'callback','web(''http://www.brown.edu/Research/monkeylogic/'',''-browser'')','tooltip','Go to the MonkeyLogic website');
        if collapsed_menu
            uicontrol('style','pushbutton','position',[x+255 y+65 25 25],'tag','ExpandedMenu','cdata',expand_icon,'callback',callbackfunc,'tooltip','Expand the menu');
        else
            uicontrol('style','pushbutton','position',[x+255 y+65 25 25],'tag','CollapsedMenu','cdata',collapse_icon,'callback',callbackfunc,'tooltip','Collapse the menu');
        end
        
        x = x0; y = fh-126; bgcolor = figure_bgcolor;
        uicontrol('style','text','position',[x+50 y+104 200 21],'string','Messages from MonkeyLogic','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold');
        hMessagebox = uicontrol('style','list','position',[x y 300 110],'string',{'<html><font color="gray">>> End of the messages</font></html>'},'backgroundcolor',[1 1 1],'fontsize',fontsize);
        if ~isempty(message_str), set(hMessagebox,'string',message_str,'value',length(message_str)); end

        x = x0 + 5; y = y0; bgcolor = 0.85 * figure_bgcolor;
        uicontrol('style','frame','position',[x-5 y-4 300 53],'backgroundcolor',bgcolor,'foregroundcolor',bgcolor);
        uicontrol('style','pushbutton','position',[x y 230 44],'tag','LoadConditionsFile','backgroundcolor',purple_bgcolor,'fontsize',fontsize,'fontweight','bold','callback',callbackfunc);
        uicontrol('style','pushbutton','position',[x+235 y+22 55 22],'string','Help','backgroundcolor',bgcolor,'fontsize',fontsize,'callback','web(''http://www.brown.edu/Research/monkeylogic/conditionsfiles.html'',''-browser'')','tooltip',['Go to the online document' char(10) 'of the conditions file']);
        uicontrol('style','pushbutton','position',[x+235 y 55 22],'tag','EditConditionsFile','string','Edit','fontsize',fontsize,'callback',callbackfunc,'tooltip','Edit the conditions file');
        x = x0; y = y - 120;
        h = subplot('position',[0.2 0 0.1 0.1]);
        mglimage(earth_image);
        set(h,'tag','StimulusFigure','units','pixel','position',[x+210 y+26 90 90],'xtick',[],'ytick',[],'box','on');
        uicontrol('style','frame','position',[x y 300 26],'backgroundcolor',bgcolor,'foregroundcolor',bgcolor);
        uicontrol('style','frame','position',[x y 210 116],'backgroundcolor',bgcolor,'foregroundcolor',bgcolor);
        bgcolor = figure_bgcolor;
        uicontrol('style','frame','position',[x+300 y 5 26],'backgroundcolor',bgcolor,'foregroundcolor',bgcolor);
        x = x0 + 5; bgcolor = 0.85 * figure_bgcolor;
        uicontrol('style','text','position',[x y+94 200 22],'string','Stimulus list','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold');
        uicontrol('style','listbox','position',[x y 200 100],'tag','StimulusList','fontsize',fontsize,'callback',callbackfunc);
        uicontrol('style','pushbutton','position',[x+205 y 90 22],'tag','StimulusTest','string','Test','fontsize',fontsize,'callback',callbackfunc,'tooltip','Test the selected stimlus');
        uicontrol('style','frame','position',[x-5 y-225 300 225],'backgroundcolor',bgcolor,'foregroundcolor',bgcolor);

        x = x0; y = y - 28;
        uicontrol('style','text','position',[x+72 y+3 200 19],'string','Total # of cond. in this file','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        uicontrol('style','edit','position',[x+240 y+3 55 22],'tag','TotalNumberOfConditions','enable','inactive','backgroundcolor',bgcolor,'fontsize',fontsize,'callback',callbackfunc);
        bgcolor = 0.5 * figure_bgcolor;
        uicontrol('style','frame','position',[x y-100 300 102],'backgroundcolor',bgcolor,'foregroundcolor',bgcolor);
        uicontrol('style','frame','position',[x y-100 69 126],'backgroundcolor',bgcolor,'foregroundcolor',bgcolor);
        x = x0 + 5; fgcolor = [1 1 1];
        uicontrol('style','text','position',[x y+3 60 22],'string','Blocks','backgroundcolor',bgcolor,'foregroundcolor',fgcolor,'fontsize',fontsize,'fontweight','bold');
        uicontrol('style','listbox','position',[x y-97 60 106],'tag','BlockList','fontsize',fontsize,'callback',callbackfunc);
        x = x0; y = y - 25;
        uicontrol('style','text','position',[x+72 y 200 22],'string','Total # of cond. in this block','backgroundcolor',bgcolor,'foregroundcolor',fgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        uicontrol('style','edit','position',[x+240 y+3 55 22],'tag','TotalNumberOfConditionsInThisBlock','backgroundcolor',bgcolor,'foregroundcolor',fgcolor,'fontsize',fontsize,'callback',callbackfunc);
        y = y - 25;
        uicontrol('style','text','position',[x+72 y 200 22],'string','# of trials to run in this block','backgroundcolor',bgcolor,'foregroundcolor',fgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        uicontrol('style','edit','position',[x+240 y+3 55 22],'tag','NumberOfTrialsToRunInThisBlock','fontsize',fontsize,'callback',callbackfunc,'tooltip','The block switches after this number of trials');
        y = y - 25;
        uicontrol('style','text','position',[x+72 y 200 22],'string','Count only correct trials','backgroundcolor',bgcolor,'foregroundcolor',fgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        uicontrol('style','checkbox','position',[x+240 y+6 15 15],'tag','CountOnlyCorrectTrials','backgroundcolor',bgcolor,'callback',callbackfunc);
        x = x0 + 5; y = y - 22;
        uicontrol('style','pushbutton','position',[x+65 y 110 22],'tag','ChartBlocks','string','Chart blocks','fontsize',fontsize,'callback',callbackfunc);
        uicontrol('style','pushbutton','position',[x+180 y 110 22],'tag','ApplyToAll','string','Apply to all','fontsize',fontsize,'callback',callbackfunc);
        y = y - 30; bgcolor = 0.85 * figure_bgcolor;
        uicontrol('style','text','position',[x y 105 22],'string','Blocks to run','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        uicontrol('style','edit','position',[x+85 y+3 145 22],'tag','BlocksToRun','enable','inactive','backgroundcolor',bgcolor,'fontsize',fontsize,'callback',callbackfunc);
        uicontrol('style','pushbutton','position',[x+235 y+3 55 22],'tag','ChooseBlocksToRun','string','Choose','fontsize',fontsize,'callback',callbackfunc);
        y = y - 25;
        uicontrol('style','text','position',[x y 140 22],'string','First block to run','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        uicontrol('style','edit','position',[x+105 y+3 55 22],'tag','FirstBlockToRun','enable','inactive','backgroundcolor',bgcolor,'fontsize',fontsize,'callback',callbackfunc);
        uicontrol('style','pushbutton','position',[x+235 y+3 55 22],'tag','ChooseFirstBlockToRun','string','Choose','fontsize',fontsize,'callback',callbackfunc);
        y = y - 40;
        uicontrol('style','text','position',[x y+17 50 20],'string','Timing','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        uicontrol('style','text','position',[x y-2 40 20],'string','files','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold');
        uicontrol('style','listbox','position',[x+45 y 185 40],'tag','TimingFiles','fontsize',fontsize,'callback',callbackfunc);
        uicontrol('style','pushbutton','position',[x+235 y+20 55 20],'string','Help','backgroundcolor',bgcolor,'fontsize',fontsize,'callback','web(''http://www.brown.edu/Research/monkeylogic/timingscripts.html'',''-browser'')','tooltip',['Go to the online document' char(10) 'of the timing file']);
        uicontrol('style','pushbutton','position',[x+235 y 55 20],'tag','EditTimingFiles','string','Edit','fontsize',fontsize,'callback',callbackfunc,'tooltip','Edit the selected timing file');
     
        x = x1 + 5; y = y1; bgcolor = figure_bgcolor;
        uicontrol('style','text','position',[x y 140 22],'string','Total # of trials to run','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        uicontrol('style','edit','position',[x+140 y+3 55 22],'tag','TotalNumberOfTrialsToRun','fontsize',fontsize,'callback',callbackfunc,'tooltip','The task stops when the trial count reaches this number');
        y = y - 25;
        uicontrol('style','text','position',[x y 140 22],'string','Total # of blocks to run','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        uicontrol('style','edit','position',[x+140 y+3 55 22],'tag','TotalNumberOfBlocksToRun','fontsize',fontsize,'callback',callbackfunc,'tooltip','The task stops when the block count reaches this number');
        y = y - 25;
        uicontrol('style','text','position',[x y 140 22],'string','Experiment name','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        uicontrol('style','edit','position',[x+110 y+3 180-d 22],'tag','ExperimentName','fontsize',fontsize,'callback',callbackfunc);
        y = y - 25;
        uicontrol('style','text','position',[x y 140 22],'string','Investigator','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        uicontrol('style','edit','position',[x+110 y+3 180-d 22],'tag','Investigator','fontsize',fontsize,'callback',callbackfunc);
        bgcolor = purple_bgcolor;
        uicontrol('style','frame','position',[x-5 y-135 300-d 135],'backgroundcolor',bgcolor);
        y = y - 30;
        uicontrol('style','text','position',[x y 140 22],'string','Subject name','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        uicontrol('style','edit','position',[x+100 y+3 190-d 22],'tag','SubjectName','fontsize',fontsize,'callback',callbackfunc);
        y = y - 25;
        uicontrol('style','text','position',[x y 100 22],'string','Filename format','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        uicontrol('style','edit','position',[x+100 y+3 190-d 22],'tag','FilenameFormat','fontsize',fontsize,'callback',callbackfunc,'tooltip',['expname or ename: Experiment Name' char(10) 'yourname or yname: Investigator' char(10) 'condname or cname: Conditions file name' char(10) 'subjname or sname: Subject name' char(10) 'yyyy: Year in full (1990, 2002)' char(10) 'yy: Year in two digits (90, 02)' char(10) 'mmm: Month using first three letters (Mar, Dec)' char(10) 'mm: Month in two digits (03, 12)' char(10) 'ddd: Day using first three letters (Mon, Tue)' char(10) 'dd: Day in two digits (05, 20)' char(10) 'HH: Hour in two digits (05, 24)' char(10) 'MM: Minute in two digits (12, 02)' char(10) 'SS: Second in two digits (07, 59)']);
        y = y - 25;
        uicontrol('style','text','position',[x y+3 50 19],'string','Data file','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        uicontrol('style','edit','position',[x+55 y+3 235-d 22],'tag','DataFile','fontsize',fontsize,'callback',callbackfunc);
        y = y - 25;
        uicontrol('style','text','position',[x y 100 22],'string','Filetype','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        uicontrol('style','popupmenu','position',[x+55 y+3 55 22],'tag','Filetype','string',filetype,'fontsize',fontsize,'callback',callbackfunc);
%         uicontrol('style','text','position',[x y 100 22],'string','Minify runtime','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
%         uicontrol('style','checkbox','position',[x+95 y+6 15 15],'tag','MinifyRuntime','backgroundcolor',bgcolor,'callback',callbackfunc);
        y = y - 25;
        uicontrol('style','text','position',[x y 55 22],'string','Runtime','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        uicontrol('style','pushbutton','position',[x+55 y+3 55 22],'tag','OpenRuntimeFolder','string','Locate','fontsize',fontsize,'callback',callbackfunc,'tooltip','Open the runtime location');
        uicontrol('style','pushbutton','position',[x+135-d y 155 48],'tag','RunButton','enable','inactive','cdata',runbuttondim_image,'callback',callbackfunc);
        
        if collapsed_menu
            hVideo = []; hIO = []; hTask = [];
            x = 310; y = 295; bgcolor = frame_bgcolor;
            uicontrol('style','frame','position',[x y 280 135],'backgroundcolor',bgcolor);
            uicontrol('style','pushbutton','position',[x+5 y+10 90 30],'cdata',taskheader_image,'enable','inactive');
            uicontrol('style','pushbutton','position',[x+190 y+15 80 25],'tag','TaskSetting','string','Settings','fontsize',fontsize,'callback',callbackfunc);
            uicontrol('style','pushbutton','position',[x+4 y+53 180 30],'cdata',ioheader_image,'enable','inactive');
            uicontrol('style','pushbutton','position',[x+190 y+55 80 25],'tag','IOSetting','string','Settings','fontsize',fontsize,'callback',callbackfunc);
            uicontrol('style','pushbutton','position',[x+2 y+88 100 30],'cdata',videoheader_image,'enable','inactive');
            uicontrol('style','pushbutton','position',[x+190 y+95 80 25],'tag','VideoSetting','string','Settings','fontsize',fontsize,'callback',callbackfunc);
        else
            hVideo = hFig; hIO = hFig; hTask = hFig;
            menu_video(310,668);
            menu_io(595,763);
            menu_task(310,163);
        end
        
        x = x2; y = y2; bgcolor = figure_bgcolor;
        x = x + 10;
        uicontrol('style','text','position',[x y 50 22],'string','Config:','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        uicontrol('style','text','position',[x+45 y 530 22],'tag','ConfigurationFile','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left','callback',callbackfunc);
        uicontrol('style','pushbutton','position',[x+235-d y+3 55 22],'tag','OpenConfigurationFolder','string','Locate','fontsize',fontsize,'callback',callbackfunc,'tooltip','Open the configuration file location');
        y = y - 24;
        uicontrol('style','pushbutton','position',[x y 140-d/2 24],'tag','LoadSettings','string','Load settings','fontsize',fontsize,'callback',callbackfunc);
        uicontrol('style','pushbutton','position',[x+150-d/2 y 140-d/2 24],'tag','SaveSettings','enable','off','string','Save settings','fontsize',fontsize,'callback',callbackfunc);
    end

    function menu_video(x0,y0)
        x = x0; y = y0; bgcolor = frame_bgcolor;
        uicontrol('style','frame','position',[x y-500 280 500],'backgroundcolor',bgcolor);
        x = x0 + 180; y = y - 27; bgcolor = figure_bgcolor;
        uicontrol('style','frame','position',[x y 100 27],'backgroundcolor',bgcolor);
        uicontrol('style','frame','position',[x+1 y+1 100 27],'backgroundcolor',bgcolor,'foregroundcolor',bgcolor);
        uicontrol('style','pushbutton','position',[x+5 y+5 95 22],'tag','LatencyTest','string','Latency test','fontsize',fontsize,'callback',callbackfunc,'tooltip','Performance test with pictures and movies');
        x = x0 + 1; y = y - 10;
        uicontrol('style','pushbutton','position',[x y 100 30],'cdata',videoheader_image,'enable','inactive');
        x = x0 + 10; y = y - 23; bgcolor = frame_bgcolor;
        uicontrol('style','text','position',[x y 170 22],'string','Subject screen device','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        uicontrol('style','popupmenu','position',[x+145 y+3 50 22],'tag','SubjectScreenDevice','string',num2cell(1:System.NumberOfScreenDevices),'fontsize',fontsize,'callback',callbackfunc);
        y = y - 25;
        uicontrol('style','text','position',[x y 100 22],'string','Resolution','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left','tooltip','To change the resolution,use the screen menu of Windows');
        uicontrol('style','edit','position',[x+75 y+3 120 22],'tag','Resolution','enable','inactive','backgroundcolor',bgcolor,'fontsize',fontsize);
        y = y - 25;
        uicontrol('style','text','position',[x y 140 22],'string','Diagonal size (cm)','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        uicontrol('style','edit','position',[x+140 y+3 55 22],'tag','DiagonalSize','fontsize',fontsize,'callback',callbackfunc,'tooltip','Diagonal size of the subject screen');
        y = y - 25;
        uicontrol('style','text','position',[x y 140 22],'string','Viewing distance (cm)','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        uicontrol('style','edit','position',[x+140 y+3 55 22],'tag','ViewingDistance','fontsize',fontsize,'callback',callbackfunc,'tooltip','Distance between the subject''eye and the screen');
        y = y - 25;
        uicontrol('style','text','position',[x y 140 22],'string','Pixels per degree','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        uicontrol('style','edit','position',[x+140 y+3 55 22],'tag','PixelsPerDegree','enable','inactive','backgroundcolor',bgcolor,'fontsize',fontsize);
        uicontrol('style','pushbutton','position',[x+203 y+2 58 124],'tag','VideoTest','string','Test','fontsize',fontsize,'callback',callbackfunc,'tooltip','Test the selected subject screen device');
        x = x0 + 5; bgcolor = 0.9 * frame_bgcolor;
        uicontrol('style','frame','position',[x y-81 270 80],'backgroundcolor',bgcolor,'foregroundcolor',0.8 * frame_bgcolor);
        x = x0 + 10; y = y - 30;
        uicontrol('style','text','position',[x y 140 22],'string','Fallback screen rect.','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        uicontrol('style','edit','position',[x+125 y+3 135 22],'tag','FallbackScreenRect','fontsize',fontsize,'callback',callbackfunc,'tooltip',['Format: [LEFT,TOP,RIGHT,BOTTOM]' char(10) 'This window will be used as the subject screen' char(10) 'when there is only one monitor available' char(10) 'or when forced to use it']);
        y = y - 25;
        uicontrol('style','text','position',[x y 180 22],'string','Forced use of fallback screen','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        uicontrol('style','checkbox','position',[x+180 y+6 15 15],'tag','ForcedUseOfFallbackScreen','backgroundcolor',bgcolor,'fontsize',fontsize,'callback',callbackfunc);
        y = y - 25;
        uicontrol('style','text','position',[x y 105 22],'string','Vsync spinlock','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        uicontrol('style','edit','position',[x+100 y+3 30 22],'tag','VsyncSpinlock','fontsize',fontsize,'callback',callbackfunc,'tooltips',['This determines when MonkeyLogic has to stop doing' char(10) 'other things and wait for the vertical blank time']);
        uicontrol('style','text','position',[x+135 y 120 22],'string','msec before vblank','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
        y = y - 30; bgcolor = frame_bgcolor;
        uicontrol('style','text','position',[x y 170 22],'string','Subject screen background','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        uicontrol('style','pushbutton','position',[x+165 y+3 100 22],'tag','SubjectScreenBackground','string','Color','fontsize',fontsize,'callback',callbackfunc);
        y = y - 30;
        uicontrol('style','text','position',[x y 115 22],'string','Fixation point','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        uicontrol('style','pushbutton','position',[x+80 y+3 185 22],'tag','FixationPointImage','fontsize',fontsize,'callback',callbackfunc);
        y = y - 25;
        uicontrol('style','text','position',[x+25 y 50 22],'string','or use','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','right');
        uicontrol('style','popupmenu','position',[x+80 y+3 65 22],'tag','FixationPointShape','string',{'Circle','Square'},'fontsize',fontsize,'callback',callbackfunc);
        uicontrol('style','pushbutton','position',[x+150 y+3 55 22],'tag','FixationPointColor','string','Color','fontsize',fontsize,'callback',callbackfunc);
        uicontrol('style','edit','position',[x+210 y+3 35 22],'tag','FixationPointDeg','fontsize',fontsize,'callback',callbackfunc,'tooltip','Radius in degrees');
        uicontrol('style','text','position',[x+245 y 24 22],'string','deg','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
        y = y - 30;
        uicontrol('style','text','position',[x y 95 22],'string','Eye tracer','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        uicontrol('style','popupmenu','position',[x+80 y+3 65 22],'tag','EyeTracerShape','string',{'Line','Circle','Square'},'fontsize',fontsize,'callback',callbackfunc);
        uicontrol('style','pushbutton','position',[x+150 y+3 55 22],'tag','EyeTracerColor','string','Color','fontsize',fontsize,'callback',callbackfunc);
        uicontrol('style','edit','position',[x+210 y+3 35 22],'tag','EyeTracerSize','fontsize',fontsize,'callback',callbackfunc);
        uicontrol('style','text','position',[x+245 y 20 22],'string','px','backgroundcolor',bgcolor,'fontsize',fontsize);
        y = y - 30;
        uicontrol('style','text','position',[x y+8 50 18],'string','Joystick','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        uicontrol('style','text','position',[x+35 y-4 40 18],'string','cursor','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        uicontrol('style','pushbutton','position',[x+80 y+3 185 22],'tag','JoystickCursorImage','fontsize',fontsize,'callback',callbackfunc);
        y = y - 25;
        uicontrol('style','text','position',[x+25 y 50 22],'string','or use','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','right');
        uicontrol('style','popupmenu','position',[x+80 y+3 65 22],'tag','JoystickCursorShape','string',{'Circle','Square'},'fontsize',fontsize,'callback',callbackfunc);
        uicontrol('style','pushbutton','position',[x+150 y+3 55 22],'tag','JoystickCursorColor','string','Color','fontsize',fontsize,'callback',callbackfunc);
        uicontrol('style','edit','position',[x+210 y+3 35 22],'tag','JoystickCursorSize','fontsize',fontsize,'callback',callbackfunc);
        uicontrol('style','text','position',[x+245 y 20 22],'string','px','backgroundcolor',bgcolor,'fontsize',fontsize);
        y = y - 30;
        uicontrol('style','text','position',[x y 115 22],'string','Touch cursor','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        uicontrol('style','pushbutton','position',[x+80 y+3 185 22],'tag','TouchCursorImage','fontsize',fontsize,'callback',callbackfunc);
        y = y - 25;
        uicontrol('style','text','position',[x+25 y 50 22],'string','or use','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','right');
        uicontrol('style','popupmenu','position',[x+80 y+3 65 22],'tag','TouchCursorShape','string',{'Circle','Square'},'fontsize',fontsize,'callback',callbackfunc);
        uicontrol('style','pushbutton','position',[x+150 y+3 55 22],'tag','TouchCursorColor','string','Color','fontsize',fontsize,'callback',callbackfunc);
        uicontrol('style','edit','position',[x+210 y+3 35 22],'tag','TouchCursorSize','fontsize',fontsize,'callback',callbackfunc);
        uicontrol('style','text','position',[x+245 y 20 22],'string','px','backgroundcolor',bgcolor,'fontsize',fontsize);
        y = y - 30;
        uicontrol('style','text','position',[x y 140 22],'string','Photodiode trigger','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        uicontrol('style','popupmenu','position',[x+115 y+3 88 22],'tag','PhotoDiodeTrigger','string',{'None','Upper left','Upper right','Lower right','Lower left'},'fontsize',fontsize,'callback',callbackfunc);
        uicontrol('style','edit','position',[x+210 y+3 35 22],'tag','PhotoDiodeTriggerSize','fontsize',fontsize,'callback',callbackfunc);
        uicontrol('style','text','position',[x+245 y 20 22],'string','px','backgroundcolor',bgcolor,'fontsize',fontsize);
    end

    function menu_io(x0,y0)
        ai_configuration = {'Differential','SingleEnded','NonReferencedSingleEnded'};
        reward_polarity = {'trigger on HIGH','trigger on LOW'};
        strobe_trigger = {'on rising edge','on falling edge','send and clear'};
        calibration_method = {'Raw Signal (Precalibrated)','Origin & Gain','2-D Spatial Transformation'};

        x = x0; y = y0; bgcolor = frame_bgcolor;
        uicontrol('style','frame','position',[x y-595 300 595],'backgroundcolor',bgcolor);
        x = x0 + 185; y = y - 27; bgcolor = figure_bgcolor;
        uicontrol('style','frame','position',[x y 115 27],'backgroundcolor',bgcolor);
        uicontrol('style','frame','position',[x+1 y+1 115 27],'backgroundcolor',bgcolor,'foregroundcolor',bgcolor);
        uicontrol('style','pushbutton','position',[x+5 y+5 110 22],'tag','EditBehavioralCodesFile','string','Edit behav. codes','fontsize',fontsize,'callback',callbackfunc);
        x = x0 + 1; y = y - 5; bgcolor = frame_bgcolor;
        uicontrol('style','pushbutton','position',[x y 180 30],'cdata',ioheader_image,'enable','inactive');
        x = x0 + 5; y = y - 119;
        uicontrol('style','text','position',[x y+90 135 22],'string','Signal type','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold');
        uicontrol('style','listbox','position',[x y 135 95],'tag','SignalType','string',IOName,'fontsize',fontsize,'callback',callbackfunc);
        uicontrol('style','text','position',[x+140 y+90 150 22],'string','I/O boards','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold');
        uicontrol('style','listbox','position',[x+140 y 150 95],'tag','IOBoards','fontsize',fontsize,'callback',callbackfunc);
        y = y - 115;
        uicontrol('style','text','position',[x y+90 100 22],'string','Subsystem','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold');
        uicontrol('style','listbox','position',[x y 100 95],'tag','Subsystem','fontsize',fontsize,'callback',callbackfunc);
        uicontrol('style','text','position',[x+100 y+90 55 22],'string','Ch/Ports','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold');
        uicontrol('style','listbox','position',[x+105 y 45 95],'tag','Channels','fontsize',fontsize);
        uicontrol('style','text','position',[x+165 y+90 115 22],'string','Status','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold');
        uicontrol('style','frame','position',[x+155 y+25 135 70],'backgroundcolor',purple_bgcolor,'foregroundcolor',0.8 * purple_bgcolor);
        uicontrol('style','text','position',[x+156 y+72 133 20],'tag','IOSignalType','string','Signal type','backgroundcolor',purple_bgcolor,'fontsize',fontsize,'fontweight','bold');
        uicontrol('style','text','position',[x+156 y+56 133 20],'tag','IOStatusBoard','string','IO board','backgroundcolor',purple_bgcolor,'fontsize',fontsize);
        uicontrol('style','text','position',[x+156 y+40 133 20],'tag','IOStatusSubsystem','string','Subsystem','backgroundcolor',purple_bgcolor,'fontsize',fontsize);
        uicontrol('style','text','position',[x+156 y+26 133 18],'tag','IOStatusChannels','string','Channels/Ports','backgroundcolor',purple_bgcolor,'fontsize',fontsize);
        uicontrol('style','pushbutton','position',[x+155 y 66 22],'tag','IOAssign','string','Assign','fontsize',fontsize,'callback',callbackfunc,'tooltip',['1. Signal type' char(10) '2. IO Boards' char(10) '3. Subsystem' char(10) '4. Channels/Ports' char(10) '5. Assign']);
        uicontrol('style','pushbutton','position',[x+225 y 66 22],'tag','IOClear','string','Clear','fontsize',fontsize,'callback',callbackfunc);
        x = x0 + 10; y = y - 30;
        uicontrol('style','text','position',[x y 210 22],'string','Non-DAQ Devices (USB, TCP/IP, etc)','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        uicontrol('style','pushbutton','position',[x+210 y+3 75 22],'tag','NonDAQDevices','string','Settings','fontsize',fontsize,'callback',callbackfunc);
        x = x0 + 5; bgcolor = 0.9 * frame_bgcolor;
        uicontrol('style','frame','position',[x y-81 290 80],'backgroundcolor',bgcolor,'foregroundcolor',0.8 * frame_bgcolor);
        uicontrol('style','frame','position',[x+165 y+54-81 125 26],'backgroundcolor',bgcolor,'foregroundcolor',0.8 * frame_bgcolor);
        uicontrol('style','frame','position',[x+166 y+55-81 125 26],'backgroundcolor',frame_bgcolor,'foregroundcolor',frame_bgcolor);
        uicontrol('style','pushbutton','position',[x+170 y+59-81 120 22],'tag','IOTestButton','string','I/O Test','fontsize',fontsize,'callback',callbackfunc,'tooltip','Test panel for analoginput, STM and TTL');
        x = x0 + 10; y = y - 30;
        uicontrol('style','text','position',[x y 90 22],'string','AI sample rate','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        uicontrol('style','popupmenu','position',[x+95 y+3 55 22],'tag','AISampleRate','string',{'1000';'500';'250';'100'},'fontsize',fontsize,'callback',callbackfunc);
        y = y - 25;
        uicontrol('style','text','position',[x y 120 22],'string','AI configuration','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        uicontrol('style','popupmenu','position',[x+95 y+3 185 23],'tag','AIConfiguration','string',ai_configuration,'fontsize',fontsize,'callback',callbackfunc);
        y = y - 25;
        uicontrol('style','text','position',[x y 120 22],'string','AI online smoothing','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        uicontrol('style','popupmenu','position',[x+125 y+3 65 22],'tag','AIOnlineSmoothing','string',{'None';'Mean';'Median'},'fontsize',fontsize,'callback',callbackfunc);
        uicontrol('style','text','position',[x+195 y 20 22],'string','of','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
        uicontrol('style','edit','position',[x+212 y+3 30 22],'tag','AIOnlineSmoothingWindow','fontsize',fontsize,'callback',callbackfunc);
        uicontrol('style','text','position',[x+247 y 35 22],'string','msec','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
        y = y - 30; bgcolor = frame_bgcolor;
        uicontrol('style','text','position',[x y 120 22],'string','Strobe','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        uicontrol('style','popupmenu','position',[x+50 y+3 110 22],'tag','StrobeTrigger','string',strobe_trigger,'fontsize',fontsize,'callback',callbackfunc);
        uicontrol('style','pushbutton','position',[x+165 y+3 55 22],'tag','StrobePulseSpec','string','Spec','fontsize',fontsize,'callback',callbackfunc,'tooltip','Set the strobe pulse specification');
        uicontrol('style','pushbutton','position',[x+225 y+3 55 22],'tag','StrobeTest','string','Test','fontsize',fontsize,'callback',callbackfunc,'tooltip','Test Behavioral Codes strobing');
        y = y - 25;
        uicontrol('style','text','position',[x y 50 22],'string','Reward','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        uicontrol('style','edit','position',[x+50 y+3 110 22],'tag','RewardFuncArgs','enable','inactive','backgroundcolor',bgcolor,'fontsize',fontsize,'callback',callbackfunc,'tooltip',['Additional arguments for the custom reward function.' char(10) 'Leave it blank if you don''t have any custom variable.']);
        uicontrol('style','pushbutton','position',[x+165 y+3 55 22],'tag','EditRewardArgs','string','Args','fontsize',fontsize,'callback',callbackfunc,'tooltip','Enter the reward variables');
        uicontrol('style','pushbutton','position',[x+225 y+3 55 22],'tag','EditRewardFunc','string','Edit','fontsize',fontsize,'callback',callbackfunc,'tooltip','Edit the custom reward function');
        y = y - 25;
        uicontrol('style','text','position',[x y 120 22],'string','Reward polarity','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        uicontrol('style','popupmenu','position',[x+95 y+3 125 22],'tag','RewardPolarity','string',reward_polarity,'fontsize',fontsize,'callback',callbackfunc);
        uicontrol('style','pushbutton','position',[x+225 y+3 55 22],'tag','RewardTest','string','Test','fontsize',fontsize,'callback',callbackfunc,'tooltip','Send a test reward pulse');
        x = x0 + 5; bgcolor = 0.9 * frame_bgcolor;
        uicontrol('style','frame','position',[x y-81 290 80],'backgroundcolor',bgcolor,'foregroundcolor',0.8 * frame_bgcolor);
        x = x0 + 10; y = y - 30;
        uicontrol('style','text','position',[x y 120 22],'string','Eye calibration','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        uicontrol('style','popupmenu','position',[x+95 y+3 185 22],'tag','EyeCalibration','string',calibration_method,'fontsize',fontsize,'callback',callbackfunc);
        y = y - 25;
        uicontrol('style','pushbutton','position',[x+35 y+3 55 22],'tag','ResetEyeCalibration','string','Reset','fontsize',fontsize,'callback',callbackfunc);
        uicontrol('style','pushbutton','position',[x+95 y+3 90 22],'tag','EyeCalibrationButton','fontsize',fontsize,'callback',callbackfunc);
        uicontrol('style','pushbutton','position',[x+190 y+3 90 22],'tag','EyeCalibrationImportButton','string','Import Eye Cal','fontsize',fontsize,'callback',callbackfunc);
        y = y - 25;
        uicontrol('style','text','position',[x+95 y 125 22],'string','Auto drift correction','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        uicontrol('style','edit','position',[x+217 y+3 30 22],'tag','EyeAutoDriftCorrection','fontsize',fontsize,'callback',callbackfunc);
        uicontrol('style','text','position',[x+252 y 20 22],'string','%','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
        y = y - 30; bgcolor = frame_bgcolor;
        uicontrol('style','text','position',[x y 120 22],'string','Joy calibration','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        uicontrol('style','popupmenu','position',[x+95 y+3 185 22],'tag','JoystickCalibration','string',calibration_method,'fontsize',fontsize,'callback',callbackfunc);
        y = y - 25;
        uicontrol('style','pushbutton','position',[x+35 y+3 55 22],'tag','ResetJoystickCalibration','string','Reset','fontsize',fontsize,'callback',callbackfunc);
        uicontrol('style','pushbutton','position',[x+95 y+3 90 22],'tag','JoystickCalibrationButton','fontsize',fontsize,'callback',callbackfunc);
        uicontrol('style','pushbutton','position',[x+190 y+3 90 22],'tag','JoystickCalibrationImportButton','string','Import Joy Cal','fontsize',fontsize,'callback',callbackfunc);

        update_boards();
    end

    function menu_task(x0,y0)
        errorlogic = {'ignore','repeat immediately','repeat delayed'};
        condlogic = {'random with replacement','random without replacement','increasing','decreasing','user-defined'};
        blocklogic = condlogic;

        x = x0; y = y0; bgcolor = frame_bgcolor;
        uicontrol('style','frame','position',[x y-158 585 158],'backgroundcolor',bgcolor);
        x = x0 + 285 + 160; y = y - 27; bgcolor = figure_bgcolor;
        uicontrol('style','frame','position',[x y 140 27],'backgroundcolor',bgcolor);
        uicontrol('style','frame','position',[x+1 y+1 140 27],'backgroundcolor',bgcolor,'foregroundcolor',bgcolor);
        uicontrol('style','pushbutton','position',[x+5 y+5 75 22],'tag','RemoteAlert','fontsize',fontsize,'callback',callbackfunc);
        uicontrol('style','pushbutton','position',[x+85 y+5 55 22],'tag','EditAlertFunc','string','Edit','fontsize',fontsize,'callback',callbackfunc,'tooltip','Edit the alert function');
        x = x0 + 10; y = y - 4; bgcolor = frame_bgcolor;
        uicontrol('style','text','position',[x y 120 22],'string','On error','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        uicontrol('style','popupmenu','position',[x+70 y+3 135 22],'tag','ErrorLogic','string',errorlogic,'fontsize',fontsize,'callback',callbackfunc);
        uicontrol('style','pushbutton','position',[x+210 y+3 55 22],'string','Help','backgroundcolor',bgcolor,'fontsize',fontsize,'callback','web(''http://www.brown.edu/Research/monkeylogic/mlmenu.html#trialselectionsettings'',''-browser'')','tooltip',['Go to the online document' char(10) 'of the trial selection settings']);
        y = y - 28;
        uicontrol('style','text','position',[x y 120 22],'string','Conditions','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        uicontrol('style','popupmenu','position',[x+70 y+3 195 22],'tag','CondLogic','string',condlogic,'fontsize',fontsize,'callback',callbackfunc);
        y = y - 25;
        uicontrol('style','pushbutton','position',[x+70 y+3 195 22],'tag','CondSelectFunction','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left','callback',callbackfunc);
        y = y - 25;
        uicontrol('style','text','position',[x y 120 22],'string','Blocks','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        uicontrol('style','popupmenu','position',[x+70 y+3 195 22],'tag','BlockLogic','string',blocklogic,'fontsize',fontsize,'callback',callbackfunc);
        y = y - 25;
        uicontrol('style','pushbutton','position',[x+70 y+3 195 22],'tag','BlockSelectFunction','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left','callback',callbackfunc);
        y = y - 22;
        uicontrol('style','pushbutton','position',[x+70 y+3 195 22],'tag','BlockChangeFunction','fontsize',fontsize,'callback',callbackfunc);
        x = x0 + 285 + 1; y = y0 - 35;
        uicontrol('style','pushbutton','position',[x y 90 30],'cdata',taskheader_image,'enable','inactive');
        x = x0 + 285 + 10; y = y0 - 59;
        uicontrol('style','text','position',[x y 160 22],'string','Inter-trial interval (ITI)','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        uicontrol('style','edit','position',[x+130 y+3 75 22],'tag','InterTrialInterval','fontsize',fontsize,'callback',callbackfunc);
        uicontrol('style','text','position',[x+210 y 45 22],'string','msec','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
        y = y - 23;
%         uicontrol('style','text','position',[x y+2 160 20],'string','Summary scene during ITI','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
%         uicontrol('style','checkbox','position',[x+160 y+6 15 15],'tag','SummarySceneDuringITI','backgroundcolor',bgcolor,'fontsize',fontsize,'callback',callbackfunc);
        uicontrol('style','text','position',[x y+2 200 20],'string','During ITI,  show traces','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
%         uicontrol('style','text','position',[x+65 y+2 160 20],'string','show traces','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        uicontrol('style','checkbox','position',[x+140 y+6 15 15],'tag','SummarySceneDuringITI','backgroundcolor',bgcolor,'fontsize',fontsize,'callback',callbackfunc);
        uicontrol('style','text','position',[x+162 y+2 100 20],'string','&  record signals','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        uicontrol('style','checkbox','position',[x+265 y+6 15 15],'tag','NonStopRecording','backgroundcolor',bgcolor,'fontsize',fontsize,'callback',callbackfunc);
        y = y0 - 105;
        uicontrol('style','pushbutton','position',[x y+3 280 22],'tag','UserPlotFunction','fontsize',fontsize,'callback',callbackfunc);

        x = x0 + 285; y = y0 - 158; bgcolor = figure_bgcolor;
        uicontrol('style','frame','position',[x y 300 52],'backgroundcolor',bgcolor);
        bgcolor = figure_bgcolor;
        uicontrol('style','frame','position',[x+1 y-1 300 52],'backgroundcolor',bgcolor,'foregroundcolor',bgcolor);
    end

    function closeDlg(~,~)
        check_cfg_change();

        delete(MLConfig);
        associated_figures = {'mlmonitor','mlcalibrate','VideoSettingWindow','IOSettingWindow','TaskSettingWindow'};
        for m = 1:length(associated_figures)
            h = findobj('tag',associated_figures{m});
            if ~isempty(h), delete(h); end
        end

        mlmessage('Closed MonkeyLogic...');
        fprintf('\n\n');

        closereq;
    end
    function close_video_setting(~,~)
        hVideo = []; closereq;
        set(findobj(hFig,'tag','VideoSetting'),'string','Settings');
    end
    function close_io_setting(~,~)
        hIO = []; closereq;
        set(findobj(hFig,'tag','IOSetting'),'string','Settings');
    end
    function close_task_setting(~,~)
        hTask = []; closereq;
        set(findobj(hFig,'tag','TaskSetting'),'string','Settings');
    end

    function check_cfg_change()
        qstring = '';
        if ~isequal(MLConfig,old_MLConfig), qstring = 'The configuration has changed.'; end
        if ~isempty(MLPath.ConditionsFile) && 2~=exist(MLPath.ConfigurationFile,'file'), qstring = 'The cfg file doesn''t exist.'; end
        if ~isempty(qstring)
            options.Interpreter = 'tex';
            options.Default = 'No';
            button = questdlg('\fontsize{10}Do you want to save the current configuration?',qstring,'Yes','No',options);
            if strcmp(button,'Yes'), savecfg(MLPath.ConfigurationFile); end
        end
    end

    function savecfg(filepath)
        if 2==exist(filepath,'file'), save(filepath,'MLConfig','-append'); else save(filepath,'MLConfig'); end
        if ~isempty(MLConfig.SubjectName)
            config_by_subject = ['MLConfig_' lower(MLConfig.SubjectName)];
            MLConfig2.(config_by_subject) = MLConfig; %#ok<STRNU>
            save(filepath,'-struct','MLConfig2','-append');
        end
        old_MLConfig = MLConfig;
    end

    function loadcfg(filepath,config_by_subject)
        if ~exist('config_by_subject','var'), config_by_subject = 'MLConfig'; end
        if exist('filepath','var') && 2==exist(filepath,'file')
            content = whos('-file',filepath,config_by_subject);
            if isempty(content) || 0==content.bytes, return; end
            content = load(filepath,config_by_subject);
            if ~isa(content.(config_by_subject),'mlconfig') && ~isfield(content.(config_by_subject),'ImportFromStruct')
                error('Invalid config file: %s',strip_path(filepath));
            end
            
            field = intersect(fieldnames(content.(config_by_subject)),fieldnames(MLConfig));
            for m=1:length(field), MLConfig.(field{m}) = content.(config_by_subject).(field{m}); end
            if isempty(MLConfig.IO), MLConfig.IO = []; end
            old_MLConfig = MLConfig;
            
            IOBoard = get_board_info();
            IOName = MLConfig.IOList(:,1);
            valid = assign_IO(MLConfig.IO);
            all_DAQ_accounted = all(valid);
            MLConfig.IO = MLConfig.IO(valid);
            if isempty(MLConfig.IO), MLConfig.IO = []; end
            update_boards();
        end
    end

    function mlmessage(text,varargin)
        if isempty(text), return, end
        nvarargs = length(varargin);
        if 0==nvarargs
            type = 'i';
        else
            nformat = length(regexp(text,'%[0-9\.\-+ #]*[diuoxXfeEgGcs]'));
            text = sprintf(text,varargin{1:nformat});
            if nformat < nvarargs
                type = varargin{end};
            elseif nvarargs == nformat
                type = 'i';
            else
                error('Not enough input arguments');
            end
        end
        fprintf('<<< MonkeyLogic >>> %s\n',text);
        
        switch lower(type(1))
            case 'e',  icon = 'warning.gif'; color = 'red'; %beep;
            case 'w',  icon = 'help_ex.png'; color = 'blue';
            otherwise, icon = 'help_gs.png'; color = 'black';
        end
        icon = fullfile(matlabroot,'toolbox/matlab/icons',icon);
        str = get(hMessagebox,'string');
        str{end} =  sprintf('<html><img src="file:///%s" height="16" width="16">&nbsp;<font color="%s">%s</font></html>',icon,color,text);
        str{end+1} = '<html><font color="gray">>> End of the messages</font></html>';
        set(hMessagebox,'string',str,'value',length(str));
        drawnow;
    end

    function op = fi(tf,op1,op2)
        if tf, op = op1; else op = op2; end
    end
    function set_button_color(h,color,varargin)
        set(h,'backgroundcolor',color,'foregroundcolor',fi(all(0.45<color&color<0.55),[1 1 1],1-color),varargin{:});
    end
    function str = set_listbox_value(h,item,varargin)
        items = get(h,'string');
        val = find(strcmpi(items,item),1);
        if isempty(val), val = 1; end
        set(h,'value',val,varargin{:});
        str = items{val};
    end
    function str = get_listbox_value(h)
        items = get(h,'string');
        val = get(h,'value');
        str = items{val};
    end
    function filename = strip_path(filepath,replacement)
        filename = '';
        if ~isempty(filepath)
            [~,filename,ext] = fileparts(filepath);
            filename = [filename ext];
        elseif exist('replacement','var')
            filename = replacement;
        end
    end
    function str = num2range(val)
        val = sort(val);
        c = 0; str = num2str(val(1));
        for m=2:length(val)
            if 1==val(m)-val(m-1)
                c = c + 1;
                continue;
            else
                switch c
                    case 0, str = [str ',' num2str(val(m))]; %#ok<*AGROW>
                    case 1, str = [str sprintf(',%d,%d',val(m-1:m))];
                    otherwise, str = [str sprintf(':%d,%d',val(m-1:m))];
                end
                c = 0;
            end
        end
        if 1==c, str = [str ',' num2str(val(end))]; elseif 1<c, str = [str ':' num2str(val(end))]; end
    end
end
