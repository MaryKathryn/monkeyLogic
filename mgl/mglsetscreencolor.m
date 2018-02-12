function mglsetscreencolor(screen,color)
%function mglsetscreencolor(screen,color)

if max(color) <=1, color = color * 255; end
color = uint8(color);

mdqmex(47,screen,color);
