% This example shows how to send out multiple waveforms through the same
% analog channel with manual triggers.
%
% This example does not work with MATLAB DAQ, since it uses NIMH
% daqtoolbox's extended functionality.
%
% To generate multiple waveforms, queue them by calling PUTDATA as many
% times as you need and set TriggerType and ManualTriggerWFOutput to Manual
% and One, respectively. Waveforms will be sent out one by one, each time
% than TRIGGER is called.
%
% RepeatOutput specifies how many time each waveform will be repeated.

hwInfo = daqhwinfo;
if strcmpi(hwInfo.ToolboxName,'Data Acquisition Toolbox')
    error('This example does not work with MATLAB DAQ. Try NIMH daqtoolbox.');
end

[y,fs] = audioread('C:\Windows\Media\notify.wav');
y2 = audioread('C:\Windows\Media\tada.wav');

ao = analogoutput('nidaq','Dev1');
addchannel(ao,0:1);

ao.TriggerType = 'Manual';
ao.SampleRate = fs;
ao.RepeatOutput = 0;
ao.ManualTriggerWFOutput = 'One';       % 'All' by default

putdata(ao,y);
putdata(ao,y2);

fprintf('Number of waveforms queued: %d\n',ao.WaveformsQueued);

tic; start(ao);
fprintf('Start: %f s\n', toc);

tic; trigger(ao);
fprintf('Trigger#1: %f s\n', toc);

tic; while issending(ao), end
fprintf('Waveform#1: %f s\n', toc);
tic; while toc < 1, end

tic; trigger(ao);
fprintf('Trigger#2: %f s\n', toc);

tic; while issending(ao), end
fprintf('Waveform#2: %f s\n', toc);

showdaqevents(ao.EventLog)
