% This example demonstrates how to send out chosen waveforms through the
% same analog channel with manual triggers.
%
% This example does not work with MATLAB DAQ, since it uses NIMH
% daqtoolbox's extended functionality.
%
% Multiple waveforms can be queued by calling PUTDATA as many times as you
% need. TriggerType must be Manual. To determine the next waveform, set
% ManualTriggerWFOutput to Chosen and put the waveform number in
% ManualTriggerNextWF. The chosen waveform can be sent out by calling
% TRIGGER afterwards.
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
ao.ManualTriggerWFOutput = 'Chosen';	% 'All' by default

putdata(ao,y);
putdata(ao,y2);

fprintf('Number of waveforms queued: %d\n',ao.WaveformsQueued);

ao.ManualTriggerNextWF = 2; % The first waveform must be given before START

tic; start(ao);
fprintf('Start: %f s\n', toc);

tic; trigger(ao);   % send out the first waveform
fprintf('Trigger#1: %f s\n', toc);

tic; while issending(ao), end
fprintf('Waveform#1: %f s\n', toc);
tic; while toc < 1, end

ao.ManualTriggerNextWF = 1; % If a new waveform is given before TRIGGER, the previous one will be repeated.
tic; trigger(ao);
fprintf('Trigger#2: %f s\n', toc);

tic; while issending(ao), end
fprintf('Waveform#2: %f s\n', toc);

showdaqevents(ao.EventLog)
