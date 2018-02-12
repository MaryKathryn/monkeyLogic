function mglactivategraphic(id,status)
%mglactivategraphic(id, status)
%   id - graphic object ids returned from addbitmap, addmovie, etc.
%   status - inactive (0) or active (1)
%
%   This function activates (1) or deactivates (0) graphic objects added.
%   The ID of an object is always 1 or larger. ID 0 indicates all objects.
%
%   May 4, 2016     Written by Jaewon Hwang (jaewon.hwang@hotmail.com)

if ~exist('status','var'), status = true; end
if isscalar(status), [m,n] = size(id); status = repmat(status,m,n); end

mdqmex(10,id,logical(status));
