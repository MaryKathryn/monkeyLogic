classdef mlconditions < handle
    properties (SetAccess = protected)
        Conditions
        UIVars
    end
    properties (SetAccess = protected, Hidden = true)
        MLPath
    end
    
    methods
        function obj = mlconditions(ConditionsFile)
            obj.MLPath = mlpath;
            init(obj);
            if exist('ConditionsFile','var')
                if isa(ConditionsFile,'mlpath'), obj.MLPath = copy(ConditionsFile); else load_file(obj,ConditionsFile); end
            end
        end
        
        function init(obj)
            obj.Conditions = [];
            obj.UIVars.TotalNumberOfConditions = [];
            obj.UIVars.StimulusList = '';
            obj.UIVars.BlockList = [];
            obj.UIVars.TotalNumberOfConditionsInThisBlock = [];
            obj.UIVars.TimingFiles = '';
        end
        
        function val = isloaded(obj), val = ~isempty(obj.Conditions); end
        function val = isconditionsfile(obj), val = isstruct(obj.Conditions); end
        function val = isuserloopfile(obj), val = ischar(obj.Conditions); end
        
        function load_file(obj,ConditionsFile,wb)
            if ~exist('ConditionsFile','var') || 2~=exist(ConditionsFile,'file')
                [n,p] = uigetfile({'*.txt', 'Conditions files (*.txt)'; '*.m', 'User-loop files (*.m)'},'Select a Conditions File');
                if 0==n, error('Can''t find the conditions file.'); end
                ConditionsFile = [p n];
            end
            if isempty(fileparts(ConditionsFile)), ConditionsFile = which(ConditionsFile); end
            obj.MLPath.ConditionsFile = ConditionsFile;
            init(obj);
            
            cond = cellfun(@obj.unquote,strtrim(regexp(strtrim(regexp(fileread(ConditionsFile),'[^\n]+\n|[^\n]+$','match')),'\t+','split')'),'UniformOutput',false);
            % in case that the selected file is a userloop file
            if strncmp(cond{1}{1},'function ',9), obj.Conditions = ConditionsFile; end
            if 2==exist(cond{1}{1},'file'), obj.Conditions = which(cond{1}{1}); end
            if ~isempty(obj.Conditions)
                obj.UIVars.StimulusList = {'user-defined'};
                obj.UIVars.TimingFiles = {'user-defined'};
                return
            end
            
            % normal conditions file
            header = {'Condition','Timing File','Frequency','Block','Info'};
            taskobj_no = cellfun(@obj.token2num,regexp(cond{1},'TaskObject#(\d+)','tokens'));
            non_taskobj = cond{1}(isnan(taskobj_no));
            known_header = ismember(lower(non_taskobj),lower(header));
            
            if all(isnan(taskobj_no)), error('No TaskObject header found'); end
            if any(~known_header), error('Invalid header column, ''%s''',non_taskobj{find(~known_header,1)}); end
            
            nheader = length(header);
            col = zeros(1,nheader);
            for m=1:nheader
                idx = find(strcmp(header{m},cond{1}),1);
                if ~isempty(idx), col(m) = idx; end
            end
            
            if any(0==col(1:4)), error('Missging header column, ''%s''',header{find(0==col(1:4),1)}); end
            
            ncond = size(cond,1)-1;
            taskobj = cell(ncond,7);
            for m=1:ncond
                if exist('wb','var'), set(wb,'string',sprintf('Loading... %.0f%%',m/ncond*100)); drawnow; end
                taskobj(m,0~=col) = cond{m+1}(col(0~=col));
                taskobj{m,6} = eval(['struct(' taskobj{m,5} ');']);
                
                idx = taskobj_no(1:length(cond{m+1}));
                obj_no = idx(~isnan(idx));
                taskobj{m,7} = struct('Label',[],'Attribute',[]);
                taskobj{m,7}(max(obj_no)).Label = '';
                a = parse_object(obj,cond{m+1}(~isnan(idx)));
                if isempty(a), error('error(s) in parsing %s',ConditionsFile); end
                taskobj{m,7}(obj_no) = a;
                
                taskobj{m,1} = str2double(taskobj{m,1});
                if m~=taskobj{m,1}, error('Condition numbers are not in order from 1 to %d',ncond); end
                [~,taskobj{m,2}] = find_ext(obj,taskobj{m,2},{'.m'});
                taskobj{m,3} = str2double(taskobj{m,3});
                taskobj{m,4} = eval(regexprep(regexprep(taskobj{m,4},' ',','),'^\[?([\d,]+)]?','[$1]'));
                
                if isempty(taskobj{m,2}), error('Can''t find the timing file, ''%s''',taskobj{m,2}); end
                if isnan(taskobj{m,3}) || taskobj{m,3}<1, error('''Frequency'' must be a natural number (0 or larger)'); end
                if any(isnan(taskobj{m,4})) || any(taskobj{m,4}<1), error('''Block'' must be natural numbers (0 or larger)'); end
            end
            if 0==ncond, error('No condition defined in the file'); end
            
            val = cell2struct(taskobj,{'Condition','TimingFile','Frequency','Block','RawInfo','Info','TaskObject'},2);
            
            all_stim = [val.TaskObject];
            [~,ia] = unique({all_stim.Label});
            obj.UIVars.TotalNumberOfConditions = length(val);
            obj.UIVars.StimulusList = all_stim(ia);
            obj.UIVars.BlockList = unique([val.Block]);
            obj.UIVars.TotalNumberOfConditionsInThisBlock = hist([val.Block],obj.UIVars.BlockList);
            [obj.UIVars.TimingFiles,~,obj.UIVars.TimingFilesNo] = unique({val.TimingFile}');
            
            obj.Conditions = val;
        end
        
        function val = parse_object(obj,str)
            if ~iscell(str), str = {str}; end
            nstr = length(str);
            a = cell(nstr,2);
            for m=1:nstr
                switch lower(str{m}(1:3))
                    case {'fix','dot'}  % fix(Xpos,Ypos)
                        tokens = regexp(str{m},'^([a-zA-Z]{3}) *\( *(-?\d+(?:\.\d*)?) *, *(-?\d+(?:\.\d*)?)\ *)','tokens');
                        if ~isempty(tokens), tokens{1}(2:3) = str2num(obj,tokens{1}(2:3)); b = 'FIX: default'; end %#ok<*ST2NM>
                    case 'pic'  % pic(filename,Xpos,Ypos[,colorkey]) or pic(filename,Xpos,Ypos,width,height[,colorkey])
                        tokens = regexp(str{m},'^([a-zA-Z]{3}) *\( *''?([^'',]+)''? *, *(-?\d+(?:\.\d*)?) *, *(-?\d+(?:\.\d*)?) *(?:, *)?(\[ *\d+(?:\.\d*)? *,? *\d+(?:\.\d*)? *,? *\d+(?:\.\d*)? *\])?(?: *)?\)|^([a-zA-Z]{3}) *\( *''?([^'',]+)''? *, *(-?\d+(?:\.\d*)?) *, *(-?\d+(?:\.\d*)?) *, *(\d+(?:\.\d*)?) *, *(\d+(?:\.\d*)?) *(?:, *)?(\[ *\d+(?:\.\d*)? *,? *\d+(?:\.\d*)? *,? *\d+(?:\.\d*)? *\])?(?: *)?\)','tokens');
                        if ~isempty(tokens)
                            [p,n] = find_ext(obj,tokens{1}{2},{'.bmp','.gif','.jpg','.jpeg','.tif','.tiff','.png'});
                            if isempty(p), error('PIC: Can''t find ''%s''',tokens{1}{2}); else tokens{1}{2} = p; end
%                             try mglimread(p); catch err, error('PIC: %s',err.message); end
                            if isempty(tokens{1}{end}), tokens{1} = tokens{1}(1:end-1); end
                            tokens{1}(3:end) = str2num(obj,tokens{1}(3:end));
                            if length(tokens{1})<6, b = sprintf('PIC: %s',lower(n)); else tokens{1}(5:6) = num2cell(round([tokens{1}{5:6}])); b = sprintf('PIC: %s [%d x %d]',lower(n),tokens{1}{5:6}); end
                            if 3==length(tokens{1}{end}), b = [b sprintf(', colorkey(%1.2g, %1.2g %1.2g)',tokens{1}{end})]; end %#ok<AGROW>
                        end
                    case 'mov'  % mov(filename,Xpos,Ypos)
                        tokens = regexp(str{m},'^([a-zA-Z]{3}) *\( *''?([^'',]+)''? *, *(-?\d+(?:\.\d*)?) *, *(-?\d+(?:\.\d*)?) *\)','tokens');
                        if ~isempty(tokens)
                            [p,n] = find_ext(obj,tokens{1}{2},{'.avi','.mpg','.mpeg'});
                            if isempty(p), error('MOV: Can''t find ''%s''',tokens{1}{2}); else tokens{1}{2} = p; end
%                             try mgldestroygraphic(mgladdmovie(p)); catch err, error('MOV: %s',err.message); end
                            tokens{1}(3:end) = str2num(obj,tokens{1}(3:end));
                            b = sprintf('MOV: %s',lower(n));
                        end
                    case 'crc'  % crc(radius,RGB,fill,Xpos,Ypos)
                        tokens = regexp(str{m},'^([a-zA-Z]{3}) *\( *(\d+(?:\.\d*)?) *, *(\[ *\d+(?:\.\d*)? *,? *\d+(?:\.\d*)? *,? *\d+(?:\.\d*)? *\]) *, *(\d+(?:\.\d*)?) *, *(-?\d+(?:\.\d*)?) *, *(-?\d+(?:\.\d*)?) *\)','tokens');
                        if ~isempty(tokens)
                            tokens{1}(2:end) = str2num(obj,tokens{1}(2:end));
                            if any(0==tokens{1}{2}), error('CRC: Size cannot be zero'); end
                            b = sprintf('CRC: %s r=%1.2g rgb=[%1.2g %1.2g %1.2g]',fi(obj,0<tokens{1}{4},'Solid','Outline'),tokens{1}{2:3});
                        end
                    case 'sqr'  % sqr(size,RGB,fill,Xpos,Ypos)
                        tokens = regexp(str{m},['^([a-zA-Z]{3}) *\( *(\d+(?:\.\d*)?) *, *(\[ *\d+(?:\.\d*)? *,? *\d+(?:\.\d*)? *,? *\d+(?:\.\d*)? *\]) *, *(\d+(?:\.\d*)?) *, *(-?\d+(?:\.\d*)?) *, *(-?\d+(?:\.\d*)?) *\)' ...
                            '|^([a-zA-Z]{3}) *\( *(\[ *\d+(?:\.\d*)? *,? *\d+(?:\.\d*)? *\]) *, *(\[ *\d+(?:\.\d*)? *,? *\d+(?:\.\d*)? *,? *\d+(?:\.\d*)? *\]) *, *(\d+(?:\.\d*)?) *, *(-?\d+(?:\.\d*)?) *, *(-?\d+(?:\.\d*)?) *\)'],'tokens');
                        if ~isempty(tokens)
                            tokens{1}(2:end) = str2num(obj,tokens{1}(2:end));
                            if any(0==tokens{1}{2}), error('SQR: Size cannot be zero'); end
                            if 1==length(tokens{1}{2}), tokens{1}{2} = [tokens{1}{2} tokens{1}{2}]; end
                            b = sprintf('SQR: %s [%1.2g x %1.2g] rgb=[%1.2g %1.2g %1.2g]',fi(obj,0<tokens{1}{4},'Solid','Outline'),tokens{1}{2:3});
                        end
                    case 'snd'  % snd(filename) or snd(sin,duration,frequency)
                        tokens = regexp(str{m},'^([a-zA-Z]{3}) *\( *''?([^'',]+)''? *\)|^([a-zA-Z]{3}) *\( *''?(?i:sin)''? *, *(\d+(?:\.\d*)?) *, *(\d+(?:\.\d*)?) *\)','tokens');
                        if ~isempty(tokens)
                            if 2==length(tokens{1})
                                [p,n] = find_ext(obj,tokens{1}{2},{'.wav','.mat'});
                                if isempty(p), error('SND: Can''t find ''%s''',tokens{1}{2}); else tokens{1}{2} = p; end
                                try load_waveform(tokens{1}); catch err, error('SND: %s',err.message); end
                                b = sprintf('SND: %s',lower(n));
                            else
                                tokens{1}(2:end) = str2num(obj,tokens{1}(2:end));
                                b = sprintf('SND: sine %g kHz, %g s',tokens{1}{3}/1000,tokens{1}{2});
                            end
                        end
                    case 'stm'  % stm(port,datasource[,retriggerable])
                        tokens = regexp(str{m},'^([a-zA-Z]{3}) *\( *(\d+) *, *''?([^'',]+)''? *\)|^([a-zA-Z]{3}) *\( *(\d+) *, *''?([^'',]+)''? *, *(\d+) *\)','tokens');
                        if ~isempty(tokens)
                            [p,n] = find_ext(obj,tokens{1}{3},{'.mat'});
                            if isempty(p), error('STM: Can''t find ''%s''',tokens{1}{3}); else tokens{1}{3} = p; end
                            try load_waveform(p); catch err, error('STM: %s',err.message); end
                            if 3==length(tokens{1}), tokens{1}(2) = str2num(obj,tokens{1}(2)); tokens{1}{4} = 0; else tokens{1}([2 4]) = str2num(obj,tokens{1}([2 4])); end
                            b = sprintf('STM: #%d%s, %s',tokens{1}{2},fi(obj,0<tokens{1}{4},' Retriggerable',''),lower(n));
                        end
                    case 'ttl'  % ttl(port)
                        tokens = regexp(str{m},'^([a-zA-Z]{3}) *\( *(\d+) *\)','tokens');
                        if ~isempty(tokens), tokens{1}(2) = str2num(obj,tokens{1}(2)); b = sprintf('TTL: #%d',tokens{1}{2}); end
                    case 'gen'  % gen(function_name) or gen(function_name,Xpos,Ypos)
                        tokens = regexp(str{m},'^([a-zA-Z]{3}) *\( *''?([^'',]+)''? *)|^([a-zA-Z]{3}) *\( *''?([^'',]+)''? *, *(-?\d+(?:\.\d*)?) *, *(-?\d+(?:\.\d*)?) *\)','tokens');
                        if ~isempty(tokens)
                            [p,n] = find_ext(obj,tokens{1}{2},{'.m'});
                            if isempty(p), error('GEN: Can''t find ''%s''',tokens{1}{2}); else tokens{1}{2} = p; end
                            try [~,func] = fileparts(n); trialrecord = mltrialrecord; cwd = pwd; cd(obj.MLPath.ExperimentDirectory); feval(func,trialrecord.simulate_1st_trial()); cd(cwd); catch err, if exist('cwd','var'), cd(cwd); end, error('GEN: %s',err.message); end
                            if 2<length(tokens{1}), tokens{1}(3:4) = str2num(obj,tokens{1}(3:4)); end
                            b = sprintf('GEN: %s',lower(n));
                        end
                    otherwise, error('Unknown object type, %s',str{m});
                end
                if isempty(tokens), error('Can''t parse out ''%s''',str{m}); end
                a{m,1} = b; a(m,2) = tokens(1);
            end
            val = cell2struct(a,{'Label','Attribute'},2);
        end
        
        function [p,n,e] = find_ext(obj,name,ext_list)
            [~,~,e] = fileparts(name); n = name;
            p = [obj.MLPath.ExperimentDirectory n]; if ~isempty(e) && 2==exist(p,'file'), return; end
            p = [obj.MLPath.BaseDirectory n]; if ~isempty(e) && 2==exist(p,'file'), return; end
            if ischar(ext_list), ext_list = {ext_list}; end
            for ext=ext_list(:)'
                e = ext{:}; n = [name e];
                p = [obj.MLPath.ExperimentDirectory n]; if 2==exist(p,'file'), return; end
                p = [obj.MLPath.BaseDirectory n]; if 2==exist(p,'file'), return; end
            end
            p = ''; n = ''; e = '';
        end
        function op = fi(~,tf,op1,op2)
            if tf, op = op1; else op = op2; end
        end
        function num = str2num(~,str)
            num = cellfun(@eval,str,'UniformOutput',false);
        end
        function val = token2num(~,token)
            if isempty(token), val = NaN; else val = str2double(token{1}); end
        end
        function val = unquote(~,str)
            nstr = length(str);
            val = cell(1,nstr);
            for m=1:nstr
                l = length(str{m});
                if l<2
                    val(m) = str(m);
                elseif 2==l
                    if strcmp(str{m},'""') || strcmp(str{m},''''''), val{m} = ''; else val(m) = str(m); end
                else
                    s1 = str{m}([1 l]);
                    s2 = str{m}(2:l-1);
                    if strcmp(s1,'""') && isempty(regexp(s2,'"','once')) || strcmp(s1,'''''') && isempty(regexp(s2,'''','once')) , val{m} = s2; else val(m) = str(m); end
                end
            end
        end
    end
end
