% This example demonstrates how to acquire a finite amount of data with
% immediate triggers.
%
% To continuously acquire infinite samples, set SamplesPerTrigger to Inf.
%
% When TriggerType is Immediate, acquisition begins immediately with START
% and the next trigger also starts automatically after the samples
% specified by SamplesPerTrigger are collected.

ai = analoginput('winsound',0);
addchannel(ai,1:2);	% The first channel in winsound devices is 1, not 0.

ai.TriggerType = 'Immediate';
ai.SampleRate = setverify(ai,'SampleRate',8000);
ai.SamplesPerTrigger = ai.SampleRate * 3;  % for 3 secs
ai.TriggerRepeat = 0;

tic; start(ai);
fprintf('Start: %f s\n', toc);

tic; while islogging(ai), end
fprintf('Logging: %f s\n', toc);

[data,time,abstime,events] = getdata(ai);
sound(data,ai.SampleRate);
showdaqevents(ai.EventLog)
