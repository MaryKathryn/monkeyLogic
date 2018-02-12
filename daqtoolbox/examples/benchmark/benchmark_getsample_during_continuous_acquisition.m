% This script tests how frequently GETSAMPLE updates during continuous
% acquisition. BufferingConfig is modified to get the fastest result from
% MATLAB daq, but NIMH daqtoolbox is not affected by this setting.
%
% While devices are running, GETSAMPLE reads the lastest sample that is
% available from continuous acquisition (i.e., equivalent to PEEKDATA(ai,1))
% and therefore you can get the benifit of NIMH daqtoolbox's fast sample
% update here as well (see benchmark_continuous_sampling.m).

ai = analoginput('nidaq', 'dev1');
ai.SamplesPerTrigger = Inf;
ai.BufferingConfig = [1 2000]; % can try different values, like [1 2000]
ch = addchannel(ai, 0:1);

t = zeros(10000, 1);
n = zeros(10000, 2);
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
    n(c,:) = getsample(ai);
end
t = t(1:c);
n = n(1:c,:);
stop(ai);

plot(t, n)

xlabel('Time (sec)');
ylabel('Sample value (volts)');
title(sprintf('%d GETSAMPLE call(s) performed',c));
