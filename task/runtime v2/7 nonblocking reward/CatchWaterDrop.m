classdef CatchWaterDrop < handle
    properties
        Position
        Threshold = 1;
        HoldTime = 500;
        Reward = 100;
    end
    properties (SetAccess = protected)
        Success
    end
    properties (Access = protected)
        Adapter
        Tracker
        WaterDropID
        FixWindowID
        CurrentStone
        FixTime
        ScreenPosition
        ThresholdInPixels
    end
    
    methods
        function obj = CatchWaterDrop(adapter)
            if ~exist('adapter','var'), return, end
            obj.Adapter = adapter;
            obj.Tracker = obj.tracker();
        end
        function delete(obj)
            if ~isempty(obj.WaterDropID), mgldestroygraphic(obj.WaterDropID); obj.WaterDropID = []; end
            destroy_fixwindow(obj);
        end
        
        function init(obj,p)
            obj.Adapter.init(p);
            obj.Success = false;
            
            if isempty(obj.Position), error('Set the Stone positions first'); end
            obj.WaterDropID = mgladdbitmap('water_icon.bmp',[0 0 0],11);
            obj.CurrentStone = 1;
            obj.FixTime = 0;
            obj.ScreenPosition = obj.Tracker.CalFun.deg2pix(obj.Position);
            obj.ThresholdInPixels = obj.Threshold * obj.Tracker.Screen.PixelsPerDegree;
            create_fixwindow(obj);
        end
        function fini(obj,p)
            obj.Adapter.fini(p);
            destroy_fixwindow(obj);
            if ~isempty(obj.WaterDropID), mgldestroygraphic(obj.WaterDropID); obj.WaterDropID = []; end
        end
        function continue_ = analyze(obj,p)
            obj.Adapter.analyze(p);
            continue_ = true;
            obj.Success = true;
            
            data = obj.Tracker.XYData;
            ndata = size(data,1);
            in = sum((data-repmat(obj.ScreenPosition(obj.CurrentStone,:),ndata,1)).^2,2) < obj.ThresholdInPixels^2;
            if all(in), obj.FixTime = obj.FixTime + obj.Tracker.Screen.FrameLength; else, obj.FixTime = 0; end

            if obj.HoldTime < obj.FixTime
                p.goodmonkey(obj.Reward,'numreward',1,'nonblocking',1);
                obj.CurrentStone = mod(obj.CurrentStone,size(obj.Position,1)) + 1;
                obj.FixTime = 0;
                create_fixwindow(obj);
            end
        end
        function draw(obj,p)
            obj.Adapter.draw(p);
        end
    end
    
    methods (Access = protected)
        function create_fixwindow(obj)
            if isempty(obj.ScreenPosition) || isempty(obj.Threshold), return, end
            destroy_fixwindow(obj);
            obj.FixWindowID = mgladdcircle([0 1 0],obj.ThresholdInPixels*2,10);
            mglsetorigin(obj.WaterDropID,obj.ScreenPosition(obj.CurrentStone,:));
            mglsetorigin(obj.FixWindowID,obj.ScreenPosition(obj.CurrentStone,:));
        end
        function destroy_fixwindow(obj)
            if ~isempty(obj.FixWindowID), mgldestroygraphic(obj.FixWindowID); obj.FixWindowID = []; end
        end
    end
    
    methods
        function o = get_adapter(obj,name)
            if strcmpi(name,mfilename), o = obj; else, o = obj.Adapter.get_adapter(name); end
        end
        function o = tracker(obj)
            o = obj.Adapter.tracker();
        end
        function val = export(obj)
            val = fieldnames(obj);
            for m=1:size(val,1), val{m,2} = obj.(val{m,1}); end
        end
        function import(obj,val)
            fn = fieldnames(obj);
            for m=1:size(val,1), if ismember(val{m,1},fn), obj.(val{m,1}) = val{m,2}; end, end
        end
        function info(obj,s)
            obj.Adapter.info(s);
            s.AdapterList{end+1} = mfilename;
            s.AdapterArgs{end+1} = obj.export();
        end
        function val = fieldnames(obj)
            val = properties(obj); l = length(val); s = false(l,1);
            for m=1:l, s(m) = strcmp(obj.findprop(val{m}).SetAccess,'public'); end
            val = val(s);
        end
    end
end
