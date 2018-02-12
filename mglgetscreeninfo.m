function info = mglgetscreeninfo(screen)

if ~exist('screen','var'), screen = 2; end

info = mdqmex(38, screen);
