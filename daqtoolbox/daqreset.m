function daqreset()

extension_dir = {'','viewpoint','eyelink'};

toolbox_dir = mfilename('fullpath');
toolbox_dir = toolbox_dir(1:find(toolbox_dir==filesep,1,'last'));
system_path = getenv('PATH');
for m=1:length(extension_dir)
    target_dir = [toolbox_dir extension_dir{m}];
    if 7==exist(target_dir,'dir') && isempty(strfind(system_path,target_dir)) %#ok<STREMP>
        system_path = [target_dir ';' system_path]; %#ok<AGROW>
    end
end
setenv('PATH',system_path);

s = evalin('caller','whos');
for m=1:length(s)
    switch s(m).class
        case {'analoginput','aichannel','analogoutput','aochannel','digitalio','dioline','pointingdevice','eyetracker'}
            evalin('caller',['delete(' s(m).name ')']);
            evalin('caller',['clear(''' s(m).name ''')']);
    end
end
s = evalin('base','whos');
for m=1:length(s)
    switch s(m).class
        case {'analoginput','aichannel','analogoutput','aochannel','digitalio','dioline','pointingdevice','eyetracker'}
            evalin('base',['delete(' s(m).name ')']);
            evalin('base',['clear(''' s(m).name ''')']);
    end
end

mdqmex(81);

end