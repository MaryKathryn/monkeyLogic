% This example demonstrates how to acquire a finite amount of data with
% software triggers.
%
% TriggerChannel must be specified when TriggerType is Software.
%
% Acquisition begins when input voltage meets a certain criterion
% specified by TriggerCondition and TriggerConditionValue.
%
% When TriggerCondition is Entering or Leaving, TriggerConditionValue must
% be a 2-element vector that defines the lower and upper bounds.

ai = analoginput('nidaq','Dev1');
addchannel(ai,0:1);

ai.TriggerType = 'Software';
ai.SampleRate = 1000;
ai.SamplesPerTrigger = 1000;
ai.TriggerRepeat = 0;
ai.TriggerChannel = ai.Channel(1);
ai.TriggerCondition = 'Entering';    % or Leaving
ai.TriggerConditionValue = [-0.1 0.1];

tic; start(ai);
fprintf('Start: %f s\n', toc);

tic; while ~islogging(ai), end
fprintf('Trigger: %f s\n', toc);

tic; while isrunning(ai), end
fprintf('Running: %f s\n', toc);

[data,time,abstime,events] = getdata(ai);
showdaqevents(ai.EventLog)

warning('off','all');
y = peekdata(ai,1100);
plot(y); hold on;
idx = find(y(:,1)==data(1,1) & y(:,2)==data(1,2),1,'last');
plot(idx:idx+length(data)-1,data); hold off;
warning('on','all');
