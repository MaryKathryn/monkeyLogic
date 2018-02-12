function id = mgladdpolygon(color,sz,vertex,device)
%id = mgladdpolygon(color,sz,vertex)
%   id - graphic object id
%   color - color can be a 1-by-3 or 2-by-3 ([facecolor; edgecolor]) matrix.
%   sz - [width height]
%
%   The subject or control screen (or both) should be created before adding
%   any graphic object.
%
%   Sep 21, 2017     Written by Jaewon Hwang (jaewon.hwang@hotmail.com)

if ~exist('color','var') || isempty(color), color = [1 1 1]; end
if max(color(:)) <=1, color = round(color * 255); end

if isscalar(sz), sz = [sz sz]; end
if ~exist('device','var'), device = 3; end

id = mdqmex(45,color',sz,vertex(:,1),vertex(:,2),device);
