classdef mldaq_playback < handle
    properties
        Eye
        Joystick
        Button
        General
        Mouse
        MouseButton
    end
    properties (SetAccess = protected)  % output
        Stimulation
        TTL

        nButton
        nGeneral
        nStimulation
        nTTL
    end
    properties (SetAccess = protected, Hidden)
        Map
        ButtonsAvailable
        GeneralAvailble
    end
    
    methods
        function obj = mldaq_playback(AnalogData)
            obj.Map.Eye = ~isempty(AnalogData.Eye);
            obj.Map.Joystick = ~isempty(AnalogData.Joystick);
            obj.Map.Mouse = ~isempty(AnalogData.Mouse);

            label = fieldnames(AnalogData.General);
            obj.nGeneral = length(label);
            for m=1:obj.nGeneral
                if ~isempty(AnalogData.General.(label{m})), obj.GeneralAvailble(end+1) = m; end
            end
            
            if isfield(AnalogData,'Button')
                label = fieldnames(AnalogData.Button);
                obj.nButton = length(label);
                obj.Map.Button = zeros(obj.nButton,2);
                for m=1:obj.nButton
                    obj.Map.Button(m) = ~isempty(AnalogData.Button.(label{m}));
                    if obj.Map.Button(m), obj.ButtonsAvailable(end+1) = m; end
                end
            end
            
            obj.nStimulation = 4;
            obj.nTTL = 10;
            
            ao = analogoutput_playback;
            for m=1:obj.nStimulation
                addchannel(ao,m-1,sprintf('Stimulation%d',m));
            end
            obj.Stimulation = cell(1,obj.nStimulation);
            for m=1:obj.nStimulation
                if isempty(obj.Stimulation{m}), obj.Stimulation{m} = ao; end
            end
            
            dio = digitalio_playback;
            for m=1:obj.nTTL
                addline(dio,m-1,0,'Out',sprintf('TTL%d',m));
            end
            obj.TTL = cell(1,obj.nTTL);
            for m=1:obj.nTTL
                if isempty(obj.TTL{m}), obj.TTL{m} = dio; end
            end
        end
        
        function obj = create(obj,~,~), end
        function eventmarker(~,~), end
        function goodmonkey(~,~,varargin), end

        function val = eye_present(obj), val = obj.Map.Eye; end
        function val = joystick_present(obj), val = obj.Map.Joystick; end
        function val = button_present(obj), val = any(obj.Map.Button(:,1)); end
        function val = mouse_present(obj), val = obj.Map.Mouse; end
        function val = usbjoystick_present(~), val = false; end
        function val = buttons_available(obj), val = obj.ButtonsAvailable; end
        function val = general_available(obj), val = obj.GeneralAvailble; end
        function val = ttl_available(obj), val = 1:obj.nTTL; end
        function val = stimulation_available(obj), val = 1:obj.nStimulation; end
%         function val = reward_present(~), val = false; end
%         function val = strobe_present(~), val = false; end
        function button_threshold(~,~,~), end
%         function val = get_device(~,~), val = []; end
        
%         function start(~), end
%         function stop(~), end
%         function flushdata(~), end
%         function flushmarker(~), end
%         function frontmarker(~), end
%         function backmarker(~), end
%         function val = isrunning(~), val = false; end
%         function val = MinSamplesAvailable(~), val = 0; end
%         function val = MinSamplesAcquired(~), val = 0; end
%         function getsample(~), end
%         function getdata(~), end
%         function peekdata(~,~), end
%         function peekfront(~), end
%         function getback(~), end
    end        
end
