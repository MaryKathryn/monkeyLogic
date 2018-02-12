classdef ButtonTracker < Tracker
    properties (SetAccess = protected)
        ClickData
        LastSamplePosition

        Invert
        Status
        nButton
        ButtonsAvailable
    end
    properties (Access = protected)
        InvertedButtons
    end
    
    methods
        function obj = ButtonTracker(varargin)  % MLConfig, TaskObject, CalFun, datasource
            obj = obj@Tracker(varargin{:});
            if 4~=nargin, return, end
            
            MLConfig = varargin{1};
            if 0==obj.DataSource && ~MLConfig.DAQ.button_present, error('No button input is defined!!!'); end

            obj.Signal = 'Button';
            obj.nButton = sum(obj.DAQ.nButton);
            obj.ClickData = cell(1,obj.nButton);
            obj.Invert = false(1,obj.nButton);
            obj.Status = false(1,obj.nButton);
            if 1==obj.DataSource, obj.ButtonsAvailable = 1:MLConfig.DAQ.nButton; else, obj.ButtonsAvailable = obj.DAQ.buttons_available; end
        end
        
        function invert(obj,button)
            not_button = find(~ismember(button,obj.ButtonsAvailable),1);
            if ~isempty(not_button), error('Button #%d doesn''t exist',not_button(1)); end
            obj.Invert(button) = ~obj.Invert(button);
            rebuild_button(obj,button);
        end
        function threshold(obj,button,val)
            not_button = find(~ismember(button,obj.ButtonsAvailable),1);
            if ~isempty(not_button), error('Button #%d doesn''t exist',not_button(1)); end
            obj.DAQ.button_threshold(button,val);
        end
        function label(obj,button,str)
            not_button = find(~ismember(button,obj.ButtonsAvailable),1);
            if ~isempty(not_button), error('Button #%d doesn''t exist',not_button(1)); end
            for m=button(:)'
                origin = mglgetproperty(obj.Screen.ButtonLabel(m),'origin');
                mgldestroygraphic(obj.Screen.ButtonLabel(m));
                obj.Screen.ButtonLabel(m) = mgladdtext(str,12);
                mglsetproperty(obj.Screen.ButtonLabel(m),'origin',origin,'halign',2,'fontsize',12);
            end
        end

        function tracker_init(obj,~)
            mglactivategraphic(obj.Screen.ButtonLabel(obj.ButtonsAvailable),true);
            obj.InvertedButtons = find(obj.Invert);
        end
        function tracker_fini(obj,~)
            mglactivategraphic([obj.Screen.ButtonLabel obj.Screen.ButtonPressed obj.Screen.ButtonReleased],false);
        end
        function acquire(obj,p)
            switch obj.DataSource
                case 0, data = p.DAQ.Button; for m=obj.InvertedButtons, data{m} = ~data{m}; end, obj.LastSamplePosition = p.DAQ.LastSamplePosition;
                case 1, p.DAQ.simulated_input(0); data = num2cell(p.DAQ.SimulatedButton); obj.LastSamplePosition = floor(p.trialtime()-1) * ones(1,obj.nButton);
                case 2, data = p.DAQ.Button; obj.LastSamplePosition = (floor(p.trialtime()-size(data,1))) * ones(1,obj.nButton);
                otherwise, error('Unknown data source!!!');
            end
            if ~isempty(data)
                obj.Success = true;
                obj.ClickData = data;
                for m=obj.ButtonsAvailable
                    if isempty(data{m}), continue, end
                    obj.Status(m) = data{m}(end);
                end
            else
                obj.Success = false;
            end
            
            mglactivategraphic(obj.Screen.ButtonPressed(obj.ButtonsAvailable),obj.Status(obj.ButtonsAvailable));
            mglactivategraphic(obj.Screen.ButtonReleased(obj.ButtonsAvailable),~obj.Status(obj.ButtonsAvailable));
        end
    end
    
    methods (Access = protected)
        function rebuild_button(obj,button)
            for m=button(:)'
                origin = mglgetproperty(obj.Screen.ButtonPressed(m),'origin');
                mgldestroygraphic([obj.Screen.ButtonPressed(m) obj.Screen.ButtonReleased(m)]);
                if obj.Invert(m)
                    load('mlimagedata.mat','red_pressed','red_released');
                    obj.Screen.ButtonPressed(m) = mgladdbitmap(mglimresize(red_pressed,obj.Screen.DPI_ratio),12);
                    obj.Screen.ButtonReleased(m) = mgladdbitmap(mglimresize(red_released,obj.Screen.DPI_ratio),12);
                else
                    load('mlimagedata.mat','green_pressed','green_released');
                    obj.Screen.ButtonPressed(m) = mgladdbitmap(mglimresize(green_pressed,obj.Screen.DPI_ratio),12);
                    obj.Screen.ButtonReleased(m) = mgladdbitmap(mglimresize(green_released,obj.Screen.DPI_ratio),12);
                end
                mglsetorigin([obj.Screen.ButtonPressed(m) obj.Screen.ButtonReleased(m)],[origin; origin]);
            end
        end
    end
end
