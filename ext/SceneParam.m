classdef SceneParam < handle
    properties
        Visual
        Movie
        Sound
        STM
        TTL
        
        Time
        Position
        BackgroundColor
        MovieCurrentPosition
        MovieLooping
        
        AdapterList
        AdapterArgs
    end
    properties (Hidden = true)
        Adapter
    end
    
    methods
        function o = copy(obj)
            fn = fieldnames(obj);
            for m=1:length(fn), o.(fn{m}) = obj.(fn{m}); end
        end
    end
end
