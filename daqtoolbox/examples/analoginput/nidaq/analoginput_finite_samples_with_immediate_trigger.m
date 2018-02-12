% This example demonstrates how to acquire a finite amount of data with
% immediate triggers.
%
% To continuously acquire infinite samples, set SamplesPerTrigger to Inf.
%
% When TriggerType is Immediate, acquisition begins immediately with START
% and the next trigger also starts automatically after the samples
% specified by SamplesPerTrigger are collected.

ai = analoginput('nidaq','Dev1');
addchannel(ai,0:1);

ai.TriggerType = 'Immediate';
ai.SampleRate = 1000;
ai.SamplesPerTrigger = 1000;
ai.TriggerRepeat = 0;

tic; start(ai);
fprintf('Start: %f s\n', toc);

tic; while isrunning(ai), end
fprintf('Running: %f s\n', toc);

[data,time,abstime,events] = getdata(ai);
plot(data);
showdaqevents(ai.EventLog)
