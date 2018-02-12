function mgldestroygraphic(id)
%mgldestroygraphic(id)
%   id - graphic object ids returned from addbitmap, addmovie, etc.
%
%   This function destroys graphic objects. The ID should be 1 or greater.
%   ID 0 indicates all objects.
%
%   May 4, 2016     Written by Jaewon Hwang (jaewon.hwang@hotmail.com)

mdqmex(12,id);
