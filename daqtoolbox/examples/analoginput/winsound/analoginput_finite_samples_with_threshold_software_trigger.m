% This example demonstrates how to acquire a finite amount of data with
% software triggers. Recording begins when any sound is made and lasts for
% 3 s.
%
% TriggerChannel must be specified when TriggerType is Software.
%
% Acquisition begins when input voltage meets a certain criterion
% specified by TriggerCondition and TriggerConditionValue.
%
% When TriggerCondition is Rising of Falling, TriggerConditionValue must
% be a scalar.
%
% When TriggerCondition is Entering or Leaving, TriggerConditionValue must
% be a 2-element vector that defines the lower and upper bounds. See the
% nidaq example for the usage of a range trigger.

ai = analoginput('winsound',0);
addchannel(ai,1:2); % The first ch in winsound devices is 1, not 0.

ai.TriggerType = 'Software';
ai.SampleRate = setverify(ai,'SampleRate',8000);
ai.SamplesPerTrigger = ai.SampleRate * 3;  % for 3 secs
ai.TriggerRepeat = 0;
ai.TriggerChannel = ai.Channel(1);
ai.TriggerCondition = 'Rising'; % or Falling
ai.TriggerConditionValue = 0.1;

tic; start(ai);
fprintf('Start: %f s\n', toc);

tic; while ~islogging(ai), end
fprintf('Trigger: %f s\n', toc);

tic; while isrunning(ai), end
fprintf('Running: %f s\n', toc);

[data,time,abstime,events] = getdata(ai);
sound(data,ai.SampleRate);
showdaqevents(ai.EventLog)
