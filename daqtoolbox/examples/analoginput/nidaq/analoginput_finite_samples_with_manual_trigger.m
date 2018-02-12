% This example demonstrates how to acquire a finite amount of data with
% manual triggers.
%
% When TriggerType is Manual, acquisition begins when TRIGGER command is
% issued, not START. Since the task initialization is already finished by
% START, TRIGGER is executed in no time.
%
% ManualTriggerHwOn can take either 'Start' or 'Trigger'. When it is
% 'Start', the device begins sampling with START so you can check the
% values of samples with PEEKDATA before actually acquiring data.
%
% This example repeates acquisition once (TriggerRepeat is 1). When
% multiple triggers are included in a single getdata call, a NaN is
% included into the returned data and time arrays.

ai = analoginput('nidaq','Dev1');
addchannel(ai,0:1);

ai.TriggerType = 'Manual';
ai.SampleRate = 1000;
ai.SamplesPerTrigger = 1000;
ai.TriggerRepeat = 1;
ai.TriggerDelay = 0;
ai.ManualTriggerHwOn = 'Start';

tic; start(ai);
fprintf('Start: %f s\n', toc);
tic; while toc < 1, end

tic; trigger(ai);
fprintf('Trigger#1: %f s\n', toc);

tic; while islogging(ai), end
fprintf('Logging: %f s\n', toc);
tic; while toc < 1, end

tic; trigger(ai);
fprintf('Trigger#2: %f s\n', toc);

tic; while isrunning(ai), end
fprintf('Running: %f s\n', toc);

[data,time,abstime,events] = getdata(ai,ai.SamplesAvailable);
plot(data);
showdaqevents(ai.EventLog)
