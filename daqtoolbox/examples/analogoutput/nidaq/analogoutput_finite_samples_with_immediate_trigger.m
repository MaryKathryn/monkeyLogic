% This example shows how to send out waveforms through analog channels.
%
% If TriggerType is Immediate, the task starts when START command is
% issued.
%
% To generate the same waveform multiple times, set RepeatOutput to a
% number bigger than 0.

[y,fs] = audioread('C:\Windows\Media\notify.wav');
y2 = audioread('C:\Windows\Media\tada.wav');

ao = analogoutput('nidaq','Dev1');
addchannel(ao,0:1);

ao.TriggerType = 'Immediate';
ao.SampleRate = fs;
ao.RepeatOutput = 0;

putdata(ao,y);
putdata(ao,y2);

tic; start(ao);
fprintf('Start: %f s\n', toc);

tic; while isrunning(ao), end
fprintf('Running: %f s\n', toc);

showdaqevents(ao.EventLog)
