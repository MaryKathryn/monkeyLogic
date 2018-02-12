classdef LBC_ImageChanger < mladapter
    properties
        ImageList
    end
    properties (SetAccess = protected)
        ElapsedFrame
        CurrentImageName
    end
    properties (Access = protected)
        NumImage
        ImageID
        ImageSchedule
        CurrentImageNum
        PrevImageNum
    end
    
    methods
        function obj = LBC_ImageChanger(varargin)
            obj = obj@mladapter(varargin{:});
        end
        function delete(obj)
            mgldestroygraphic(obj.ImageID);
        end
        function init(obj,p)
            init@mladapter(obj,p);
            mgldestroygraphic(obj.ImageID); %#ok<*MCSUP>
            obj.NumImage = size(obj.ImageList,1);
            obj.ImageID = NaN(1,obj.NumImage);
            for m=1:obj.NumImage
                if isempty(obj.ImageList{m,1}), continue, end
                obj.ImageID(m) = mgladdbitmap(mglimread(obj.ImageList{m,1}));
            end
            obj.ImageSchedule = ceil(cumsum([obj.ImageList{:,3}]) / obj.Tracker.Screen.FrameLength);
            mglactivategraphic(obj.ImageID,false);
            obj.ElapsedFrame = 0;
            obj.CurrentImageNum = 0;
            obj.PrevImageNum = 0;
        end
        function fini(obj,p)
            fini@mladapter(obj,p);
            mglactivategraphic(obj.ImageID,false);
        end
        function continue_ = analyze(obj,p)
            analyze@mladapter(obj,p);
            if obj.Adapter.Success, obj.ElapsedFrame = obj.ElapsedFrame + 1; end
            if 0 < obj.ElapsedFrame, obj.CurrentImageNum = find(obj.ElapsedFrame<=obj.ImageSchedule,1); end
            obj.Success = isempty(obj.CurrentImageNum);
            continue_ = ~obj.Success;
        end
        function draw(obj,p)
            draw@mladapter(obj,p);
            if isempty(obj.CurrentImageNum)  % This means that we presented all the images, so turn them off.
                mglactivategraphic(obj.ImageID,false);
            elseif obj.PrevImageNum ~= obj.CurrentImageNum
                obj.PrevImageNum = obj.CurrentImageNum;
                mglactivategraphic(obj.ImageID,false);
                
                selected_id = obj.ImageID(obj.CurrentImageNum);
                if ~isnan(selected_id)
                    selected_pos = obj.ImageList{obj.CurrentImageNum,2};
                    mglactivategraphic(selected_id,true);
                    mglsetorigin(selected_id,obj.Tracker.CalFun.deg2pix(selected_pos));
                end
                selected_marker = obj.ImageList{obj.CurrentImageNum,4};
                p.eventmarker(selected_marker);
                obj.CurrentImageName = obj.ImageList{obj.CurrentImageNum,1};
            end
        end
    end
end
