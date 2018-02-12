classdef ClosedLoopStimulator < mladapter
    properties
        Channel
        Waveform
        Frequency
    end
    properties (SetAccess = protected)
    end
    properties (Access = protected)
        AO
        Output
        Replaying
    end
    
    methods
        function obj = ClosedLoopStimulator(varargin)
            obj = obj@mladapter(varargin{:});
            obj.Replaying = 2==obj.Tracker.DataSource;
        end
        
        function set.Channel(obj,val)
            if ~isscalar(val), error('Channel must be a scalar.'); end
            non_stim = ~ismember(val,obj.Tracker.DAQ.stimulation_available);
            if any(non_stim), error('Stimulation #%d is not assigned.',val(find(non_stim,1))); end
            obj.Channel = val;
        end
        function set.Waveform(obj,val)
            obj.Waveform = val(:);
        end
        function set.Frequency(obj,val)
            if ~isscalar(val), error('Frequency must be a scalar.'); end
            obj.Frequency = val;
        end
        
        function init(obj,p)
            init@mladapter(obj,p);
            if ~obj.Replaying
                obj.AO = p.DAQ.Stimulation{obj.Channel};
                chan = strcmp(obj.AO.Channel.ChannelName,sprintf('Stimulation%d',obj.Channel));
                nchan = length(obj.AO.Channel);
                obj.AO.SampleRate = obj.Frequency;
                obj.AO.RepeatOutput = Inf;
                obj.AO.RegenerationMode = 1;
                obj.Output = zeros(size(obj.Waveform,1),nchan);
                obj.Output(:,chan) = obj.Waveform;
                putdata(obj.AO,obj.Output);
                start(obj.AO);
            end
        end
        function fini(obj,p)
            fini@mladapter(obj,p);
            mglactivategraphic(obj.Tracker.Screen.Stimulation(:,obj.Channel),false);
            if ~obj.Replaying, stop(obj.AO,15); end
            obj.Success = false;
        end
        function continue_ = analyze(obj,p)
            continue_ = analyze@mladapter(obj,p);
            if obj.Replaying, obj.Success = obj.Adapter.Success; return, end
            if obj.Adapter.Success
                if ~obj.AO.Sending, trigger(obj.AO); obj.Success = true; end
            else
                if obj.AO.Sending, stop(obj.AO,41); obj.Success = false; end
            end
        end
        function draw(obj,p)
            draw@mladapter(obj,p);
            if obj.Success
                mglactivategraphic(obj.Tracker.Screen.Stimulation(:,obj.Channel),true);
            else
                mglactivategraphic(obj.Tracker.Screen.Stimulation(:,obj.Channel),false);
            end
        end
    end
end
