ai = analoginput('nidaq','Dev1');
addchannel(ai,0:1);

ai.TriggerType = 'Immediate';
ai.SampleRate = 1000;
ai.SamplesPerTrigger = 1000;
ai.TriggerRepeat = 0;

start(ai);
tic;

% This GETDATA call performs a blocking I/O in MATLAB DAQ, so it waits
% until all the samples are collected and returns the control. However, in
% NIMH daqtoolbox, it runs as a non-blocking I/O and therfore return
% immediately with an empty result.
data = getdata(ai);
fprintf('Number of samples from 1st GETDATA: %d\n',size(data,1));
fprintf('Elapsed time: %f s\n',toc);

while isrunning(ai); end
% GETDATA below causes an error in MATLAB DAQ, because all samples are already
% retrived in the previous call.
data2 = getdata(ai);
fprintf('Number of samples from 2nd GETDATA: %d\n',size(data2,1));
