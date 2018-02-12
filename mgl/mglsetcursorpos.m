function mglsetcursorpos(position)
%mglsetcursorpos(position)
%	position - [x y];
%
%   May 4, 2016     Written by Jaewon Hwang (jaewon.hwang@hotmail.com)

if ~exist('position','var'), position = 0; end

mdqmex(34,position);
