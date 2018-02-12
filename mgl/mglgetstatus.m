function status = mglgetstatus(id)
%   id - object ids returned from addbitmap, addmovie, etc.
%
%   May 4, 2016     Written by Jaewon Hwang (jaewon.hwang@hotmail.com)

status = mdqmex(32,id);
