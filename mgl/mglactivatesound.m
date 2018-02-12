function mglactivatesound(id,status)
%mglactivatesound(id, status)
%   id - sound object ids returned from addsound.
%   status - 0 or 1
%
%   This function activates (1) or deactivates (0) sound objects added.
%   The ID of an object is always 1 or larger. ID 0 indicates all objects.
%
%   May 4, 2016     Written by Jaewon Hwang (jaewon.hwang@hotmail.com)

if ~exist('status','var'), status = true; end
if isscalar(status), [m,n] = size(id); status = repmat(status,m,n); end

mdqmex(27,id,logical(status));
