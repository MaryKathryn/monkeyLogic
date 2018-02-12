function sqr = make_rectangle(sz, rgb, fillflag, rotation)
%SYNTAX:
%        sqr = make_square(size, rbg, fillflag, rotation)
%
% Size is in pixels.  Rotation is optional and is in degrees.
%
%   Jun 10, 2016        Modified by Jaewon for correct alpha channel processing.
%                       sqr(:,:,1) is the alpha data and sqr(:,:,2:4) is RGB.
%                       Use mglimage() to display this image

if 1==length(sz)
    xs = round(sz);
    ys = round(sz);
else
    xs = round(sz(1));
    ys = round(sz(2));
end

sqr = ones(ys, xs);

if 0==fillflag
    bordersz = round(0.15 * min([xs ys]));
    sqr(bordersz:(ys-bordersz+1), bordersz:(xs-bordersz+1)) = 0;
end

if ~exist('rotation','var'), rotation = 0; end

if 0 ~= rotation, sqr = imrotate(sqr, rotation); end

if max(max(sqr)) > 0
    sqr = sqr./max(max(sqr));
end

sqr = uint8(sqr*255);
sqr = repmat(sqr,[1 1 4]);

if max(rgb)<=1, rgb = rgb*255; end
sqr(:,:,2) = rgb(1);
sqr(:,:,3) = rgb(2);
sqr(:,:,4) = rgb(3);

% mglimage(sqr);

