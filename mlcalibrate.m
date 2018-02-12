classdef mlcalibrate < handle
%MLCALIBRATE provides following calibration functions
% sig2deg(voltage,offset): convert voltages (n-by-2) to degrees (the center is [0 0])
% deg2pix(deg)           : convert degrees to pixels (the left-top corner is [0 0])
% sig2pix(voltage,offset): concatenation of sig2deg and deg2pix
% pix2deg(pix)           : convert pixels to degrees
%
% subject2deg(xy), subject2pix(xy): convert window coordinates on the subject screen
%                                   to degrees and pixels, respectively
% control2deg(xy), control2pix(xy): convert window coordinates on the control screen
%                                   to degrees and pixels, respectively. Require to call
%                                   update_control_screen_geometry() whenever the zoom level
%                                   of the control screen changes.
%
% translate(offset): move the origin of the transformation matrix
% rotate(theta): rotate the transformation space.
%
%   Mar 12, 2017    Written by Jaewon Hwang (jaewon.hwang@nih.gov, jaewon.hwang@hotmail.com)

    properties (SetAccess = protected)
        sig2deg
    end
    properties (SetAccess = protected, Hidden = true)
        tform           % Transform Matrix: cell(1,3)
        calmethod       % Calibration Method: 1-3
        ppd             % PixelsPerDegree
        ssrc            % SubjectScreenRect
        ssfull          % SubjectScreenFullSize
        sshalf          % SubjectScreenHalfSize
        aspectratio     % SubjectScreenAspectRatio
        cspos           % ControlScreenPosition
        c2s_ratio       % Control2SubjectRatio
        rotation_t      % transpose of rotation matrix
        rotation_rev_t
    end

    methods (Access = protected)
        function xy = raw_signal(obj,xy,offset)  % Calibration method 1: Raw signal
            n = size(xy,1);
            xy = (xy - repmat(obj.tform{1}.offset + offset,n,1)) * obj.rotation_t;
        end
        function xy = origin_gain(obj,xy,offset)  % Calibration method 2: Origin-Gain
            n = size(xy,1);
            xy = (xy - repmat(obj.tform{2}.origin + offset*obj.tform{2}.rotation_rev_t./obj.tform{2}.gain,n,1)) .* repmat(obj.tform{2}.gain,n,1) * (obj.tform{2}.rotation_t * obj.rotation_t);
        end
        function xy = spatial_transform(obj,xy,offset)  % Calibration method 3: 2-D Spatial Transformation
            n = size(xy,1);
            xy = (obj.tform{3}.forward_fcn(obj.tform{3},xy) - repmat(offset,n,1)) * obj.rotation_t;
        end
    end        
    
    methods
        function obj = mlcalibrate(sig_type,MLConfig)
            switch sig_type
                case {1,'eye'}
                    obj.tform = MLConfig.EyeTransform;
                    obj.calmethod = MLConfig.EyeCalibration;
                case {2,'joy'}
                    obj.tform = MLConfig.JoystickTransform;
                    obj.calmethod = MLConfig.JoystickCalibration;
            end
            if ~isfield(obj.tform{1},'offset'), obj.tform{1}.offset = [0 0]; end
            if ~isfield(obj.tform{2},'rotation'), obj.tform{2}.rotation = 0; end
            if ~isfield(obj.tform{2},'rotation_t'), obj.tform{2}.rotation_t = eye(2); end
            if ~isfield(obj.tform{2},'rotation_rev_t'), obj.tform{2}.rotation_rev_t = eye(2); end
            obj.tform{3} = projective_transform('convert',obj.tform{3});

            obj.ppd = MLConfig.PixelsPerDegree;
            obj.ssrc = MLConfig.Screen.SubjectScreenRect;
            obj.ssfull = MLConfig.Screen.SubjectScreenFullSize;
            obj.sshalf = MLConfig.Screen.SubjectScreenHalfSize;
            obj.aspectratio = MLConfig.Screen.SubjectScreenAspectRatio;
            obj.update_controlscreen_geometry();
            rotate(obj,0);

            switch obj.calmethod
                case 1, obj.sig2deg = @obj.raw_signal;
                case 2, obj.sig2deg = @obj.origin_gain;
                case 3, obj.sig2deg = @obj.spatial_transform;
            end
        end
        function rc = update_controlscreen_geometry(obj)
            if ~mglcontrolscreenexists(), rc = []; return, end
            info = mglgetscreeninfo(2);
            rc = info.Rect;
            obj.cspos = rc;
            sz = rc(3:4) - rc(1:2);
            zoom = info.Zoom;
            if sz(1) < obj.aspectratio * sz(2)
                obj.cspos(3) = sz(1) * zoom;
                obj.cspos(4) = sz(1) * zoom / obj.aspectratio;
            else
                obj.cspos(3) = sz(2) * zoom * obj.aspectratio;
                obj.cspos(4) = sz(2) * zoom;
            end
            obj.cspos(1:2) = obj.cspos(1:2) + (sz-obj.cspos(3:4)) / 2;
            obj.c2s_ratio = obj.ssfull ./ obj.cspos(3:4);
        end            
        
        function xy = deg2pix(obj,xy)
            n = size(xy,1);
            xy = xy .* repmat(obj.ppd,n,1) + repmat(obj.sshalf,n,1);
        end
        function xy = sig2pix(obj,xy,offset)
            xy = obj.deg2pix(obj.sig2deg(xy,offset));
        end
        function xy = pix2deg(obj,xy)
            n = size(xy,1);
            xy = (xy - repmat(obj.sshalf,n,1)) ./ repmat(obj.ppd,n,1);
        end
        function xy = subject2deg(obj,xy)
            n = size(xy,1);
            xy = (xy - repmat(obj.ssrc(1:2) + obj.sshalf,n,1)) ./ repmat(obj.ppd,n,1);
        end
        function xy = subject2pix(obj,xy)
            n = size(xy,1);
            xy = xy - repmat(obj.ssrc(1:2),n,1);
        end
        function xy = control2deg(obj,xy)
            n = size(xy,1);
            xy = (xy - repmat(obj.cspos(1:2) + obj.sshalf ./ obj.c2s_ratio,n,1)) .* repmat(obj.c2s_ratio ./ obj.ppd,n,1);
        end
        function xy = control2pix(obj,xy)
            n = size(xy,1);
            xy = (xy - repmat(obj.cspos(1:2),n,1)) .* repmat(obj.c2s_ratio,n,1);
        end
        
        function tform = translate(obj,offset)
            if any(offset)
                switch obj.calmethod
                    case 1
                        obj.tform{1}.offset = obj.tform{1}.offset + offset; 
                    case 2
                        obj.tform{2}.origin = obj.tform{2}.origin + offset*obj.tform{2}.rotation_rev_t./obj.tform{2}.gain;
                    case 3
                        offset_in_volts = obj.tform{3}.inverse_fcn(obj.tform{3},offset) - obj.tform{3}.inverse_fcn(obj.tform{3},[0 0]);
                        obj.tform{3}.moving_point = obj.tform{3}.moving_point + repmat(offset_in_volts,size(obj.tform{3}.moving_point,1),1);
                        t = projective_transform('calculate',obj.tform{3}.moving_point,obj.tform{3}.fixed_point);
                        obj.tform{3}.tdata = t.tdata;
                end
            end
            tform = obj.tform{obj.calmethod};
        end
        function rotate(obj,theta)
            obj.rotation_t = [cosd(theta) -sind(theta); sind(theta) cosd(theta)]';
            obj.rotation_rev_t = [cosd(-theta) -sind(-theta); sind(-theta) cosd(-theta)]';
        end
    end
    
    methods (Hidden = true)
        function tform = get_transform_matrix(obj)
            tform = obj.tform{obj.calmethod};
        end
        function set_transform_matrix(obj,tform)
            obj.tform{obj.calmethod} = tform;
        end
    end
end
