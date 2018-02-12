function mglwait4vblank(status,screen)
%mglwait4vblank(status)
%   status - 0 or 1
%
%   This function returns when the raster line is in the vertical blank (1)
%   or when it is out of the vertical blank (0);
%
%   May 4, 2016     Written by Jaewon Hwang (jaewon.hwang@hotmail.com)

if ~exist('status','var'), status = true; end
if ~exist('screen','var'), screen = 1; end

mdqmex(17,logical(status),screen);
