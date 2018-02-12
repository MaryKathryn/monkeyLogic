function [type,subtype] = mglgettype(id)
%   id - object ids returned from addbitmap, addmovie, etc.
%
%   May 4, 2016     Written by Jaewon Hwang (jaewon.hwang@hotmail.com)

[type,subtype] = mdqmex(21,id);
