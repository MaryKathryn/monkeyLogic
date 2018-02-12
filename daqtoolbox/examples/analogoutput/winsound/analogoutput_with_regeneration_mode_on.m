% This example demonstrates how to recycle queued samples without calling
% PUTDATA again.
%
% This example does not work with MATLAB DAQ, since it uses NIMH
% daqtoolbox's extended functionality.
%
% If RegenerationMode is 1, queued samples are not discarded when
% generation is over. To empty the queued samples, call STOP explicitly
% when Running is 0.

hwInfo = daqhwinfo;
if strcmpi(hwInfo.ToolboxName,'Data Acquisition Toolbox')
    error('This example does not work with MATLAB DAQ. Try NIMH daqtoolbox.');
end

[y,fs] = audioread('C:\Windows\Media\notify.wav');
y2 = audioread('C:\Windows\Media\tada.wav');

ao = analogoutput('winsound',0);
addchannel(ao,1:2);	% The first channel in winsound devices is 1, not 0.

ao.TriggerType = 'Immediate';
ao.SampleRate = fs;
ao.RepeatOutput = 0;
ao.RegenerationMode = 1;

putdata(ao,y);
putdata(ao,y2);

fprintf('SamplesAvailable: %d\n',ao.SamplesAvailable);

tic; start(ao);
fprintf('Start: %f s\n', toc);

tic; while isrunning(ao), end
fprintf('Running: %f s\n', toc);

fprintf('SamplesAvailable: %d\n',ao.SamplesAvailable);
tic; while toc<1; end

tic; start(ao);
fprintf('Restart: %f s\n', toc);

tic; while isrunning(ao), end
fprintf('Running: %f s\n', toc);

fprintf('SamplesAvailable: %d\n',ao.SamplesAvailable);
stop(ao);
fprintf('SamplesAvailable: %d\n',ao.SamplesAvailable);

showdaqevents(ao.EventLog)
