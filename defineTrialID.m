%Define trial ID words
%Words : ddd dss sss SSt ttt
%   d : days since Jan 1st 2012
%   s : seconds of the day (86400/day)
%   S : setup (01: Cerebus; 02: Plexon)
%   t : trial number

%   KM edit - append ID_ onto the generated number
function TrialID = defineTrialID(trialNumber,setup)
    %computes the elapsed number of seconds between the actual date and Jan 1st
    %2012
    presentTime = clock;
    %since we are only keeping the number of days, we are dropping
    %hours/mins/secs
    today = [presentTime(1:3) 0,0,0];
    reference = [2012,1,1,0,0,0];
    elapsedSeconds = etime(today, reference);
    %Converts the number of seconds in the number of days
    %   (1 day = 60sec/min*60min/hr*24hr/day = 86400 sec/day)
    elapsedDays = elapsedSeconds / 86400;
    %gets the current time to compute the day's seconds:
    currentSeconds = (presentTime(4)*3600) + (presentTime(5)*60) + round(presentTime(6));
    %Setup
    % 01 : Cerebus
    % 02 : Plexon
%     setup = e.setupID;
    %Trial number:
%     trialNumber = e.trialCounter;
    TrialID = '000000000000000';
    strelapsedDays = int2str(elapsedDays);
    strcurrentSeconds = int2str(currentSeconds);
    strsetup = int2str(setup);
    strtrialNumber = int2str(trialNumber);
    sizeelapsedDays = length(strelapsedDays);
    sizecurrentSeconds = length(strcurrentSeconds);
    sizesetup = length(strsetup);
    sizetrialNumber = length(strtrialNumber);
    TrialID(5-sizeelapsedDays:4) = strelapsedDays;
    TrialID(10-sizecurrentSeconds:9) = strcurrentSeconds;
    TrialID(12-sizesetup:11) = strsetup;
    TrialID(16-sizetrialNumber:15) = strtrialNumber;
    
% append the ID_ part of the name field 
    TrialID = strcat('ID_',TrialID);
end