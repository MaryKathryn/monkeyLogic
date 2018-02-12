function [position,device] = GetMonitorPosition(device)
%position = GetMonitorPosition()
%   position - [left bottom width height]
%   device - DirectX device number or [left top right bottom]
%
%   May 4, 2016     Written by Jaewon Hwang (jaewon.hwang@hotmail.com)

nadapter = mglgetadaptercount;  % make MATLAB aware of DPI

position = get(0,'MonitorPosition');

% fix the bug of get(0,'MonitorPosition') in R2015aSP1 or earlier.
if verLessThan('matlab','8.4')
    screensize = get(0,'ScreenSize');
    position(:,3:4) = position(:,3:4) - position(:,1:2) + 1;
    position(:,2) = screensize(4) - position(:,4) - position(:,2) + 2;
elseif verLessThan('matlab','8.6')
    screensize = get(0,'ScreenSize');
    DPI_ratio = mglgetadapterdisplaymode(1) / screensize(3);
    if 1 < DPI_ratio
        position(:,1) = position(:,1) + min(position(:,1)) - 1;
        position(:,2) = position(:,2) + max(sum(position(:,[2 4]),2)) - screensize(4);
    end
end

% sort the order of the positions to be the same as the Direct's device order.
rect = Pos2Rect(position);
order = NaN(1,nadapter);
for m=1:nadapter
    intersect = IntersectRect(mglgetadapterrect(m),rect);
    [~,order(m)] = max((intersect(:,3)-intersect(:,1)) .* (intersect(:,4)-intersect(:,2)));
end
position = position(order,:);
rect = rect(order,:);

% return the position of a particular monitor when the device number or the
% window rect is given.
if exist('device','var')
    if ~isscalar(device)
        intersect = IntersectRect(device,rect);
        [~,device] = max((intersect(:,3)-intersect(:,1)) .* (intersect(:,4)-intersect(:,2)));
    end
    position = position(device,:);
end
