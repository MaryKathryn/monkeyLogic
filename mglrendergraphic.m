function mglrendergraphic(frameNum,screen,clear)
%mglrendergraphic(frameNum)
%   frameNum - count of refresh, 0-based
%   screen - subject(1), control(2), or both(3)
%
%   This function renders all active graphic objects for presenting.
%
%   May 4, 2016     Written by Jaewon Hwang (jaewon.hwang@hotmail.com)

if ~exist('frameNum','var'), frameNum = 0; end
if frameNum < 0, error('The frame number must be 0 or greater.'); end
if ~exist('screen','var'), screen = 3; end
if ~exist('clear','var'), clear = true; end

mdqmex(8, frameNum, screen, logical(clear));
