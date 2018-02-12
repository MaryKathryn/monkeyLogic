function alert_function(hook,MLConfig,TrialRecord)
% This file is an example of how to send notifications to Slack apps.
% 1. Copy this file to your task directory and rename it alert_function.m
%   (or overwrite alert_function.m in your ML directory with this file, if
%   you want the same alert messages for all your tasks).
% 2. Follow the instructions below and get the Webhook URL.
% 3. Put the URL in the strHookURL variable below.
% 4. Modify the notification texts in the switch statement as you want. Or
%   add more notifications for other events.
% 5. Turn on the 'Alert' button on the ML main menu.

% Slack
% 1. Configure an Incoming Webhooks at https://slack.com/services/new/incoming-webhook
% 2. Copy the Webhook URL once the service is configured, and store it as a
%   MATLAB string here.
%
%   strHookURL = 'https://hooks.slack.com/services/T83J0FY9Y/B83NX6F....';
% 
% 3. Call SendSlackNotification() in the switch statement below. For the
%    syntax details, type 'help SendSlackNotification' on the MATLAB
%    command window.
%
%   SendSlackNotification(strHookURL,'Task done. This message is sent from ML2');
%
% 4. You can use Slack attachments to display rich content. See the
%   comments in MakeSlackAttachment() or type 'help MakeSlackAttachment'.
%
% 5. This Slack integration depends on Dylan Muir's SlackMatlab code. For
%   more information, visit https://github.com/DylanMuir/SlackMatlab

strHookURL = 'https://hooks.slack.com/services/T83J0FY9Y/B83NX6F....';  % This URL is an example.
strTarget = '#monkeylogic';     % a channel name ('#channel') or a user name ('@username')
strUsername = 'MonkeyLogic';    % the name that will be displayed under the notification
strIconURL = '';                % a URL referencing an icon image file
strIconEmoji = ':monkey_face:'; % Emoji string. strIconURL and strIconEmoji should not both be provided.
csAttachments = '';             % a Slack attachment structure created by MakeSlackAttachment()

strTime = datestr(now,'mm/dd HH:MM PM, ');
[~,CondFile] = fileparts(MLConfig.MLPath.ConditionsFile);
SubjectName = MLConfig.SubjectName; if isempty(SubjectName), SubjectName = 'Someone'; end

strText = '';
switch hook
    case 'task_start'
        strText = [strTime SubjectName ' just started Task ''' CondFile '''.'];
    case 'block_start'
        
    case 'trial_start'
        
    case 'trial_end'
        
    case 'block_end'
        
    case 'task_end'
        strText = [strTime SubjectName ' finished Task ''' CondFile '''.'];
    case 'task_paused'

    case 'task_resumed'
        
    case 'task_aborted'  % in case that the task stopped with an error
        strText = [strTime 'An error occurred while ' SubjectName ' was doing Task ''' CondFile '''.'];
end

if ~isempty(strText)
    result = SendSlackNotification(strHookURL,strText,strTarget,strUsername,strIconURL,strIconEmoji,csAttachments);
    if ~strcmp(result,'ok'), error('There was an error while sending out a Slack notification.'); end
end

end
