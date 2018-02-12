function mglsetcontrolscreenrect(rect)
%mglsetcontrolscreenrect(rect)
%	rect - [left top right bottom];
%
%   May 4, 2016     Written by Jaewon Hwang (jaewon.hwang@hotmail.com)

if any(0==rect(3:4)-rect(1:2)), return, end

mdqmex(19,rect);
