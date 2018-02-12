function mglsetproperty(id,varargin)
%mglsetproperty(id,method,varargin)
%   id - object id
%   method - method to call
%
%   May 4, 2016     Written by Jaewon Hwang (jaewon.hwang@hotmail.com)

[type,subtype] = mglgettype(id);
if isempty(type) || nargin<2, return, end

idx = 1;
while idx < nargin
    method = lower(varargin{idx});
    idx = idx + 1;
    try
        switch type{1}
            case 'GDI'
                switch method
                    case 'origin', mglsetorigin(id,varargin{idx}); idx = idx + 1;
                    case {'edgecolor','facecolor'}
                        color = varargin{idx};
                        if 3~=numel(color), error('''Color'' must be a 1-by-3 vector.'); end
                        if max(color)<=1, color = round(255*color); end
                        mdqmex(22,id,method,color); idx = idx + 1;
                end
                switch subtype{1}
                    case 'PIE', mdqmex(22,id,method,varargin{idx}); idx = idx + 1;
                end
            case 'BITMAP'
                switch method
                    case 'origin', mglsetorigin(id,varargin{idx}); idx = idx + 1;
                end
            case 'MOVIE'
                switch method
                    case 'setnextframe', mdqmex(22,id,method,varargin{idx}-1); idx = idx + 1;  % 0-based
                    case 'seek', mdqmex(22,id,method,varargin{idx}); idx = idx + 1;
                    case 'resetinitframenum', mdqmex(22,id,method);
                    case {'framebyframe','looping'}, mdqmex(22,id,method,logical(varargin{idx})); idx = idx + 1;
                    case 'origin', mglsetorigin(id,varargin{idx}); idx = idx + 1;
                    case 'addframe'
                        bits = varargin{idx}; idx = idx + 1;
                        dim = ndims(bits);
                        sz = size(bits);
                        if 3~=dim && 4~=dim || 3~=sz(3) && 4~=sz(3), error('The first argument doesn''t look like a bitmap or movie.'); end
                        if ~isa(bits,'uint8')
                            if max(bits(:)) <= 1, bits = bits * 255; end
                            bits = cast(bits,'uint8');
                        end
                        if 3==dim, nframe = 1; else, nframe = sz(4); end
                        for m=1:nframe
                            frame = bits(:,:,:,m);
                            if 3 == sz(3), frame = cat(3,255*ones(sz(1:2),'uint8'),frame); end
                            frame = flipud(reshape(permute(frame,[2 1 3 4]),[],4)');
                            mdqmex(22,id,method,frame);
                        end
                end
            case 'LINE'
                switch method
                    case {'addpoint','addpoints'}, mdqmex(22,id,method,cast(varargin{idx}','uint32')); idx = idx + 1;
                    case 'color'
                        if isscalar(varargin{idx}), color = varargin{idx} * ones(1,3); else, color = varargin{idx}; end
                        idx = idx + 1;
                        if 3 ~= length(color), error('''Color'' must be a 1-by-3 vector.'); end
                        if max(color)<=1, color = 255 * color; end
                        mdqmex(22,id,method,uint8(color));
                    case 'clear'
                        mdqmex(22,id,method);
                end
            case 'TEXT'
                switch method
                    case 'origin', mglsetorigin(id,varargin{idx}); idx = idx + 1;
                    case {'normal','bold','italic','underline','strikeout'}, mdqmex(22,id,method);
                    case {'text','fontface','fontsize'}, mdqmex(22,id,method,varargin{idx}); idx = idx + 1;
                    case {'halign','valign'}
                        switch lower(varargin{idx})
                            case {'left','top',1}, mdqmex(22,id,method,1);
                            case {'center','middle',2}, mdqmex(22,id,method,2);
                            case {'right','bottom',3}, mdqmex(22,id,method,3);
                        end
                        idx = idx + 1;
                    case 'font'
                        if ischar(varargin{idx}), fontface = varargin{idx}; fontsize = varargin{idx+1}; else, fontface = varargin{idx+1}; fontsize = varargin{idx}; end
                        idx = idx + 2;
                        mdqmex(22,id,method,fontface,fontsize);
                    case 'color'
                        if isscalar(varargin{idx}), color = varargin{idx} * ones(1,3); else, color = varargin{idx}; end
                        idx = idx + 1;
                        if 3~=numel(color), error('''Color'' must be a 1-by-3 vector.'); end
                        if max(color)<=1, color = 255 * color; end
                        mdqmex(22,id,method,uint8(color));
                end
            case 'WAVE'
                switch method
                    case 'seek', mdqmex(22,id,method,varargin{idx}); idx = idx + 1;
                end
        end
    catch err
        switch err.identifier
            case 'MATLAB:badsubscript', error('mglsetproperty: Method and Arg do not match');
        end
    end
end
