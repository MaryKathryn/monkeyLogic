classdef mlscreen < handle
    properties (SetAccess = protected)
        SubjectScreenRect
        Xsize
        Ysize
        SubjectScreenAspectRatio
        SubjectScreenFullSize
        SubjectScreenHalfSize
        DPI_ratio
        RefreshRate
        FrameLength
        
        BackgroundColor
        PixelsPerDegree
    end
    properties (Hidden)
        PhotodiodeWhite
        PhotodiodeBlack
        EyeTracer
        EyeLineTracer
        JoystickCursor
        TouchCursor
        DashBoard
        ButtonLabel
        ButtonPressed
        ButtonReleased
        EscapeRequested
        TTL
        Reward
        RewardCount
        RewardDuration
        Stimulation
    end
    
    methods
        function obj = mlscreen(MLConfig)
            if exist('MLConfig','var') && isa(MLConfig,'mlconfig')
                create(obj,MLConfig);
            else
                obj.SubjectScreenHalfSize = NaN(1,2);
            end
        end
        function delete(obj), destroy(obj); end
        function destroy(obj)
            try
                if ~isempty(obj.SubjectScreenRect)
                    mgldestroycontrolscreen;
                    mgldestroysubjectscreen;
                    mgldestroysound(0);
                end
            catch
                % do nothing
            end
        end
        
        function set.EyeTracer(obj,val)
            old_tracer = obj.EyeTracer;
            obj.EyeTracer = val;
            obj.EyeLineTracer = strcmpi('line',mglgettype(obj.EyeTracer)); %#ok<MCSUP>
            mgldestroygraphic(old_tracer);
        end
        function create(obj,MLConfig)
            hFig = findobj('tag','mlplayer');
            if ~isempty(hFig), close(hFig); pause(0.3); drawnow; end
            mglcreatesubjectscreen(MLConfig.SubjectScreenDevice,MLConfig.SubjectScreenBackground,MLConfig.FallbackScreenRect,MLConfig.ForcedUseOfFallbackScreen);

            info = mglgetscreeninfo(1);
            obj.SubjectScreenRect = info.Rect;
            obj.Xsize = info.Rect(3) - info.Rect(1);
            obj.Ysize = info.Rect(4) - info.Rect(2);
            obj.SubjectScreenAspectRatio = obj.Xsize / obj.Ysize;
            obj.SubjectScreenFullSize = [obj.Xsize obj.Ysize];
            obj.SubjectScreenHalfSize = obj.SubjectScreenFullSize / 2;
            screensize = get(0,'ScreenSize');
            obj.DPI_ratio = mglgetadapterdisplaymode(1) / screensize(3);
            obj.RefreshRate = mglgetrefreshrate();
            obj.FrameLength = 1000 / obj.RefreshRate;
            
            obj.BackgroundColor = MLConfig.SubjectScreenBackground;
            obj.PixelsPerDegree = MLConfig.PixelsPerDegree(1);
        end
        
        function create_tracers(obj,MLConfig)
            DAQ = MLConfig.DAQ;
            load('mlimagedata.mat','green_pressed','green_released','reward_image','stimulation_triggered','ttl_triggered');
            ControlScreenRect = mglgetcontrolscreenrect / obj.DPI_ratio;
            ControlScreenSize = ControlScreenRect(3:4) - ControlScreenRect(1:2);
            fontsize = 12;

            switch MLConfig.EyeTracerShape
                case 'Line', obj.EyeTracer = mgladdline(MLConfig.EyeTracerColor,50,1,10);
                otherwise, obj.EyeTracer = load_cursor('',MLConfig.EyeTracerShape,MLConfig.EyeTracerColor,MLConfig.EyeTracerSize,10);
            end
            obj.JoystickCursor = [load_cursor(MLConfig.JoystickCursorImage,MLConfig.JoystickCursorShape,MLConfig.JoystickCursorColor,MLConfig.JoystickCursorSize,9) ...
                load_cursor(MLConfig.JoystickCursorImage,MLConfig.JoystickCursorShape,MLConfig.JoystickCursorColor,MLConfig.JoystickCursorSize,10)];

            obj.TouchCursor = load_cursor(MLConfig.TouchCursorImage,MLConfig.TouchCursorShape,MLConfig.TouchCursorColor,MLConfig.TouchCursorSize,10);

            by = ControlScreenSize(2) - 30;
            nbutton = DAQ.nButton;
            obj.ButtonLabel = NaN(1,sum(nbutton));
            obj.ButtonPressed = NaN(1,sum(nbutton));
            obj.ButtonReleased = NaN(1,sum(nbutton));
            for m=1:sum(nbutton)
                obj.ButtonLabel(m) = mgladdtext(sprintf('%d',m),12);
                mglsetproperty(obj.ButtonLabel(m),'halign',2,'fontsize',fontsize);
                obj.ButtonPressed(m) = mgladdbitmap(mglimresize(green_pressed,obj.DPI_ratio),12);
                obj.ButtonReleased(m) = mgladdbitmap(mglimresize(green_released,obj.DPI_ratio),12);
                bx = 40 + (m-1)*40;
                mglsetorigin([obj.ButtonLabel(m) obj.ButtonPressed(m) obj.ButtonReleased(m)], [bx by-30; bx by; bx by] * obj.DPI_ratio);
            end
            
            mglactivategraphic([obj.EyeTracer obj.JoystickCursor obj.TouchCursor obj.ButtonLabel obj.ButtonPressed obj.ButtonReleased],false);

            if 1 < MLConfig.PhotoDiodeTrigger
                sz = MLConfig.PhotoDiodeTriggerSize;
                imdata = cat(3,ones(sz,sz),zeros(sz, sz, 3));
                obj.PhotodiodeBlack = mgladdbitmap(imdata,9);
                imdata = ones(sz, sz, 4);
                obj.PhotodiodeWhite = mgladdbitmap(imdata,9);
                half_sz = sz / 2;
                switch MLConfig.PhotoDiodeTrigger
                    case 2  % upper left
                        xori = half_sz;
                        yori = half_sz;
                    case 3  % upper right
                        xori = obj.Xsize - half_sz;
                        yori = half_sz;
                    case 4  % lower right
                        xori = obj.Xsize - half_sz;
                        yori = obj.Ysize - half_sz;
                    case 5  % lower left
                        xori = half_sz;
                        yori = obj.Ysize - half_sz;
                end
                mglsetorigin([obj.PhotodiodeBlack obj.PhotodiodeWhite],[xori yori]);
                mglactivategraphic([obj.PhotodiodeBlack obj.PhotodiodeWhite],[true false]);
            end
            
            obj.DashBoard = [mgladdtext('',12) mgladdtext('',12) mgladdtext('',12) mgladdtext('',12) mgladdtext('',12) mgladdtext('',12)];
            mglsetproperty(obj.DashBoard,'origin',[20 20; 20 40; 20 60; 20 80; 20 100; 20 120] * obj.DPI_ratio,'fontsize',fontsize);

            by = ControlScreenSize(2) - 30;
            obj.EscapeRequested = mgladdtext('Escape',12);
            mglsetorigin(obj.EscapeRequested, [ControlScreenSize(1)-30 by] * obj.DPI_ratio);
            mglsetproperty(obj.EscapeRequested,'halign',3,'valign',2,'fontsize',fontsize);

            by = by-50;
            nttl = DAQ.nTTL;
            obj.TTL = NaN(2,sum(nttl));
            for m=1:sum(nttl)
                obj.TTL(1,m) = mgladdtext(sprintf('%d',m),12);
                mglsetproperty(obj.TTL(1,m),'halign',2,'fontsize',fontsize);
                obj.TTL(2,m) = mgladdbitmap(mglimresize(ttl_triggered,obj.DPI_ratio),12);

                bx = 40 + (m-1)*40;
                mglsetorigin(obj.TTL(:,m), [bx by-30; bx by] * obj.DPI_ratio);
            end
            
            obj.Reward = mgladdbitmap(mglimresize(reward_image,obj.DPI_ratio),12);
            obj.RewardCount = mgladdtext('0',12);
            obj.RewardDuration = mgladdtext('0',12);
            mglsetproperty(obj.RewardCount,'halign',2,'fontsize',fontsize);
            mglsetproperty(obj.RewardDuration,'halign',3,'fontsize',fontsize);
            mglsetorigin([obj.Reward obj.RewardCount obj.RewardDuration], [ControlScreenSize(1)-41 by; ControlScreenSize(1)-41 by-30; ControlScreenSize(1)-70 by-5] * obj.DPI_ratio);

            by = by-50;
            nstimulation = DAQ.nStimulation;
            obj.Stimulation = NaN(2,sum(nstimulation));
            for m=1:sum(nstimulation)
                obj.Stimulation(1,m) = mgladdtext(sprintf('%d',m),12);
                mglsetproperty(obj.Stimulation(1,m),'halign',2,'fontsize',fontsize);
                obj.Stimulation(2,m) = mgladdbitmap(mglimresize(stimulation_triggered,obj.DPI_ratio),12);

                bx = 40 + (m-1)*40;
                mglsetorigin(obj.Stimulation(:,m), [bx by-30; bx by] * obj.DPI_ratio);
            end
            
            mglactivategraphic([obj.DashBoard obj.EscapeRequested obj.TTL(:)' obj.Reward obj.RewardCount obj.RewardDuration obj.Stimulation(:)'],false);
        end
    end
end
