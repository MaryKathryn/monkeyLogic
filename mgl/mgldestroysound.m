function mgldestroysound(id)
%mgldestroysound(id)
%   id - object ids returned from addsound.
%
%   This function destroys sound objects. The ID should be 1 or greater.
%   ID 0 indicates all objects.
%
%   May 4, 2016     Written by Jaewon Hwang (jaewon.hwang@hotmail.com)

mdqmex(29,id);
