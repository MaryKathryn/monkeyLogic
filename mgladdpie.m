function id = mgladdpie(color,sz,start_angle,central_angle,device)
%id = mgladdpie(color,sz,start_angle,central_angle)
%   id - graphic object id
%
%   The subject or control screen (or both) should be created before adding
%   any graphic object.
%
%   May 4, 2016     Written by Jaewon Hwang (jaewon.hwang@hotmail.com)

if ~exist('color','var') || isempty(color), color = [1 1 1]; end
if max(color(:)) <=1, color = round(color * 255); end

if isscalar(sz), sz = [sz sz]; end
if ~exist('device','var'), device = 3; end

id = mdqmex(46,color',sz,start_angle,central_angle,device);
