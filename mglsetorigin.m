function mglsetorigin(id,point)
%   id - graphic object ids returned from addbitmap, addmovie, etc.
%   point - [x y], the new coordinates
%
%   This function changes the center positions of listed graphic objects.
%
%   May 4, 2016     Written by Jaewon Hwang (jaewon.hwang@hotmail.com)

if ~any(2==size(point)), error('POINT should be a n-by-2 matrix of [x y].'); end
if 2==size(point,2), point = point'; end

mdqmex(15,id,point);
