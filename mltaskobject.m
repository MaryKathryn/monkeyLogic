classdef mltaskobject < matlab.mixin.Copyable
    properties (SetAccess = protected)
        ID
        Modality
    end
    properties
        Status
        Position
    end
    properties (SetAccess = protected)
        ScreenPosition
        Info
        MoreInfo
    end
    properties (SetAccess = protected, Hidden)
        Size
        PixelsPerDegree
        SubjectScreenHalfSize
        DestroyObject
    end
    methods
        function obj = mltaskobject(taskobj,MLConfig,TrialRecord)
            init(obj);
            if ~exist('taskobj','var'), return; end
            if isa(taskobj,'mltaskobject')
                obj = copy(taskobj);
            else
                obj.PixelsPerDegree = MLConfig.PixelsPerDegree;
                obj.SubjectScreenHalfSize = MLConfig.Screen.SubjectScreenHalfSize;
                if ~exist('TrialRecord','var') || ~isa(TrialRecord,'mltrialrecord'), TrialRecord = mltrialrecord; TrialRecord = TrialRecord.simulate_1st_trial; end
                if ischar(taskobj), taskobj = {taskobj}; end
                if iscell(taskobj), taskobj = MLConfig.MLConditions.parse_object(taskobj); end
                if isfield(taskobj,'Attribute'), createobj(obj,taskobj,MLConfig,TrialRecord); else createobj_from_struct(obj,taskobj,MLConfig,TrialRecord); end
                obj.DestroyObject = true;
            end
            mglactivategraphic(obj.ID(1==obj.Modality | 2==obj.Modality),false);
            mglactivatesound(obj.ID(3==obj.Modality),false);
            TrialRecord.set_stimulus_info(obj);
        end
        function delete(obj)
            movie = 2==obj.Modality;
            visual = 1==obj.Modality | movie;
            sound = 3==obj.Modality;
            try
                if obj.DestroyObject
                    mgldestroygraphic(obj.ID(visual));
                    mgldestroysound(obj.ID(sound));
                else
                    mglactivategraphic(obj.ID(visual),false);
                    mglsetproperty(obj.ID(movie),'seek',0);
                    mglactivatesound(obj.ID(sound),false);
                end
            catch
                % for suppressing unnecessary error messages
            end
        end
        function init(obj)
            obj.ID = [];
            obj.Modality = [];
            obj.Status = false;
            obj.Position = [];
            obj.ScreenPosition = [];
            obj.Info = struct;
            obj.MoreInfo = {};
            obj.Size = [];
            obj.DestroyObject = false;
        end
        function val = length(obj), val = length(obj.ID); end
        function val = size(obj), val = size(obj.ID); end
        function val = horzcat(obj,varargin)
            val = copy(obj);
            for m=1:length(varargin)
                val.ID = [val.ID varargin{m}.ID];
                val.Modality = [val.Modality varargin{m}.Modality];
                val.Status = [val.Status varargin{m}.Status];
                val.Position = [val.Position; varargin{m}.Position];
                val.ScreenPosition = [val.ScreenPosition; varargin{m}.ScreenPosition];
                val.Info = [val.Info; varargin{m}.Info];
                val.MoreInfo = [val.MoreInfo varargin{m}.MoreInfo];
                val.Size = [val.Size; varargin{m}.Size]; 
            end
        end
        function val = vertcat(obj,varargin), val = horzcat(obj,varargin{:}); end
        
        function obj = subsasgn(obj,s,b)
            switch length(s)
                case 1, error('This type of assignment is not allowed.');
                case 2
                    switch s(1).type
                        case {'()','{}'}
                            if strcmp(s(2).type,'.')
                                if isempty(s(1).subs{1})
                                    error('Index is not given');
                                else
                                    switch s(2).subs
                                        case 'Status', obj.Status(s(1).subs{1}) = b;
                                        case 'Position'
                                            obj.Position(s(1).subs{1},:) = b;
                                            obj.ScreenPosition(s(1).subs{1},:) = get_ScreenPosition(obj,b);
                                        otherwise, error('''%s'' is a read-only property',s(2).subs);
                                    end
                                end
                            end
                        case '.'
                            if strcmp(s(2).type,'()') || strcmp(s(2).type,'{}')
                                if isempty(s(2).subs{1})
                                    error('Index is not given');
                                else
                                    switch s(1).subs
                                        case 'Status', obj.Status(s(2).subs{1}) = b;
                                        case 'Position'
                                            obj.Position(s(2).subs{1},:) = b;
                                            obj.ScreenPosition(s(2).subs{1},:) = get_ScreenPosition(obj,obj.Position(s(2).subs{1},:));
                                        otherwise, error('''%s'' is a read-only property',s(1).subs);
                                    end
                                end
                            end
                        otherwise
                            error('Unknown subsref type');
                    end
                case 3
                    switch s(1).type
                        case {'()','{}'}
                            if strcmp(s(2).type,'.')
                                if isempty(s(1).subs{1})
                                    error('Index is not given');
                                else
                                    switch s(2).subs
                                        case 'Position'
                                            obj.Position(s(1).subs{1},s(3).subs{1}) = b;
                                            obj.ScreenPosition(s(1).subs{1},:) = get_ScreenPosition(obj,obj.Position(s(1).subs{1},:));
                                        otherwise, error('''%s'' is a read-only property',s(2).subs);
                                    end
                                end
                            end
                    end
                otherwise
                    error('This type of assignment is not allowed.');
            end
        end
        
        function varargout = subsref(obj,s)
            switch length(s)
                case 1
                    switch s.type
                        case {'()','{}'}
                            if isempty(s.subs)
                                varargout{1} = [];
                            else
                                idx = s.subs{1};
                                varargout{1} = mltaskobject;
                                varargout{1}.ID = obj.ID(idx);
                                varargout{1}.Modality = obj.Modality(idx);
                                varargout{1}.Status = obj.Status(idx);
                                varargout{1}.Position = obj.Position(idx,:);
                                varargout{1}.ScreenPosition = obj.ScreenPosition(idx,:);
                                varargout{1}.Info = obj.Info(idx);
                                varargout{1}.MoreInfo = obj.MoreInfo(idx);
                                varargout{1}.Size = obj.Size(idx,:);
                                varargout{1}.PixelsPerDegree = obj.PixelsPerDegree;
                                varargout{1}.SubjectScreenHalfSize = obj.SubjectScreenHalfSize;
                                varargout{1}.DestroyObject = false;
                            end
                        case '.'
                            varargout{1} = obj.(s.subs);
                        otherwise
                            error('Unknown subsref type');
                    end
                case 2
                    switch s(1).type
                        case {'()','{}'}
                            if strcmp(s(2).type,'.')
                                if isempty(s(1).subs)
                                    varargout{1} = [];
                                else
                                    narr = length(s(1).subs{1});
                                    if 1==narr
                                        switch s(2).subs
                                            case 'MoreInfo', varargout(1) = obj.(s(2).subs)(s(1).subs{1});
                                            case {'Position','ScreenPosition','Size'}, varargout{1} = obj.(s(2).subs)(s(1).subs{1},:);
                                            otherwise, varargout{1} = obj.(s(2).subs)(s(1).subs{1});
                                        end
                                    else
                                        varargout = cell(narr,1);
                                        for m=1:narr
                                            switch s(2).subs
                                                case 'MoreInfo', varargout(m) = obj.(s(2).subs)(s(1).subs{1}(m));
                                                case {'Position','ScreenPosition','Size'}, varargout{m} = obj.(s(2).subs)(s(1).subs{1}(m),:);
                                                otherwise, varargout{m} = obj.(s(2).subs)(s(1).subs{1}(m));
                                            end
                                        end
                                    end
                                end
                            end
                        case '.'
                            switch s(2).type
                                case {'()','{}'}
                                    if isempty(s(2).subs)
                                        varargout{1} = [];
                                    else
                                        switch s(1).subs
                                            case 'MoreInfo', if 1==length(s(2).subs{1}), varargout{1} = obj.(s(1).subs){s(2).subs{1}}; else varargout{1} = obj.(s(1).subs)(s(2).subs{1}); end
                                            case {'Position','ScreenPosition','Size'}, varargout{1} = obj.(s(1).subs)(s(2).subs{1},:);
                                            otherwise, varargout{1} = obj.(s(1).subs)(s(2).subs{1});
                                        end
                                    end
                                case '.'
                                    narr = length(obj);
                                    if 1==narr
                                        switch s(1).subs
                                            case 'Info', varargout{1} = obj.(s(1).subs)(1).(s(2).subs);
                                            case 'MoreInfo', varargout{1} = obj.(s(1).subs){1}.(s(2).subs);
                                        end
                                    else
                                        varargout{1} = cell(1,narr);
                                        switch s(1).subs
                                            case 'Info', for m=1:narr, varargout{1}{m} = obj.(s(1).subs)(m).(s(2).subs); end
                                            case 'MoreInfo', for m=1:narr, varargout{1}{m} = obj.(s(1).subs){m}.(s(2).subs); end
                                        end
                                    end
                            end
                        otherwise
                            error('Unknown subsref type');
                    end
                case 3
                    switch s(1).type
                        case {'()','{}'}
                            if '.'==s(2).type
                                narr = length(s(1).subs{1});
                                varargout = cell(1,narr);
                                switch s(2).subs
                                    case {'Position','ScreenPosition'}, varargout{1} = obj.(s(2).subs)(s(1).subs{1},s(3).subs{1});
                                    case 'Info', for m=1:narr, varargout{m} = obj.(s(2).subs)(s(1).subs{1}(m)).(s(3).subs); end
                                    case 'MoreInfo', for m=1:narr, varargout{m} = obj.(s(2).subs){s(1).subs{1}(m)}.(s(3).subs); end
                                end
                            end
                        case '.'
                            if strcmp(s(2).type,'()') || strcmp(s(2).type,'{}')
                                narr = length(s(2).subs{1});
                                if 1==narr
                                    switch s(1).subs
                                        case 'Info', varargout{1} = obj.(s(1).subs)(s(2).subs{1}).(s(3).subs);
                                        case 'MoreInfo', varargout{1} = obj.(s(1).subs){s(2).subs{1}}.(s(3).subs);
                                    end
                                else                                    
                                    varargout{1} = cell(1,narr);
                                    switch s(1).subs
                                        case 'Info', for m=1:narr, varargout{1}{m} = obj.(s(1).subs)(s(2).subs{1}(m)).(s(3).subs); end
                                        case 'MoreInfo', for m=1:narr, varargout{1}{m} = obj.(s(1).subs){s(2).subs{1}(m)}.(s(3).subs); end
                                    end
                                end
                            end
                        otherwise
                            error('Unknown subsref type');
                    end
                case 4
                    switch s(1).type
                        case {'()','{}'}, varargout{1} = obj.(s(2).subs)(s(1).subs{1}).(s(3).subs){s(4).subs{1}};
                        case '.', varargout{1} = obj.(s(1).subs)(s(2).subs{1}).(s(3).subs){s(4).subs{1}};
                    end
                otherwise
                    error('Unknown subsref type');
            end
        end
    end
    
    methods (Access = protected)
        function cp = copyElement(obj)
            cp = copyElement@matlab.mixin.Copyable(obj);
            cp.DestroyObject = false;
        end
        function val = get_ScreenPosition(obj,Position)
            n = size(Position,1);
            val = round(Position .* repmat(obj.PixelsPerDegree,n,1)) + repmat(obj.SubjectScreenHalfSize,n,1);
        end
        
        function createobj_from_struct(obj,taskobj,MLConfig,TrialRecord)
            nobj = length(taskobj);
            obj.ID(1:nobj) = NaN;
            obj.Modality(1:nobj) = 0;
            obj.Status(1:nobj) = false;
            obj.Position(1:nobj,1:2) = NaN;
            obj.Info = taskobj;
            obj.MoreInfo(1:nobj) = cell(1,nobj);
            obj.Size(1:nobj,1:2) = 0;

            for m=1:nobj
                o = taskobj(m);
                switch lower(o.Type)
                    case 'gen'
                        [~,n] = fileparts(o.Name);
                        if isfield(o,'Xpos'), x = o.Xpos; else x = 0; end
                        if isfield(o,'Ypos'), y = o.Ypos; else y = 0; end
                        info = [];
                        switch nargout(n)
                            case 2, [imdata,info] = feval(n,TrialRecord);
                            case 3, [imdata,x,y] = feval(n,TrialRecord);
                            case 4, [imdata,x,y,info] = feval(n,TrialRecord);
                            otherwise, imdata = feval(n,TrialRecord);
                        end
                        if ischar(imdata)
                            if 2~=exist(imdata,'file'), error('File from Gen doesn''t exist'); end
                            [~,~,e] = fileparts(imdata);
                            switch lower(e)
                                case {'.bmp','.gif','.jpg','.jpeg','.tif','.tiff','.png'}
                                    bits = mglimread(imdata);
                                    if 3==size(bits,3) && isfield(info,'Colorkey'), obj.ID(m) = mgladdbitmap(bits,info.Colorkey); else obj.ID(m) = mgladdbitmap(bits); end
                                    obj.Modality(m) = 1;
                                    info = copyfield(obj,info,imfinfo(imdata));
                                    info.Size = mglgetproperty(obj.ID(m),'size');
                                case {'.avi','.mpg','.mpeg'}
                                    obj.ID(m) = mgladdmovie(imdata);
                                    obj.Modality(m) = 2;
                                    info.Filename = imdata;
                                    info = copyfield(obj,info,mglgetproperty(obj.ID(m),'info'));
                                otherwise
                                    error('Unknown file type from Gen');
                            end
                        else
                            info.Filename = o.Name;
                            switch ndims(imdata)
                                case 2
                                    if isfield(info,'Colorkey'), obj.ID(m) = mgladdbitmap(repmat(imdata,[1 1 3]),info.Colorkey); else obj.ID(m) = mgladdbitmap(repmat(imdata,[1 1 3])); end
                                    obj.Modality(m) = 1;
                                    info.Size = mglgetproperty(obj.ID(m),'size');
                                case 3
                                    if 3==size(imdata,3) && isfield(info,'Colorkey'), obj.ID(m) = mgladdbitmap(imdata,info.Colorkey); else obj.ID(m) = mgladdbitmap(imdata); end
                                    obj.Modality(m) = 1;
                                    info.Size = mglgetproperty(obj.ID(m),'size');
                                case 4
                                    if isfield(info,'TimePerFrame'), obj.ID(m) = mgladdmovie(imdata,info.TimePerFrame); else obj.ID(m) = mgladdmovie(imdata,0.033333333333333333333333333333333); end
                                    obj.Modality(m) = 2;
                                    info = copyfield(obj,info,mglgetproperty(obj.ID(m),'info'));
                                otherwise, error('Image type from Gen cannot be determined');
                            end
                        end
                        obj.Position(m,:) = [x y];
                        obj.MoreInfo{m} = info;
                        obj.Size(m,:) = obj.MoreInfo{m}.Size;
                    case {'fix','dot'}
                        obj.ID(m) = mgladdbitmap(load_cursor(MLConfig.FixationPointImage,MLConfig.FixationPointShape,MLConfig.FixationPointColor,MLConfig.PixelsPerDegree(1)*MLConfig.FixationPointDeg));
                        obj.Modality(m) = 1;
                        obj.Position(m,:) = [o.Xpos o.Ypos];
                        if isempty(MLConfig.FixationPointImage), obj.MoreInfo{m}.Filename = ''; else obj.MoreInfo{m} = imfinfo(MLConfig.FixationPointImage); end
                        obj.MoreInfo{m}.Size = mglgetproperty(obj.ID(m),'size');
                        obj.Size(m,:) = obj.MoreInfo{m}.Size;
                    case 'pic'
                        if isfield(o,'Xsize') && isfield(o,'Ysize'), imdata = mglimresize(mglimread(o.Name),[o.Ysize o.Xsize]); else imdata = mglimread(o.Name); end
                        if 3==size(imdata,3) && isfield(o,'Colorkey'), obj.ID(m) = mgladdbitmap(imdata,o.Colorkey); else obj.ID(m) = mgladdbitmap(imdata); end
                        obj.Modality(m) = 1;
                        obj.Position(m,:) = [o.Xpos o.Ypos];
                        obj.MoreInfo{m} = imfinfo(o.Name);
                        obj.MoreInfo{m}.Size = mglgetproperty(obj.ID(m),'size');
                        obj.Size(m,:) = obj.MoreInfo{m}.Size;
                    case 'crc'
                        obj.ID(m) = mgladdbitmap(make_circle(MLConfig.PixelsPerDegree(1)*o.Radius,o.Color,o.FillFlag));
                        obj.Modality(m) = 1;
                        obj.Position(m,:) = [o.Xpos o.Ypos];
                        obj.MoreInfo{m}.Filename = '';
                        obj.MoreInfo{m}.Size = mglgetproperty(obj.ID(m),'size');
                        obj.Size(m,:) = obj.MoreInfo{m}.Size;
                    case 'sqr'
                        obj.ID(m) = mgladdbitmap(make_rectangle([o.Xsize o.Ysize]*MLConfig.PixelsPerDegree(1),o.Color,o.FillFlag));
                        obj.Modality(m) = 1;
                        obj.Position(m,:) = [o.Xpos o.Ypos];
                        obj.MoreInfo{m}.Filename = '';
                        obj.MoreInfo{m}.Size = mglgetproperty(obj.ID(m),'size');
                        obj.Size(m,:) = obj.MoreInfo{m}.Size;
                    case 'mov'
                        obj.ID(m) = mgladdmovie(o.Name);
                        obj.Modality(m) = 2;
                        obj.Position(m,:) = [o.Xpos o.Ypos];
                        obj.MoreInfo{m}.Filename = o.Name;
                        obj.MoreInfo{m} = copyfield(obj,obj.MoreInfo{m},mglgetproperty(obj.ID(m),'info'));
                        obj.Size(m,:) = obj.MoreInfo{m}.Size;
                    case 'snd'
                        if isfield(o,'Name') && ~isempty(o.Name)
                            if strcmpi(o.Name,'sin')
                                [y,fs] = load_waveform({'snd', o.Duration, o.Freq});
                                obj.MoreInfo{m}.Filename = '';
                            else
                                [y,fs] = load_waveform({'snd', o.Name});
                                obj.MoreInfo{m}.Filename = o.Name;
                            end
                        else
                            y = o.WaveForm;
                            fs = o.Freq;
                            obj.MoreInfo{m}.Filename = '';
                        end
                        obj.ID(m) = mgladdsound(y,fs);
                        obj.Modality(m) = 3;
                        obj.MoreInfo{m}.Duration = length(y)/fs;
                        obj.MoreInfo{m}.Frequency = fs;
                    case 'stm'
                        obj.ID(m) = o.OutputPort;
                        obj.Modality(m) = 4;
                        if isfield(o,'Name') && ~isempty(o.Name)
                            [y,fs] = load_waveform(o.Name);
                            obj.MoreInfo{m}.Filename = o.Name;
                        else
                            y = o.WaveForm;
                            fs = o.Freq;
                            obj.MoreInfo{m}.Filename = '';
                        end
                        obj.MoreInfo{m}.Channel = o.OutputPort;
                        obj.MoreInfo{m}.Duration = length(y)/fs;
                        obj.MoreInfo{m}.Frequency = fs;
                        ao = MLConfig.DAQ.Stimulation{o.OutputPort};
                        if isempty(ao)
                            if ~TrialRecord.SimulationMode, error('''Stimulation %d'' is not assigned',o.OutputPort); end
                        else
                            stop(ao);
                            actual_rate = setverify(ao,'SampleRate',fs);
                            if actual_rate~=fs, error('output frequency is %g kHz, instead of %g kHz',actual_rate/1000,fs/1000); end
                            ch = strcmp(ao.Channel.ChannelName,sprintf('Stimulation%d',o.OutputPort));
                            data = zeros(length(y),length(ao.Channel));
                            data(:,ch) = y;
                            if isfield(o,'Retriggering'), ao.RegenerationMode = o.Retriggering; else ao.RegenerationMode = 0; end
                            putdata(ao,data);
                            start(ao);
                        end
                    case 'ttl'
                        obj.ID(m) = o.OutputPort;
                        obj.Modality(m) = 5;
                        obj.MoreInfo{m}.Filename = '';
                        obj.MoreInfo{m}.Channel = o.OutputPort;
                        if isempty(MLConfig.DAQ.TTL{o.OutputPort}) && ~TrialRecord.SimulationMode, error('''TTL %d'' is not assigned',o.OutputPort); end
                end
            end
            obj.ScreenPosition = get_ScreenPosition(obj,obj.Position);
            visualobj = 1==obj.Modality | 2==obj.Modality;
            mglsetorigin(obj.ID(visualobj),obj.ScreenPosition(visualobj,:));
        end
        
        function createobj(obj,taskobj,MLConfig,TrialRecord)
            nobj = length(taskobj);
            obj.ID(1:nobj) = NaN;
            obj.Modality(1:nobj) = 0;
            obj.Status(1:nobj) = false;
            obj.Position(1:nobj,1:2) = NaN;
            obj.Info = taskobj;
            obj.MoreInfo(1:nobj) = cell(1,nobj);
            obj.Size(1:nobj,1:2) = 0;

            for m=1:nobj
                a = taskobj(m).Attribute;
                switch lower(a{1})
                    case 'gen'
                        [~,n] = fileparts(a{2});
                        if 2<length(a), x = a{3}; y = a{4}; else x = 0; y = 0; end
                        info = [];
                        switch nargout(n)
                            case 2, [imdata,info] = feval(n,TrialRecord);
                            case 3, [imdata,x,y] = feval(n,TrialRecord);
                            case 4, [imdata,x,y,info] = feval(n,TrialRecord);
                            otherwise, imdata = feval(n,TrialRecord);
                        end
                        if ischar(imdata)
                            if 2~=exist(imdata,'file'), error('File from Gen doesn''t exist'); end
                            [~,~,e] = fileparts(imdata);
                            switch lower(e)
                                case {'.bmp','.gif','.jpg','.jpeg','.tif','.tiff','.png'}
                                    bits = mglimread(imdata);
                                    if 3==size(bits,3) && isfield(info,'Colorkey'), obj.ID(m) = mgladdbitmap(bits,info.Colorkey); else obj.ID(m) = mgladdbitmap(bits); end
                                    obj.Modality(m) = 1;
                                    info = copyfield(obj,info,imfinfo(imdata));
                                    info.Size = mglgetproperty(obj.ID(m),'size');
                                case {'.avi','.mpg','.mpeg'}
                                    obj.ID(m) = mgladdmovie(imdata);
                                    obj.Modality(m) = 2;
                                    info.Filename = imdata;
                                    info = copyfield(obj,info,mglgetproperty(obj.ID(m),'info'));
                                otherwise
                                    error('Unknown file type from Gen');
                            end
                        else
                            info.Filename = '';
                            switch ndims(imdata)
                                case 2
                                    if isfield(info,'Colorkey'), obj.ID(m) = mgladdbitmap(repmat(imdata,[1 1 3]),info.Colorkey); else obj.ID(m) = mgladdbitmap(repmat(imdata,[1 1 3])); end
                                    obj.Modality(m) = 1;
                                    info.Size = mglgetproperty(obj.ID(m),'size');
                                case 3
                                    if 3==size(imdata,3) && isfield(info,'Colorkey'), obj.ID(m) = mgladdbitmap(imdata,info.Colorkey); else obj.ID(m) = mgladdbitmap(imdata); end
                                    obj.Modality(m) = 1;
                                    info.Size = mglgetproperty(obj.ID(m),'size');
                                case 4
                                    if isfield(info,'TimePerFrame'), obj.ID(m) = mgladdmovie(imdata,info.TimePerFrame); else obj.ID(m) = mgladdmovie(imdata,0.033333333333333333333333333333333); end
                                    obj.Modality(m) = 2;
                                    info = copyfield(obj,info,mglgetproperty(obj.ID(m),'info'));
                                otherwise, error('Image type from Gen cannot be determined');
                            end
                        end
                        obj.Position(m,:) = [x y];
                        obj.MoreInfo{m} = info;
                        obj.Size(m,:) = obj.MoreInfo{m}.Size;
                    case {'fix','dot'}
                        obj.ID(m) = mgladdbitmap(load_cursor(MLConfig.FixationPointImage,MLConfig.FixationPointShape,MLConfig.FixationPointColor,MLConfig.PixelsPerDegree(1)*MLConfig.FixationPointDeg));
                        obj.Modality(m) = 1;
                        obj.Position(m,:) = [a{2:3}];
                        if isempty(MLConfig.FixationPointImage), obj.MoreInfo{m}.Filename = ''; else obj.MoreInfo{m} = imfinfo(MLConfig.FixationPointImage); end
                        obj.MoreInfo{m}.Size = mglgetproperty(obj.ID(m),'size');
                        obj.Size(m,:) = obj.MoreInfo{m}.Size;
                    case 'pic'
                        if 5<length(a), imdata = mglimresize(mglimread(a{2}),[a{6} a{5}]); else imdata = mglimread(a{2}); end
                        if 3==size(imdata,3) && 3==length(a{end}), obj.ID(m) = mgladdbitmap(imdata,a{end}); else obj.ID(m) = mgladdbitmap(imdata); end
                        obj.Modality(m) = 1;
                        obj.Position(m,:) = [a{3:4}];
                        obj.MoreInfo{m} = imfinfo(a{2});
                        obj.MoreInfo{m}.Size = mglgetproperty(obj.ID(m),'size');
                        obj.Size(m,:) = obj.MoreInfo{m}.Size;
                    case 'crc'
                        obj.ID(m) = mgladdbitmap(make_circle(MLConfig.PixelsPerDegree(1)*a{2},a{3},a{4}));
                        obj.Modality(m) = 1;
                        obj.Position(m,:) = [a{5:6}];
                        obj.MoreInfo{m}.Filename = '';
                        obj.MoreInfo{m}.Size = mglgetproperty(obj.ID(m),'size');
                        obj.Size(m,:) = obj.MoreInfo{m}.Size;
                    case 'sqr'
                        obj.ID(m) = mgladdbitmap(make_rectangle(MLConfig.PixelsPerDegree(1)*a{2},a{3},a{4}));
                        obj.Modality(m) = 1;
                        obj.Position(m,:) = [a{5:6}];
                        obj.MoreInfo{m}.Filename = '';
                        obj.MoreInfo{m}.Size = mglgetproperty(obj.ID(m),'size');
                        obj.Size(m,:) = obj.MoreInfo{m}.Size;
                    case 'mov'
                        obj.ID(m) = mgladdmovie(a{2});
                        obj.Modality(m) = 2;
                        obj.Position(m,:) = [a{3:4}];
                        obj.MoreInfo{m}.Filename = a{2};
                        obj.MoreInfo{m} = copyfield(obj,obj.MoreInfo{m},mglgetproperty(obj.ID(m),'info'));
                        obj.Size(m,:) = obj.MoreInfo{m}.Size;
                    case 'snd'
                        [y,fs] = load_waveform(a);
                        obj.ID(m) = mgladdsound(y,fs);
                        obj.Modality(m) = 3;
                        if 2==length(a)
                            obj.MoreInfo{m}.Filename = a{2};
                        else
                            obj.MoreInfo{m}.Filename = '';
                        end
                        obj.MoreInfo{m}.Duration = length(y)/fs;
                        obj.MoreInfo{m}.Frequency = fs;
                    case 'stm'
                        obj.ID(m) = a{2};
                        obj.Modality(m) = 4;
                        [y,fs] = load_waveform(a{3});
                        obj.MoreInfo{m}.Filename = a{3};
                        obj.MoreInfo{m}.Channel = a{2};
                        obj.MoreInfo{m}.Duration = length(y)/fs;
                        obj.MoreInfo{m}.Frequency = fs;
                        o = MLConfig.DAQ.Stimulation{a{2}};
                        if isempty(o)
                            if ~TrialRecord.SimulationMode, error('''Stimulation %d'' is not assigned',a{2}); end
                        else
                            stop(o);
                            actual_rate = setverify(o,'SampleRate',fs);
                            if actual_rate~=fs, error('output frequency is %g kHz, instead of %g kHz',actual_rate/1000,fs/1000); end
                            ch = strcmp(o.Channel.ChannelName,sprintf('Stimulation%d',a{2}));
                            data = zeros(length(y),length(o.Channel));
                            data(:,ch) = y;
                            o.RegenerationMode = a{4};
                            putdata(o,data);
                            start(o);
                        end
                    case 'ttl'
                        obj.ID(m) = a{2};
                        obj.Modality(m) = 5;
                        obj.MoreInfo{m}.Filename = '';
                        obj.MoreInfo{m}.Channel = a{2};
                        if isempty(MLConfig.DAQ.TTL{a{2}}) && ~TrialRecord.SimulationMode, error('''TTL %d'' is not assigned',a{2}); end
                    case 'ctx'
                        obj.ID(m) = a{2}; %object ID is the context value
                        obj.Modality(m) = 6; %VR Context
                      
                    case 'gol'
                        obj.ID(m) = a{2}; %object ID is the context value
                        obj.Modality(m) = 7; %VR Goal
                        obj.MoreInfo{m}.Color = a{3};
                        obj.MoreInfo{m}.Value = a{2};
                end
            end
            obj.ScreenPosition = get_ScreenPosition(obj,obj.Position);
            visualobj = 1==obj.Modality | 2==obj.Modality;
            mglsetorigin(obj.ID(visualobj),obj.ScreenPosition(visualobj,:));
        end
        
        function dest = copyfield(~,dest,src,field)
            if isempty(src), src = struct; end
            if isempty(dest), dest = struct; end
            if ~exist('field','var'), field = fieldnames(src); end
            for m=1:length(field), dest.(field{m}) = src.(field{m}); end
        end
    end
end
