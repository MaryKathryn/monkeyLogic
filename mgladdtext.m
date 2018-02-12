function id = mgladdtext(string,device)
%id = mgladdtext(string,device)
%   id - graphic object id
%
%   The subject or control screen (or both) should be created before adding
%   any graphic object.
%
%   May 4, 2016     Written by Jaewon Hwang (jaewon.hwang@hotmail.com)

if ~exist('string','var'), string = ''; end
if ~exist('device','var'), device = 3; end

id = mdqmex(26,string,device);
