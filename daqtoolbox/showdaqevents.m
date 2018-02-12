function varargout = showdaqevents(s,idx)

if ~exist('idx','var'), idx = 1:length(s); end
if any(idx < 1), error('Invalid INDEX specified.  INDEX contains zero or negative values'); end
if any(length(s) < idx), error('INDEX exceeds event dimensions.  8 events occurred.'); end

nrow = length(idx);
out = cell(nrow,1);
for m=1:nrow
    n = idx(m);
    switch s(n).Type
        case {'Start','Stop'}
            type = s(n).Type;
            channel = '';
        case 'Trigger'
            type = sprintf('%s#%d', s(n).Type, s(n).Data.Trigger);
            if isempty(s(n).Data.Channel), channel = 'N/A'; else channel = sprintf('%d', s(n).Data.Channel); end
    end
    str = sprintf('%4d %-19s ( %02d:%02d:%02d, %d )', m, type, round(s(n).Data.AbsTime(4:6)), s(n).Data.RelSample);
    if ~isempty(channel), str = sprintf('%-48s Channel: %s', str, channel); end
    out{m} = str;
end

if 0 < nargout
    varargout{1} = out;
else
    fprintf('\n');
    for m=1:length(out), fprintf('%s\n',out{m}); end
    fprintf('\n');
end
