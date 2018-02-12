function property = mglgetproperty(id,varargin)
%property = mglgetproperty(id)
%   id - object id
%
%   May 4, 2016     Written by Jaewon Hwang (jaewon.hwang@hotmail.com)

property = [];
if 1 < nargin, method = lower(varargin{1}); else method = ''; end

type = mglgettype(id);
switch type{1}
    case 'GDI'
    case 'BITMAP'
        switch method
            case 'origin', property = mdqmex(13,id,method);
            otherwise, property = mdqmex(13,id,'size');
        end
    case 'MOVIE'
        switch method
            case 'getbuffer'
                if 2 < nargin
                    seektime = varargin{2};
                    property = permute(mdqmex(13,id,method,seektime),[2 1 3 4]);
                else
                    property = permute(mdqmex(13,id,method),[2 1 3 4]);
                end
            case {'origin','size'}, property = mdqmex(13,id,method);
            otherwise, property = mdqmex(13,id,'info');
        end
    case 'LINE'
    case 'TEXT'
        switch method
            case {'origin','rect'}, property = mdqmex(13,id,method);
            otherwise, property = mdqmex(13,id,'size');
        end
    case 'WAVE'
        switch method
            case {'isplaying','duration'}, property = mdqmex(13,id,method);
            otherwise, property = mdqmex(13,id,'info');
        end
end
