function [y,fs] = load_waveform(stim)

y = []; fs = [];

if ischar(stim), stim = {stim}; end
try
    switch length(stim)
        case 1
            [~,n,e] = fileparts(stim{1});
            w = load(stim{1});
            f = fieldnames(w);
            v = find(strcmpi(f,'y')|strcmpi(f,'waveform'),1);
            if ~isempty(v), y = w.(f{v}); end
            v = find(strcmpi(f,'fs')|strcmpi(f,'freq')|strcmpi(f,'frequency'),1);
            if ~isempty(v), fs = w.(f{v}); end
            if isempty(y) || isempty(fs), error('''%s'' does not contain y and/or fs',[n e]); end
        case 2
            [~,~,e] = fileparts(stim{2});
            switch lower(e)
                case '.wav'
                    if verLessThan('matlab','8.0')
                        [y,fs] = wavread(stim{2}); %#ok<DWVRD>
                    else
                        [y,fs] = audioread(stim{2});
                    end
                case '.mat'
                    [y,fs] = load_waveform(stim{2});
            end
        case 3
            fs = 44100;
            t = 0:1/fs:stim{2};
            y = sin(2*pi*stim{3}*t);
    end
catch err
    error('load_waveform: %s',err.message);
end
