% This script is from Asaad & Eskandar (2008a) and measures how frequently
% new samples are updated during continuous acquisition. BufferingConfig is
% modified to get the fastest result from MATLAB daq, but NIMH daqtoolbox
% is not affected by this setting.
%
% MATLAB DAQ updates samples at ~15-ms intervals and therefore is not
% suitable for near-realtime data acquisition (<1 ms). NIMH DAQ fetches new
% samples whenever requested and as soon as they are registered by devices.
%
% Asaad WF, Eskandar EN. Achieving behavioral control with millisecond
% resolution in a high-level programming environment. J Neurosci Methods.
% 2008;173:235-240.

ai = analoginput('nidaq', 'dev1');
ai.SamplesPerTrigger = Inf;
ai.BufferingConfig = [1 2000]; % can try different values, like [1 2000]
ch = addchannel(ai, 0:1);

t = zeros(10000, 1);
n = t;
c = 0;

start(ai);
tic;
while ~isrunning(ai), end
toc
while ~ai.SamplesAvailable, end
toc
flushdata(ai);
tic;
while toc < 1
    c = c + 1;
    t(c) = toc;
    n(c) = ai.SamplesAvailable;
end
t = t(1:c);
n = n(1:c);
stop(ai);

plot(t, n)

xlabel('Time (sec)');
ylabel('Number of samples acquired');
title(sprintf('%d SamplesAvailable calls/s, %d transfers/s', c, sum(0<diff(n))));
