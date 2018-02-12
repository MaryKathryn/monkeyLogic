classdef mlscreen_playback < handle
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
    properties
        EyeTracer
        EyeLineTracer
        JoystickCursor
        TouchCursor

        ButtonLabel
        ButtonPressed
        ButtonReleased
        TTL
        Stimulation
    end
    
    methods
        function obj = mlscreen_playback(MLConfig)
            resolution = regexp(MLConfig.Resolution,'(\d+) x (\d+) (\d+) Hz','tokens');
            if MLConfig.ForcedUseOfFallbackScreen
                rect = eval(MLConfig.FallbackScreenRect);
                ss = rect(3:4)-rect(1:2);
            else
                ss = str2double(resolution{1}(1:2));
            end
            obj.SubjectScreenRect = [0 0 ss];
            obj.Xsize = ss(1);
            obj.Ysize = ss(2);
            obj.SubjectScreenAspectRatio = obj.Xsize / obj.Ysize;
            obj.SubjectScreenFullSize = [obj.Xsize obj.Ysize];
            obj.SubjectScreenHalfSize = obj.SubjectScreenFullSize / 2;
            obj.BackgroundColor = MLConfig.SubjectScreenBackground;
            obj.PixelsPerDegree = MLConfig.PixelsPerDegree(1);
            screensize = get(0,'ScreenSize');
            obj.DPI_ratio = mglgetadapterdisplaymode(1) / screensize(3);

            hFig = findobj('tag','mlplayer');
            controlscreenposition = get(hFig,'position');
            replica_pos = get(findobj(hFig,'tag','replica'),'position');
            mdqmex(42,obj.SubjectScreenFullSize,uint8(obj.BackgroundColor*255),Pos2Rect([controlscreenposition(1:2)-1 0 0]+replica_pos),uint8([0.25 0.25 0.25]*255));

            obj.RefreshRate = mglgetrefreshrate(2);
            obj.FrameLength = 1000 / obj.RefreshRate;
            
        end
        function delete(obj), destroy(obj); end
        function destroy(obj)
            mgldestroygraphic([obj.EyeTracer obj.JoystickCursor obj.TouchCursor obj.ButtonLabel obj.ButtonPressed obj.ButtonReleased]);
        end
        
        function create_buttons(obj,MLConfig)
            load('mlimagedata.mat','green_pressed','green_released','stimulation_triggered','ttl_triggered');
            ControlScreenRect = mglgetcontrolscreenrect / obj.DPI_ratio;
            ControlScreenSize = ControlScreenRect(3:4) - ControlScreenRect(1:2);
            fontsize = 12;

            by = ControlScreenSize(2) - 30;
            nbutton = MLConfig.DAQ.nButton;
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
            
            by = by-50;
            nttl = MLConfig.DAQ.nTTL;
            obj.TTL = NaN(2,sum(nttl));
            for m=1:sum(nttl)
                obj.TTL(1,m) = mgladdtext(sprintf('%d',m),12);
                mglsetproperty(obj.TTL(1,m),'halign',2,'fontsize',fontsize);
                obj.TTL(2,m) = mgladdbitmap(mglimresize(ttl_triggered,obj.DPI_ratio),12);

                bx = 40 + (m-1)*40;
                mglsetorigin(obj.TTL(:,m), [bx by-30; bx by] * obj.DPI_ratio);
            end
            
            by = by-50;
            nstimulation = MLConfig.DAQ.nStimulation;
            obj.Stimulation = NaN(2,sum(nstimulation));
            for m=1:sum(nstimulation)
                obj.Stimulation(1,m) = mgladdtext(sprintf('%d',m),12);
                mglsetproperty(obj.Stimulation(1,m),'halign',2,'fontsize',fontsize);
                obj.Stimulation(2,m) = mgladdbitmap(mglimresize(stimulation_triggered,obj.DPI_ratio),12);

                bx = 40 + (m-1)*40;
                mglsetorigin(obj.Stimulation(:,m), [bx by-30; bx by] * obj.DPI_ratio);
            end
            
            mglactivategraphic([obj.EyeTracer obj.JoystickCursor obj.TouchCursor obj.ButtonLabel obj.ButtonPressed obj.ButtonReleased obj.TTL(:)' obj.Stimulation(:)'],false);
        end
        
        function set.EyeTracer(obj,val)
            old_tracer = obj.EyeTracer;
            obj.EyeTracer = val;
            obj.EyeLineTracer = strcmpi('line',mglgettype(obj.EyeTracer)); %#ok<MCSUP>
            mgldestroygraphic(old_tracer);
        end
        function set.JoystickCursor(obj,val)
            old_tracer = obj.JoystickCursor;
            obj.JoystickCursor = val;
            mgldestroygraphic(old_tracer);
        end
        function set.TouchCursor(obj,val)
            old_tracer = obj.TouchCursor;
            obj.TouchCursor = val;
            mgldestroygraphic(old_tracer);
        end
    end
end
