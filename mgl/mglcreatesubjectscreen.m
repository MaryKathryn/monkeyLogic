function mglcreatesubjectscreen(device,color,fallback_screen_size,forced_fallback)
%mglcreatesubjectscreen(device,color)
%	device - the device number where you want to create the subject screen.
%            It is a value between 1 and the number of your monitors.
%   color - background color
%
%   May 4, 2016     Written by Jaewon Hwang (jaewon.hwang@hotmail.com)

ndevice = mglgetadaptercount;
if device<1 || ndevice<device, error('The specified adapter #%d does not exist. Use 1-%d.',device,ndevice); end

if ~exist('color','var') || isempty(color), color = [0 0 0]; end
if max(color) <= 1, color = color * 255; end
if ~exist('fallback_screen_size','var'), fallback_screen_size = [0 0 1024 768]; end
if ischar(fallback_screen_size), fallback_screen_size = eval(fallback_screen_size); end
if ~exist('forced_fallback','var'), forced_fallback = 0; end

mdqmex(3,device-1,uint8(color),int32(fallback_screen_size),double(forced_fallback));
