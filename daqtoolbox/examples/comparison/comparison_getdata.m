ai = analoginput('nidaq','Dev1');
addchannel(ai,0:1);

ai.TriggerType = 'Immediate';
ai.SampleRate = 1000;
ai.SamplesPerTrigger = Inf;
ai.TriggerRepeat = 0;

start(ai);
tic; while toc<1; end
stop(ai);

% This GETDATA call does not work with MATLAB DAQ. When SamplesPerTrigger
% is Inf, you need to specifiy the number of samples to retrive. However,
% the same command works fine in NIMH daqtoolbox and it grabs all samples
% collected.
data = getdata(ai);
plot(data);