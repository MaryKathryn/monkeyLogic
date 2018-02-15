if ~exist('eye_','var'), error('This task requires eye signal input. Please set it up or try the simulation mode.'); end
showcursor(false);  % remove the joystick cursor


%MAP CHANGE ===============================================================
% Before Pre-Start Trial we need to make sure we are running the correct
% MAP in UE. This could also be used to load a specific map according to
% the current condition defined in the UE_Test.txt file. 
Map = 'Hc_TrainingX_med_12';
if isempty(TrialRecord.LastTrialCodes.CodeNumbers) % first trial
    try
        if ~tcp_.MapChange(Map)
            error('Could not initialize TCP Connection');
        end
        
    catch err
        %catches error message and display it
        fprintf('<<< MonkeyLogic >>> %s\n',err.message);
        rethrow(err);
    end
end


%FIX POINT AND SPEED MULTIPLIER ===========================================
% can configure the use of a Fixation point and modify the travel speed
% inside the maze 
%Fix = Bool to display fix point, default to False
%SpeedModifier = float to modify speed, default to 1.00
Fix = false;
SpeedModifier = 1.00;
if Fix ~= false || SpeedModifier ~= 1.00
    tcp_.SetFixAndSpeed(Fix, SpeedModifier); 
end


%TRIAL VARIABLES ==========================================================
%Set behavioral codes
%For PreStart Scene will send North/South Direction and Context
% North: 57;
% South: 58;
%Trial Start : 59;
%Goal Hit : 60;
bhv_code(57,'North',...
    58,'South',...
    59,'Trial Start',...
    60,'Goal Hit',...
    50,'Reward');  % behavioral codes

%To control the amount of reward for the hierarchy
ErrorITI = 2000; %time in ms for ITI after error trial
TrialTime = 20000; % 20 Seconds Max duration
RewardMultiplier = [1 0.5 0]; %for High-Mid-Low 
ContextTextures = {'ML_Wood', 'ML_Steel'};
GoalsColors = {'Red', 'Green', 'Blue', 'Cyan', 'Purple', 'Yellow', 'Orange', 'Black', 'White', 'Gray', 'Invisible'};
ColorsLetters = {'R','G','B','C','P','Y','O','K','W','A','I'};

%PRE_START_TRIAL ==========================================================
fBob = 0; %bobbing motion
bContTrials = 1; %continuous trials (no-ITI)
bUseLocAsStart = 1; %Use current location as start
bSerialGoals = 0; %multiple goals to be hit serially to get reward
bUseFog = 0; %Mark the target with a fog
bUseCues = 0; %outdated leave at 0
strGoalID = ''; %For FreeRoam

if isempty(TrialRecord.LastTrialCodes.CodeNumbers) || ... if empty means it's the first trial
        (TrialRecord.TrialErrors(end) ~= 0) || ... %the subject was on black or the last trial was an error (sent to black)
        (TrialRecord.TrialErrors(end) == 0 && any(ismember(TrialRecord.LastTrialCodes.CodeNumbers, 58))) % Was the last trial South
    
    bIsNorth = 1;%trial direction 
    PreStartBehavCode = 57;
    CurrentGoals = {'Goal_NW', 'Goal_NE'};
else
    bIsNorth = 0;%trial direction 
    PreStartBehavCode = 58;
    CurrentGoals = {'Goal_SW', 'Goal_SE'};
end

%Get Current Condition
strContext = ContextTextures{TaskObject(1).ID}; %Context
WestGoalColor = TaskObject(2).MoreInfo.Color; %Color Letter
WestGoalValue = TaskObject(2).MoreInfo.Value; % Value: 1=High; 2=Mid; 3=Low; 
EastGoalColor = TaskObject(3).MoreInfo.Color;
EastGoalValue = TaskObject(3).MoreInfo.Value;

%Concatenate color names
strGoalsColor = [GoalsColors{ismember(ColorsLetters,WestGoalColor)} '/' GoalsColors{ismember(ColorsLetters,EastGoalColor)}];

%Pre_Start_Trial string being send to the Unreal Engine
strToSend = ['HCTASKPRESTARTTRIAL {fBob ' num2str(fBob) '} ' ...
                '{bIsNorth ' num2str(bIsNorth) '} ' ...
                '{bContTrials ' num2str(bContTrials) '} ' ...
                '{bUseLocAsStart ' num2str(bUseLocAsStart) '} ' ...
                '{bSerialGoals ' num2str(bSerialGoals) '} ' ...
                '{bUseFog ' num2str(bUseFog) '} ' ...
                '{bUseCues ' num2str(bUseCues) '} ' ...
                '{Textures ' strContext '} '...
                '{GoalsColor ' strGoalsColor '} '...
                '{strGoalID ' strGoalID '}'];


%SCENE 1: SendPreStartTrial ===============================================
preStart = UE_SendMessage(tcp_);
preStart.PendingMessage = strToSend;
scene1 = create_scene(preStart,[]);

%SCENE 2: Wait for goal touch or time run out =============================
goalTouch = UE_GoalTouch(tcp_);
goalTouch.Goals = CurrentGoals;
wth1 = WaitThenHold(goalTouch);
wth1.WaitTime = TrialTime;
wth1.HoldTime = 0;
scene2 = create_scene(wth1,[]);

%END SCENE ================================================================
endTrial = UE_SendMessage(tcp_);
endTrial.PendingMessage = 'ENDTRIAL';
endscene = create_scene(endTrial,[]);

%RUN TASK =================================================================
%Pre-Start trial sending
run_scene(scene1,PreStartBehavCode);
if ~preStart.Success
    run_scene(endscene);
    %These are the possible trial errors, NUMBERING STARTS AT 0!!!!!!!!!!!!
%   {'correct','no response','late response','break fixation','no fixation','early response','incorrect','lever break','ignored','aborted'};
    trialerror(9); % aborted; pre start trial did not send
    return
end

%Actual Trial
run_scene(scene2,59);
if ~wth1.Success
    run_scene(endscene);
    trialerror(8); % ignored
    return
end

%End Scene
run_scene(endscene);

% reward
%the subject touched a goal; test to see if was highest reward
if goalTouch.TouchedGoal{1}(end) == 'W'
    TouchedValue = WestGoalValue;
    IgnoredValue = EastGoalValue;
elseif goalTouch.TouchedGoal{1}(end) == 'E'
    TouchedValue = EastGoalValue;
    IgnoredValue = WestGoalValue;
else
    TouchedValue = [];
    IgnoredValue = [];
end

if isempty(TouchedValue) || isempty(IgnoredValue)
    %Ignored Trial, send to black 
    tcp_.OnBlack();
    idle(ErrorITI);
elseif TouchedValue < IgnoredValue 
    trialerror(0); % correct
    goodmonkey(100 * RewardMultiplier(TouchedValue), 'juiceline',1, 'numreward',1, 'eventmarker',50, 'nonblocking', 1); % 100 ms of juice x 2
elseif IgnoredValue < TouchedValue
    trialerror(6); % chose the wrong (second) object among the options [target distractor]
    goodmonkey(100 * RewardMultiplier(TouchedValue), 'juiceline',1, 'numreward',1, 'eventmarker',50, 'nonblocking', 1); % 100 ms of juice x 2
    tcp_.OnBlack();
    idle(ErrorITI);
end
