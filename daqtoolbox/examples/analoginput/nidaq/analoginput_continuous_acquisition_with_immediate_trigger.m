% This example demonstrates how to acquire a continuous amount of data
% with immediate triggers.
%
% In MATLAB DAQ, the number of samples to retrieve must be specified in
% GETDATA as shown below, when SamplesPerTrigger is Inf. However, in NIMH
% DAQ, simply GETDATA(ai) does the work.

ai = analoginput('nidaq','Dev1');
addchannel(ai,0:1);

ai.TriggerType = 'Immediate';
ai.SampleRate = 1000;
ai.SamplesPerTrigger = Inf;

tic; start(ai);
fprintf('Start: %f s\n', toc);

tic; while ai.SamplesAvailable < 1000, end
fprintf('Acquire 1000 samples: %f s\n',toc);

tic; stop(ai);
fprintf('Stop: %f s\n', toc);

[data,time,abstime,events] = getdata(ai,ai.SamplesAvailable);
plot(data);
showdaqevents(ai.EventLog)
