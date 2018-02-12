function id = mgladdmovie(filename,buffering_time,device)
%id = mgladdmovie(filepath[, buffering_time])
%id = mgladdmovie(sz,time_per_frame)
%   id - movie object id
%   buffering_time - buffering time in seconds
%   sz - [width height]
%   time_per_frame - time during which one frame is presented. In seconds.
%
%   May 4, 2016     Written by Jaewon Hwang (jaewon.hwang@hotmail.com)

if ~exist('buffering_time','var') || isempty(buffering_time), buffering_time = 2; end
if ~exist('device','var'), device = 3; end

if ischar(filename)   % mgladdmovie(filepath)
    id = mdqmex(11,filename,buffering_time,device);
elseif 1<nargin
    sz = size(filename);
    if 2==length(sz)  % mgladdmovie(sz,time_per_frame)
        id = mdqmex(11,filename,buffering_time,device);
    else              % mgladdmovie(imdata,time_per_frame)
        id = mdqmex(11,sz([2 1]),buffering_time,device);
        mglsetproperty(id,'addframe',filename);
    end
end
