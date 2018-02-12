function id = mgladdbitmap(varargin)
%id = mgladdbitmap(filename [,colorkey])
%id = mgladdbitmap(bits [,colorkey])
%   id - graphic object id
%   filename - Only *.bmp can be read directly from the file.
%   colorkey - transparent color
%   bits - bitmap color matrix of [width x height x 3 (or 4)]
%          The page order of a transparent image must be [A-R-G-B], which
%          means the first page should be alpha data.
%          The transparent color and the alpha channel cannot be set both.
%          Then the colorkey will be ignored.
%
%   The subject or control screen (or both) should be created before adding
%   any graphic object.
%
%   May 4, 2016     Written by Jaewon Hwang (jaewon.hwang@hotmail.com)

if 0==nargin, error('The first argument must be either filename or bitmat data.'); end

default_colorkey = [30 31 32];
switch nargin
    case 1, colorkey = default_colorkey; device = 3;
    case 2, if isscalar(varargin{2}), device = varargin{2}; colorkey = default_colorkey; else device = 3; colorkey = varargin{2}; end
    case 3, if isscalar(varargin{2}), device = varargin{2}; colorkey = varargin{3}; else colorkey = varargin{2}; device = varargin{3}; end
end
if max(colorkey) <=1, colorkey = colorkey * 255; end
colorkey = uint8(colorkey);

if ischar(varargin{1})
    filename = varargin{1};
    if 2~=exist(filename,'file'), error('The file, %s, does not exist.',filename); end
    [~,~,ext] = fileparts(filename);
    if ~strcmpi(ext,'.bmp'), error('Only a BMP file can be added directly.'); end
    id = mdqmex(7, filename, colorkey, device);
else
    bits = varargin{1};
    if 2==ndims(bits), bits = repmat(bits,[1 1 3]); end %#ok<ISMAT>
    if 3~=ndims(bits), error('The first argument doesn''t look like a bitmap data.'); end
    if ~isa(bits,'uint8')
        if max(bits(:)) <= 1, bits = bits * 255; end
        bits = uint8(bits);
    end
    sz = size(bits);
    if 3 == sz(3), bits = cat(3,255*ones(sz(1:2),'uint8'),bits); end
    bits = flipud(reshape(permute(bits,[2 1 3 4]),[],4)');
    id = mdqmex(7, sz([2 1 3]), bits, colorkey, device);
end
