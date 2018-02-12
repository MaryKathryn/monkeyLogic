% The following code crashes down MATLAB 8.6 (R2015b, 32-bit) + Data
% Acquisition Toolbox (3.8). It is because the number of channels added is
% not the same between when samples are collected and when they are
% retrived. NIMH DAQ simply empties its storage when the number of channels
% changes, to keep the compatibility with MATLAB DAQ without crashing.

ai = analoginput('nidaq','Dev1');
addchannel(ai,0);
start(ai);
while isrunning(ai), end
addchannel(ai,1);
getdata(ai)
