function refreshrate = mglgetrefreshrate(screen)
%refreshrate = mglgetrefreshrate(screen)
%
%   May 4, 2016     Written by Jaewon Hwang (jaewon.hwang@hotmail.com)

if ~exist('screen','var'), screen = 1; end

refreshrate = mdqmex(33, screen);
