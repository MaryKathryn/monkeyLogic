function crc = make_circle(radius, rgb, fillflag, varargin)
%SYNTAX:
%        crc = make_circle(radius, [r g b], fillflag, bgcolor)
%
% radius is in pixels. bgcolor is background color (optional).
%
% created by WA 7/06
% last modified 9/3/06 -WA
%
%   Jun 10, 2016        Modified by Jaewon for correct alpha channel processing.
%                       crc(:,:,1) is the alpha data and crc(:,:,2:4) is RGB.
%                       Use mglimage() to display this image

r2 = round(1.2 * radius);
i = -r2:1:r2;
[x,y] = meshgrid(i);

crc = sqrt((x.^2) + (y.^2));

if fillflag == 0
    thresh = 0;
    crc = radius - abs((radius - crc).^2);
    crc = crc.*(crc > thresh);
else
    inner = double(crc < radius);
    outer = double(crc >= radius);
    outer = radius - (outer.*(abs(crc - radius).^2));
    outer = outer.*(outer >= 0);
    crc = inner + outer;
end

crc = uint8(crc / max(max(crc)) * 255);
crc = repmat(crc,[1 1 4]);

if max(rgb)<=1, rgb = rgb*255; end
crc(:,:,2) = rgb(1);
crc(:,:,3) = rgb(2);
crc(:,:,4) = rgb(3);

% mglimage(crc);
