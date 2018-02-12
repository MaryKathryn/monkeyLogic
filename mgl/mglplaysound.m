function mglplaysound(id)
%mglplaysound(id)
%   id - sound object ids
%
%   The IDs of individual sounds are always 1 or larger. ID 0 indicates all
%   sound objects.
%
%   May 4, 2016     Written by Jaewon Hwang (jaewon.hwang@hotmail.com)

if ~exist('id','var'), id = 0; end

mdqmex(30,id,true);
