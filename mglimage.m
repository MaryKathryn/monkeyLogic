function h = mglimage(C,varargin)

if max(C(:)) <= 1, C = C * 255; end
if ~isa(C,'uint8'), C = uint8(C); end

if 4 == size(C,3)
    h = image(C(:,:,2:4),varargin{:});
    set(h,'AlphaData',double(C(:,:,1))/255);
else
    h = image(C,varargin{:});
end