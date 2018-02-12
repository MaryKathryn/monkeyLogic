function mglcreatecontrolscreen(rect,color)
%mglcreatecontrolscreen(rect,color)
%	rect - [left top right bottom];
%   color - background color
%
%   Before calling this function, the subject screen should be created
%   first by mglcreatesubjectscreen(device).
%
%   May 4, 2016     Written by Jaewon Hwang (jaewon.hwang@hotmail.com)

subject_screen = mglgetscreeninfo(1);
if isempty(subject_screen), error('Create the subject screen first.'); end

if exist('rect','var')
    ndevice = mglgetadaptercount;
	
    intersect = zeros(ndevice,4);
    screen_rect = zeros(ndevice,4);
    for m=1:ndevice
        screen_rect(m,:) = mglgetadapterrect(m);
        intersect(m,:) = IntersectRect(rect, screen_rect(m,:));
    end
    
    area = (intersect(:,3)-intersect(:,1)) .* (intersect(:,4)-intersect(:,2));
    if all(0==area), error('The specified rectangle is out of screen.'); end
    [~,device] = max(area);
    
    if 1 < ndevice && device == subject_screen.Device && all(mglgetadapterrect(device)==subject_screen.Rect)
        subject_screen.Device
        device
        rect
        intersect
        screen_rect
        GetMonitorPosition
        error('The main menu window will be occluded by the subject screen. Please move it to a different location and try again.');
    end
else
    device = 1;
    rect = [0 0 800 600];
end

if ~exist('color','var') || isempty(color), color = [0.25 0.25 0.25]; end
if max(color) <=1, color = color * 255; end

mdqmex(5,device-1,int32(rect),uint8(color));
