function id = mgladdcircle(color,sz,device)
%id = mgladdcircle(color,sz)
%   id - graphic object id
%   color - color can be a 1-by-3 or 2-by-3 ([facecolor; edgecolor]) matrix.
%   sz - [width height]
%
%   The subject or control screen (or both) should be created before adding
%   any graphic object.
%
%   May 4, 2016     Written by Jaewon Hwang (jaewon.hwang@hotmail.com)

if ~exist('color','var') || isempty(color), color = [1 1 1]; end
if max(color(:)) <=1, color = round(color * 255); end

if isscalar(sz), sz = [sz sz]; end
if ~exist('device','var'), device = 3; end

id = mdqmex(24,color',sz,device);
