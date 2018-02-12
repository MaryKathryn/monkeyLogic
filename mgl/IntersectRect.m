function intersect = IntersectRect(obj,rects)
%intersect = IntersectRect(obj,rects)
%   All rect variables (intersect, obj and rects) are in Windows rectangle
%   format, which is [left top right bottom].
%
%   This function calculates the size of the overlapped area between one
%   rectagle (obj) and many other rectangles (rects).
%
%   May 4, 2016     Written by Jaewon Hwang (jaewon.hwang@hotmail.com)

intersect = [max(obj(1),rects(:,1)) max(obj(2),rects(:,2)) min(obj(3),rects(:,3)) min(obj(4),rects(:,4))];
row = intersect(:,3)<=intersect(:,1) | intersect(:,4)<=intersect(:,2);
intersect(row,:) = 0;
