% This script measures how many GETSAMPLE calls can be made for 1 s.

ai = analoginput('nidaq', 'dev1');
ch = addchannel(ai, 0:1);

s = zeros(40000, 2);
t = zeros(40000, 1);
c = 0;
tic;
while toc < 1
    c = c + 1;
    t(c) = toc;
    s(c,:) = getsample(ai);
end
stop(ai);

s = s(1:c,:);
t = t(1:c);

plot(t, s)

xlabel('Time (sec)');
ylabel('Sample value (volts)');
title(sprintf('%d GETSAMPLE calls/s', c));
