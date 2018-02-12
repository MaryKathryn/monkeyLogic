function fliptime = mglpresent(screen,varargin)
%mglpresent(screen)
%   screen - subject(1), control(2), or both(3)
%
%   May 4, 2016     Written by Jaewon Hwang (jaewon.hwang@hotmail.com)

if ~exist('screen','var'), screen = 3; end

fliptime = mdqmex(9,screen,varargin{:});
