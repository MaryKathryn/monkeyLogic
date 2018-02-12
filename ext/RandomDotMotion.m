classdef RandomDotMotion < mladapter
    properties
        Position   % [x,y] in degrees
        Radius     % aperture radius in degrees
        Coherence  % 0 - 100
        Direction  % degree
        Speed      % degrees per second
        
        NumDot
        DotSize    % in degrees
        DotColor
        Interleaf  % number of alternating frames
    end
    properties (Access = protected)
        DotID
        DotPosition
        
        ScrPosition
        ScrRadius
        ScrDisplacement
        ScrDirection
        ScrDotSize
        NumMovingDot
        SymmetryMat
    end
    
    methods
        function obj = RandomDotMotion(varargin)
            obj = obj@mladapter(varargin{:});
            if 0==nargin, return, end

            obj.Position = [0 0];
            obj.Radius = 5;
            obj.Coherence = 100;
            obj.Direction = 0;
            obj.Speed = 5;

            obj.NumDot = 100;
            obj.DotSize = 0.15;
            obj.DotColor = [1 1 1];
            obj.Interleaf = 3;
        end
        function delete(obj)
            destroy_dots(obj);
        end
        
        function set.Position(obj,pos)
            if 2~=numel(pos), error('Origin must be a 1-by-2 vector'); end
            pos = pos(:)';
            if ~isempty(obj.Position) && all(pos==obj.Position), return, end
            obj.Position = pos;
            obj.ScrPosition = obj.Tracker.CalFun.deg2pix(pos); %#ok<*MCSUP>
        end
        function set.Radius(obj,radius)
            if ~isscalar(radius), error('Radius must be a scalar'); end
            if radius<=0, error('Radius must be a positive number'); end
            if ~isempty(obj.Radius) && radius==obj.Radius, return, end
            obj.Radius = radius;
            obj.ScrRadius = obj.Tracker.Screen.PixelsPerDegree * radius;
            init_position(obj);
        end
        function set.Coherence(obj,coherence)
            if ~isscalar(coherence), error('Coherence must be a scalar'); end
            if coherence<0 || 100<coherence, error('Coherence must be 0 to 100'); end
            if ~isempty(obj.Coherence) && coherence==obj.Coherence, return, end
            obj.Coherence = coherence;
            init_displacement(obj);
        end
        function set.Direction(obj,direction)
            if ~isscalar(direction), error('Direction must be a scalar'); end
            if ~isempty(obj.Direction) && direction==obj.Direction, return, end
            obj.Direction = direction;
            obj.ScrDirection = -direction;
            init_displacement(obj);
            init_matrix(obj);
        end
        function set.Speed(obj,speed)
            if ~isscalar(speed), error('Speed must be a scalar'); end
            if speed<0, error('Speed must be a positive number'); end
            if ~isempty(obj.Speed) && speed==obj.Speed, return, end
            obj.Speed = speed;
            init_displacement(obj);
        end
        
        function set.NumDot(obj,ndot)
            if ~isscalar(ndot), error('NumDot must be a scalar'); end
            if ndot<=0, error('NumDot must be a positive number'); end
            if ~isempty(obj.NumDot) && ndot==obj.NumDot, return, end
            obj.NumDot = ndot;
            create_dots(obj);
            init_position(obj);
            init_displacement(obj);
        end
        function set.DotSize(obj,dotsize)
            if ~isscalar(dotsize), error('DotSize must be a scalar'); end
            if dotsize<=0, error('DotSize must be a positive number'); end
            if ~isempty(obj.DotSize) && dotsize==obj.DotSize, return, end
            obj.DotSize = dotsize;
            obj.ScrDotSize = obj.Tracker.Screen.PixelsPerDegree * dotsize;
            create_dots(obj);
        end
        function set.DotColor(obj,color)
            if 3~=numel(color), error('DotColor must be a 1-by-3 vector'); end
            color = color(:)';
            if ~isempty(obj.DotColor) && all(color==obj.DotColor), return, end
            obj.DotColor = color;
            create_dots(obj);
        end
        function set.Interleaf(obj,interleaf)
            if ~isscalar(interleaf), error('Interleaf must be a scalar'); end
            if interleaf<=0, error('Interleaf must be a positive number'); end
            if ~isempty(obj.Interleaf) && interleaf==obj.Interleaf, return, end
            obj.Interleaf = interleaf;
            init_position(obj);
            init_displacement(obj);
        end
        
        function init(obj,p)
            init@mladapter(obj,p);
            mglactivategraphic(obj.DotID,true);
        end
        function fini(obj,p)
            fini@mladapter(obj,p);
            mglactivategraphic(obj.DotID,false);
        end
        function continue_ = analyze(obj,p)
            continue_ = analyze@mladapter(obj,p);
            obj.Success = obj.Adapter.Success;
        end
        function draw(obj,p)
            draw@mladapter(obj,p);
            
            % draw dots for the current frame
            interleaf = mod(p.scene_frame(),obj.Interleaf) + 1;
            mglsetorigin(obj.DotID,obj.DotPosition{interleaf}+repmat(obj.ScrPosition,obj.NumDot,1));

            % pick dots to move randomly
            random_order = randperm(obj.NumDot);
            moving_dots = random_order(1:obj.NumMovingDot);
            random_dots = random_order(obj.NumMovingDot+1:obj.NumDot);
            
            % move them to new position
            new_position = obj.DotPosition{interleaf}(moving_dots,:) + obj.ScrDisplacement;
            escaping_dots = obj.ScrRadius*obj.ScrRadius < sum(new_position.^2,2);
            new_position(escaping_dots,:) = obj.DotPosition{interleaf}(moving_dots(escaping_dots),:) * obj.SymmetryMat;
            obj.DotPosition{interleaf}(moving_dots,:) = new_position;
 
            % move the rest of the dots to random position
            n = length(random_dots);
            r = (1-rand(n,1).^2) * obj.ScrRadius;
            t = rand(n,1) * 360;
            obj.DotPosition{interleaf}(random_dots,:) = [r.*cosd(t) r.*sind(t)];
        end
    end
    
    methods (Access = protected)
        function create_dots(obj)
            if isempty(obj.NumDot) || isempty(obj.ScrDotSize) || isempty(obj.DotColor), return, end
            destroy_dots(obj);
            obj.DotID = zeros(1,obj.NumDot);
            for m=1:obj.NumDot, obj.DotID(m) = mgladdbox([obj.DotColor; obj.DotColor],obj.ScrDotSize); end
            mglactivategraphic(obj.DotID,false);
        end
        function destroy_dots(obj)
            if ~isempty(obj.DotID), mgldestroygraphic(obj.DotID); end
        end
        function init_position(obj)
            if isempty(obj.NumDot) || isempty(obj.Interleaf) || isempty(obj.ScrRadius), return, end
            obj.DotPosition = cell(1,obj.Interleaf);
            for m=1:obj.Interleaf
                r = (1-rand(obj.NumDot,1).^2) * obj.ScrRadius;
                t = rand(obj.NumDot,1) * 360;
                obj.DotPosition{m} = [r.*cosd(t) r.*sind(t)];
            end
        end
        function init_displacement(obj)
            if isempty(obj.NumDot) || isempty(obj.Coherence) || isempty(obj.ScrDirection) || isempty(obj.Speed) || isempty(obj.Interleaf), return, end
            obj.NumMovingDot = round(obj.NumDot * obj.Coherence / 100);
            d = obj.Tracker.Screen.PixelsPerDegree * obj.Speed * obj.Interleaf / obj.Tracker.Screen.RefreshRate;
            obj.ScrDisplacement = repmat([d*cosd(obj.ScrDirection) d*sind(obj.ScrDirection)],obj.NumMovingDot,1);
        end
        function init_matrix(obj)
            switch obj.ScrDirection
                case {0,180}
                    obj.SymmetryMat = [-1 0; 0 1];
                case {90,270}
                    obj.SymmetryMat = [1 0; 0 -1];
                otherwise
                    a = -1 / tand(obj.ScrDirection);
                    b = 1 + a*a;
                    obj.SymmetryMat = [(2-b)/b 2*a/b; 2*a/b (b-2)/b];
            end
        end
    end
end
