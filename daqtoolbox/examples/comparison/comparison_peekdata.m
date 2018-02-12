ai = analoginput('nidaq','Dev1');
addchannel(ai,0:1);

ai.TriggerType = 'Manual';
ai.ManualTriggerHwOn = 'Start';
ai.SampleRate = 1000;
ai.SamplesPerTrigger = 1000;
ai.TriggerRepeat = 2;

start(ai);
trigger(ai);
while islogging(ai); end
tic; while toc<1; end
trigger(ai);
while islogging(ai); end
tic; while toc<1; end
trigger(ai);
while islogging(ai); end

% PEEKDATA of MATLAB DAQ requires the second argument for the number of
% samples to retrieve, but NIMH DAQ accepts it without the argument and
% returns all the samples monitoring. In addition, MATLAB DAQ can "peek"
% logged samples only, whereas NIMH DAQ can look back on every sample since
% START.

hwInfo = daqhwinfo;
switch hwInfo.ToolboxName
    case 'Data Acquisition Toolbox' % MATLAB DAQ
        data = peekdata(ai,3000);
    case 'NIMH daqtoolbox'          % NIMH DAQ
        data = peekdata(ai);
end

plot(data);
