classdef mltaskobject_playback < matlab.mixin.Copyable
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
        Label
    end
    properties (Hidden)
        Size
        PixelsPerDegree
        SubjectScreenHalfSize
        DestroyObject
        SearchPath
    end
    methods
        function obj = mltaskobject_playback(taskobj,MLConfig)
            clear(obj);
            if ~exist('taskobj','var'), return; end
            if isa(taskobj,'mltaskobject')
                obj = copy(taskobj);
            else
                obj.PixelsPerDegree = MLConfig.PixelsPerDegree;
                obj.SubjectScreenHalfSize = MLConfig.Screen.SubjectScreenHalfSize;
                obj.DestroyObject = true;
            end
        end
        function delete(obj), clear(obj); end
        function clear(obj)
            try
                if obj.DestroyObject
                    mgldestroygraphic(obj.ID);
                end
            catch
                % for suppressing unnecessary error messages
            end
            obj.ID = [];
            obj.Modality = [];
            obj.Status = false;
            obj.Position = [];
            obj.ScreenPosition = [];
            obj.Info = struct;
            obj.MoreInfo = {};
            obj.Label = [];
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
        
        function createobj(obj,taskobj,MLConfig,TrialRecord)
            nobj = length(taskobj);
            obj.ID(1:nobj) = NaN;
            obj.Modality(1:nobj) = 0;
            obj.Status(1:nobj) = false;
            obj.Position(1:nobj,1:2) = NaN;
            obj.Info = taskobj;
            obj.MoreInfo(1:nobj) = cell(1,nobj);
            obj.Label = cell(1,nobj);

            switch class(taskobj)
                case 'cell'
                    for m=1:nobj
                        a = taskobj{m};
                        switch lower(a{1})
                            case 'gen'
                                a{2} = validate_path(obj,a{2});
                                if ~isempty(a{2})
                                    func = get_function_handle(a{2});
                                    info = [];
                                    switch nargout(func)
                                        case 2, [imdata,info] = func(TrialRecord);
                                        case 3, imdata = func(TrialRecord);
                                        case 4, [imdata,~,~,info] = func(TrialRecord);
                                        otherwise, imdata = func(TrialRecord);
                                    end
                                    if ischar(imdata)
                                        if 2==exist(imdata,'file')
                                            [~,~,e] = fileparts(imdata);
                                            switch lower(e)
                                                case {'.bmp','.gif','.jpg','.jpeg','.tif','.tiff','.png'}
                                                    bits = mglimread(imdata);
                                                    if 3==size(bits,3) && isfield(info,'Colorkey'), obj.ID(m) = mgladdbitmap(bits,info.Colorkey); else obj.ID(m) = mgladdbitmap(bits); end
                                                    obj.Modality(m) = 1;
                                                case {'.avi','.mpg','.mpeg'}
                                                    obj.ID(m) = mgladdmovie(imdata,0);
                                                    obj.Modality(m) = 2;
                                            end
                                        end
                                    else
                                        switch ndims(imdata)
                                            case 2
                                                if isfield(info,'Colorkey'), obj.ID(m) = mgladdbitmap(repmat(imdata,[1 1 3]),info.Colorkey); else obj.ID(m) = mgladdbitmap(repmat(imdata,[1 1 3])); end
                                                obj.Modality(m) = 1;
                                            case 3
                                                if 3==size(imdata,3) && isfield(info,'Colorkey'), obj.ID(m) = mgladdbitmap(imdata,info.Colorkey); else obj.ID(m) = mgladdbitmap(imdata); end
                                                obj.Modality(m) = 1;
                                            case 4
                                                if isfield(info,'TimePerFrame'), obj.ID(m) = mgladdmovie(imdata,info.TimePerFrame); else obj.ID(m) = mgladdmovie(imdata,0.033333333333333333333333333333333); end
                                                obj.Modality(m) = 2;
                                        end
                                    end
                                end
                                if isnan(obj.ID(m)), obj.ID(m) = mdqmex(43,[0 255 0]',obj.Size(m,:),2); obj.Modality(m) = 1; end
                            case {'fix','dot'}
                                obj.ID(m) = mgladdbitmap(load_cursor(MLConfig.FixationPointImage,MLConfig.FixationPointShape,MLConfig.FixationPointColor,MLConfig.PixelsPerDegree(1)*MLConfig.FixationPointDeg));
                                obj.Modality(m) = 1;
                            case 'pic'
                                a{2} = validate_path(obj,a{2});
                                if ~isempty(a{2})
                                    if 5<length(a), imdata = mglimresize(mglimread(a{2}),[a{6} a{5}]); else imdata = mglimread(a{2}); end
                                    if 3==size(imdata,3) && 3==length(a{end}), obj.ID(m) = mgladdbitmap(imdata,a{end}); else obj.ID(m) = mgladdbitmap(imdata); end
                                    obj.Modality(m) = 1;
                                else
                                    obj.ID(m) = mdqmex(43,[0 255 0]',obj.Size(m,:),2);
                                    obj.Modality(m) = 1;
                                end
                            case 'crc'
                                obj.ID(m) = mgladdbitmap(make_circle(MLConfig.PixelsPerDegree(1)*a{2},a{3},a{4}));
                                obj.Modality(m) = 1;
                            case 'sqr'
                                obj.ID(m) = mgladdbitmap(make_rectangle(MLConfig.PixelsPerDegree(1)*a{2},a{3},a{4}));
                                obj.Modality(m) = 1;
                            case 'mov'
                                a{2} = validate_path(obj,a{2});
                                if ~isempty(a{2})
                                    obj.ID(m) = mgladdmovie(a{2},0);
                                    obj.Modality(m) = 2;
                                else
                                    obj.ID(m) = mdqmex(43,[0 255 0]',obj.Size(m,:),2);
                                    obj.Modality(m) = 1;
                                end
                            case 'snd'
                                if 2==length(a), [~,n,e] = fileparts(a{2}); obj.Label{m} = [n e]; else obj.Label{m} = sprintf('Sine %g kHz',a{3}/1000); end
                                obj.Modality(m) = 3;
                            case 'stm', obj.Label{m} = sprintf('Stimulation %d',a{2}); obj.Modality(m) = 4;
                            case 'ttl', obj.Label{m} = sprintf('TTL %d',a{2}); obj.Modality(m) = 5;
                        end
                    end
                case 'struct'
                    for m=1:nobj
                        o = taskobj(m);
                        switch lower(o.Type)
                            case 'gen'
                                o.Name = validate_path(obj,o.Name);
                                if ~isempty(o.Name)
                                    func = get_function_handle(o.Name);
                                    info = [];
                                    switch nargout(func)
                                        case 2, [imdata,info] = func(TrialRecord);
                                        case 3, imdata = func(TrialRecord);
                                        case 4, [imdata,~,~,info] = func(TrialRecord);
                                        otherwise, imdata = func(TrialRecord);
                                    end
                                    if ischar(imdata)
                                        if 2==exist(imdata,'file')
                                            [~,~,e] = fileparts(imdata);
                                            switch lower(e)
                                                case {'.bmp','.gif','.jpg','.jpeg','.tif','.tiff','.png'}
                                                    bits = mglimread(imdata);
                                                    if 3==size(bits,3) && isfield(info,'Colorkey'), obj.ID(m) = mgladdbitmap(bits,info.Colorkey); else obj.ID(m) = mgladdbitmap(bits); end
                                                    obj.Modality(m) = 1;
                                                case {'.avi','.mpg','.mpeg'}
                                                    obj.ID(m) = mgladdmovie(imdata,0);
                                                    obj.Modality(m) = 2;
                                            end
                                        end
                                    else
                                        switch ndims(imdata)
                                            case 2
                                                if isfield(info,'Colorkey'), obj.ID(m) = mgladdbitmap(repmat(imdata,[1 1 3]),info.Colorkey); else obj.ID(m) = mgladdbitmap(repmat(imdata,[1 1 3])); end
                                                obj.Modality(m) = 1;
                                            case 3
                                                if 3==size(imdata,3) && isfield(info,'Colorkey'), obj.ID(m) = mgladdbitmap(imdata,info.Colorkey); else obj.ID(m) = mgladdbitmap(imdata); end
                                                obj.Modality(m) = 1;
                                            case 4
                                                if isfield(info,'TimePerFrame'), obj.ID(m) = mgladdmovie(imdata,info.TimePerFrame); else obj.ID(m) = mgladdmovie(imdata,0.033333333333333333333333333333333); end
                                                obj.Modality(m) = 2;
                                        end
                                    end
                                end
                                if isnan(obj.ID(m)), obj.ID(m) = mdqmex(43,[0 255 0]',obj.Size(m,:),2); obj.Modality(m) = 1; end
                            case {'fix','dot'}
                                obj.ID(m) = mgladdbitmap(load_cursor(MLConfig.FixationPointImage,MLConfig.FixationPointShape,MLConfig.FixationPointColor,MLConfig.PixelsPerDegree(1)*MLConfig.FixationPointDeg));
                                obj.Modality(m) = 1;
                            case 'pic'
                                o.Name = validate_path(obj,o.Name);
                                if ~isempty(o.Name)
                                    if isfield(o,'Xsize') && isfield(o,'Ysize'), imdata = mglimresize(mglimread(o.Name),[o.Ysize o.Xsize]); else imdata = mglimread(o.Name); end
                                    if 3==size(imdata,3) && isfield(o,'Colorkey'), obj.ID(m) = mgladdbitmap(imdata,o.Colorkey); else obj.ID(m) = mgladdbitmap(imdata); end
                                    obj.Modality(m) = 1;
                                else
                                    obj.ID(m) = mdqmex(43,[0 255 0]',obj.Size(m,:),2);
                                    obj.Modality(m) = 1;
                                end
                            case 'crc'
                                obj.ID(m) = mgladdbitmap(make_circle(MLConfig.PixelsPerDegree(1)*o.Radius,o.Color,o.FillFlag));
                                obj.Modality(m) = 1;
                            case 'sqr'
                                obj.ID(m) = mgladdbitmap(make_rectangle([o.Xsize o.Ysize]*MLConfig.PixelsPerDegree(1),o.Color,o.FillFlag));
                                obj.Modality(m) = 1;
                            case 'mov'
                                o.Name = validate_path(obj,o.Name);
                                if ~isempty(o.Name)
                                    obj.ID(m) = mgladdmovie(o.Name,0);
                                    obj.Modality(m) = 2;
                                else
                                    obj.ID(m) = mdqmex(43,[0 255 0]',obj.Size(m,:),2);
                                    obj.Modality(m) = 1;
                                end
                            case 'snd'
                                if isfield(o,'Name') && ~isempty(o.Name)
                                    if strcmpi(o.Name,'sin'), obj.Label{m} = sprintf('Sine %g kHz',o.Freq/1000); else [~,n,e] = fileparts(o.Name); obj.Label{m} = [n e]; end
                                else
                                    obj.Label{m} = 'Wave sound';
                                end
                                obj.Modality(m) = 3;
                            case 'stm', obj.Label{m} = sprintf('Stimulation %d',o.OutputPort); obj.Modality(m) = 4;
                            case 'ttl', obj.Label{m} = sprintf('TTL %d',o.OutputPort); obj.Modality(m) = 5;
                        end
                    end
            end
            mglactivategraphic(obj.ID,false);
        end
        
        function obj = subsasgn(obj,s,b)
            switch length(s)
                case 1
                    obj.(s(1).subs) = b;
                    switch s(1).subs
                        case 'Position'
                            obj.ScreenPosition = get_ScreenPosition(obj,obj.Position);
                            visualobj = 1==obj.Modality | 2==obj.Modality;
                            mglsetorigin(obj.ID(visualobj),obj.ScreenPosition(visualobj,:));
                    end
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
                                            obj.ScreenPosition(s(2).subs{1},:) = get_ScreenPosition(obj,b);
                                        otherwise, error('''%s'' is a read-only property',s(1).subs);
                                    end
                                end
                            end
                        otherwise
                            error('Unknown subsref type');
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
                                            case {'MoreInfo','Label'}, varargout(1) = obj.(s(2).subs)(s(1).subs{1});
                                            case {'Position','ScreenPosition','Size'}, varargout{1} = obj.(s(2).subs)(s(1).subs{1},:);
                                            otherwise, varargout{1} = obj.(s(2).subs)(s(1).subs{1});
                                        end
                                    else
                                        varargout = cell(narr,1);
                                        for m=1:narr
                                            switch s(2).subs
                                                case {'MoreInfo','Label'}, varargout(m) = obj.(s(2).subs)(s(1).subs{1}(m));
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
                                            case {'MoreInfo','Label'}, if 1==length(s(2).subs{1}), varargout{1} = obj.(s(1).subs){s(2).subs{1}}; else varargout{1} = obj.(s(1).subs)(s(2).subs{1}); end
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
        
        function filepath = validate_path(obj,filepath)
            if isempty(filepath), return, end
            if 2==exist(filepath,'file'), return, end
            [~,n,e] = fileparts(filepath);
            p = [obj.SearchPath.manual_path obj.SearchPath.base_path];
            for m=1:length(p)
                filepath = [p{m} n e];
                if 2==exist(filepath,'file'), break; else filepath = []; end
            end
            if isempty(filepath) && ~obj.SearchPath.no_for_all
                mglsetcontrolscreenshow(false);
                options.Interpreter = 'tex';
                options.Default = 'Yes';
                qstring = ['\fontsize{10}Can''t find the file, ''' regexprep([n e],'([\^_\\])','\\$1') '''.' char(10) 'You can keep the stimulus files with the data file or' char(10) 'under the "images" or "stimuli" subdirectory.' char(10) 'Would you like to manually locate it?'];
                button = questdlg(qstring,'Missing stimulus file','Yes','No','No for all',options);
                switch button
                    case 'Yes'
                        [n,p] = uigetfile([n e]);
                        if 0~=n, obj.SearchPath.manual_path{end+1} = p; filepath = [p n]; end
                    case 'No for all', obj.SearchPath.no_for_all = true;
                end
                mglsetcontrolscreenshow(true);
            end
        end
    end
end
