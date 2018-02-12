function runtime_script = embed_timingfile(MLConfig,timingfile,trialholder)
% SYNTAX
%         runtimescript = embed_timingfile(MLConfig,timingfile,trialholder)
%
% Created by WA, July, 2006
% Modified 7/25/08 -WA
% Modified 9/08/08 -SM (to handle block comments)
% Modified 2015-04-29 -SL (0.3.0 - minor)

% Dec 22, 2016      This file is completely re-written by Jaewon Hwang

% process the timing file
timing_code = fileread(timingfile);
userfunc = '';
if verLessThan('matlab','9.1')
    userfunc_startpoint = strfind(timing_code,[char(10) 'function ']);
    if ~isempty(userfunc_startpoint)
        userfunc = [timing_code(userfunc_startpoint:end) char(10)];
        timing_code = timing_code(1:userfunc_startpoint);
    end
end
timing_code = regexp(tree2str(mtree(timing_code)),'[^\n]+\n|[^\n]+$','match')';
timing_trimmed = strtrim(timing_code);

% abort_trial or return
timing_code(strncmp(timing_trimmed,'abort_trial',11)|strncmp(timing_trimmed,'return',6)) = {'end_trial; return'};

% editable
MLEditable = struct;
MLEditable.editable = struct;  % this is the field where the types of variables will be set.
MLEditable.reward_dur = MLConfig.RewardFuncArgs.Duration;
MLEditable.editable.reward_dur = '';
editable_definition = find(strncmp(timing_trimmed,'editable',8));
for m=editable_definition'
    [varname,types] = eval(timing_code{m});
    for n=1:length(varname)
        MLEditable.(varname{n}) = [];
        MLEditable.editable.(varname{n}) = types{n};
    end
end
if ~isempty(editable_definition), timing_code(editable_definition) = {''}; end

vars = setdiff(fieldnames(MLEditable),'editable');
for m=1:length(vars)
    tokens = regexp(timing_trimmed,['^' vars{m} '[\t ]*=(.+)$'],'tokens');
    n = find(~cellfun(@isempty,tokens),1);
    if isempty(n)
        if ~strcmp(vars{m},'reward_dur'), MLEditable = rmfield(MLEditable,vars{m}); end
    else
        MLEditable.(vars{m}) = eval(tokens{n}{1}{1});
        timing_code{n} = '';
        switch MLEditable.editable.(vars{m})
            case {'file','dir'}, sanity = isa(MLEditable.(vars{m}),'char'); str = 'The ''file'' or ''dir'' type must be char.';
            case 'color', sanity = isvector(MLEditable.(vars{m})) && 3==length(MLEditable.(vars{m})); str = 'The ''color'' type must be a 1-by-3 vector.';
            otherwise, sanity = isscalar(MLEditable.(vars{m})) || ischar(MLEditable.(vars{m}));
        end
        if ~sanity, error(['Incorrect value for the editable variable, %s.' char(10) '%s'],vars{m},str); end
    end
end

if isempty(MLConfig.SubjectName), editable_by_subject = 'MLEditable'; else, editable_by_subject = ['MLEditable_' lower(MLConfig.SubjectName)]; end
if 2==exist(MLConfig.MLPath.ConfigurationFile,'file')
    saved_vars = whos('-file',MLConfig.MLPath.ConfigurationFile,editable_by_subject);
    if ~isempty(saved_vars) && 0<saved_vars.bytes
        saved_vars = load(MLConfig.MLPath.ConfigurationFile,editable_by_subject);
        field = intersect(setdiff(fieldnames(MLEditable),'editable'),fieldnames(saved_vars.(editable_by_subject)));
        MLEditable = copyfield(MLEditable,saved_vars.(editable_by_subject),field);
    else 
        saved_vars = whos('-file',MLConfig.MLPath.ConfigurationFile,'MLEditable');
        if ~isempty(saved_vars) && 0<saved_vars.bytes
            saved_vars = load(MLConfig.MLPath.ConfigurationFile,'MLEditable');
            field = intersect(setdiff(fieldnames(MLEditable),'editable'),fieldnames(saved_vars.MLEditable));
            MLEditable = copyfield(MLEditable,saved_vars.MLEditable,field);
        end
    end
end
if ~isempty(vars)
    MLEditable2.MLEditable = MLEditable;
    MLEditable2.(editable_by_subject) = MLEditable; %#ok<STRNU>
    if 2==exist(MLConfig.MLPath.ConfigurationFile,'file'), save(MLConfig.MLPath.ConfigurationFile,'-struct','MLEditable2','-append'); else, save(MLConfig.MLPath.ConfigurationFile,'-struct','MLEditable2'); end
    editable_vars = cell(length(vars),1);
    for m = 1:length(vars), editable_vars{m} = sprintf('%s = TrialData.VariableChanges.%s;', vars{m}, vars{m}); end
    timing_code = [editable_vars; timing_code];
end
timing_code = regexprep(timing_code,'(.*)',['$1' char(10)]);

% read trialholder
if ~exist('trialholder','var') || 2~=exist(trialholder,'file')
    if any(~cellfun(@isempty,regexp(timing_trimmed,'toggleobject'))) || any(~cellfun(@isempty,regexp(timing_trimmed,'eyejoytrack')))
        trialholder = [MLConfig.MLPath.BaseDirectory 'trialholder_v1.m'];
        
        % Note that this part can be called every trial, if the userloop returns the trialholder filename.
        MLConfig.DAQ.unregister_digitalinput();  % we don't need to continuously sample digital input in this trialholder
    else
        trialholder = [MLConfig.MLPath.BaseDirectory 'trialholder_v2.m'];
        
        % Note that this part can be called every trial, if the userloop returns the trialholder filename.
        hFig = findobj('tag','mlmonitor');
        if ~isempty(hFig)
            set(findobj(hFig,'tag','MaxLatencyLabel'),'string','Frame Interval');
            set(findobj(hFig,'tag','CycleRateLabel'),'string','Drawing Time');
        end
    end
end
trialholder_code = fileread(trialholder);
insertion_point = strfind(trialholder_code,'%END OF TIMING CODE********************************************************');
if isempty(insertion_point), error('There is no timing script insertion point in ''%s''',trialholder); end

% minify runtime
if MLConfig.MinifyRuntime
    runtime_code = strtrim(regexp(tree2str(mtree([trialholder_code(1:insertion_point-1) userfunc ...
        [timing_code{:}] trialholder_code(insertion_point:end)])),'[^\n]+\n|[^\n]+$','match'))';
    tokens = regexp(runtime_code,'^([^'']*)(''.*'')([^'']*)$','tokens');
    row = cellfun(@isempty,tokens);
    tokens(row) = runtime_code(row);
    for m=1:length(tokens)
        if iscell(tokens{m})
            runtime_code{m} = [remove_blank(tokens{m}{1}{1}) tokens{m}{1}{2} remove_blank(tokens{m}{1}{3})];
        else
            runtime_code{m} = remove_blank(tokens{m});
        end
    end
else
    runtime_code = regexprep(regexp([trialholder_code(1:insertion_point-1) userfunc [timing_code{:}] ...
        trialholder_code(insertion_point:end)],'[^\n]+\n|[^\n]+$','match')','\n$','');
end

% write runtime
[~,funcname] = fileparts(timingfile);
funcname = [funcname '_runtime'];
runtime_code{1} = strrep(runtime_code{1},'trialholder',funcname);
runtime_script = [MLConfig.MLPath.RunTimeDirectory funcname '.m'];
if 2==exist(runtime_script,'file'), delete(runtime_script); end  % This is to show an error message where deletion is impossible. fopen doesn't make one.
fid = fopen(runtime_script,'w');
try
    for m=1:length(runtime_code)
        fprintf(fid,'%s\n',runtime_code{m});
    end
    fclose(fid);
%     pcode(funcname,'-inplace');
catch err
    fclose(fid);
    rethrow(err);
end

end  % end of embedtimingfile


function str = remove_blank(str)
    symbols = {' = ','='; ' \+ ','\+'; ' - ','-'; ' \.\* ','\.\*'; ' \./ ','\./'; ' \.\^ ','\.\^'; ' & ','&'; ' && ','&&'; ' \| ','\|'; ' \|\| ','\|\|'; ...
        '\) \(','\)\('; '\[ ','\['; ' \]','\]'; '\( ','\('; ' \)','\)'; '{ ','{'; ' }','}'; ', ',','; '; ',';'};
    str = regexprep(str,symbols(:,1),symbols(:,2));
end

function dest = copyfield(dest,src,field)
    if isempty(src), src = struct; end
    if isempty(dest), dest = struct; end
    if ~exist('field','var'), field = intersect(fieldnames(dest),fieldnames(src)); end
    for m=1:length(field)
        if isa(dest.(field{m}),class(src.(field{m}))), dest.(field{m}) = src.(field{m}); end
    end
end

function [varnames,types] = editable(varargin) %#ok<DEFNU>
    global_type = '';
    type = '';
    count = 1;
    for m = 1:length(varargin)
        var = varargin{m}; if ~iscell(var), var = {var}; end
        nvar = length(var);
        for n=1:nvar
            switch lower(var{n})
                case '-file', type = 'file';
                case '-dir', type = 'dir';
                case '-color', type = 'color';
                otherwise
                    varnames{count} = var{n}; %#ok<*AGROW>
                    types{count} = global_type;
                    if ~isempty(type), types{count} = type; end
                    type = '';
                    count = count + 1;
            end
            if n==nvar, global_type = type; end
        end
    end
end
