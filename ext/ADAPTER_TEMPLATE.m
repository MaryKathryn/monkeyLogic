classdef ADAPTER_TEMPLATE < mladapter  % Change the class name
    properties
        % Define user variables here. All variables must be initialized.
        
    end
    properties (SetAccess = protected)
        % Variables that users need to read but should not change
        
    end
    properties (Access = protected)
        % Variables that should not be accessible from the outside of the object
        
    end
    
    methods
        function obj = ADAPTER_TEMPLATE(varargin)  % Change the function name
            obj = obj@mladapter(varargin{:});
            
            % User variables can be initialized here, too.
            
        end
        function delete(obj) %#ok<INUSD>
            % Things to do when this adapter is destroyed
        end
        
        function init(obj,p)
            init@mladapter(obj,p);
            
            % Define things to do before a scene starts here
            
        end
        function fini(obj,p)
            fini@mladapter(obj,p);
            
            % Define things to do after a scene finishes here
            
        end
        function continue_ = analyze(obj,p)
            continue_ = analyze@mladapter(obj,p);
            obj.Success = obj.Adapter.Success;
            
            % This function is called every frame during the scene.
            % Do things to detect behavior here.
            %
            % Two variables are important.
            % continue_ determines whether the analysis will be continued to next frame.
            % obj.Success indicates whether the behavior is detected.
            %
            % See WaitThenHold.m for an example.
            
        end
        function draw(obj,p)
            draw@mladapter(obj,p);
            
            % This function is called every frame during the scene.
            % Update graphics related to this adapter here.
            
        end
    end
end
