function id = mgladdsound(varargin)
%id = mgladdsound(filepath)
%id = mgladdsound(y,fs)
%   id - sound object id
%   y - n-by-channel sound data, between 0 and 1 
%   fs - sample rate
%
%   May 4, 2016     Written by Jaewon Hwang (jaewon.hwang@hotmail.com)

switch nargin
	case 1
		filename = varargin{1};
		id = mdqmex(28,filename);
	case 2
		y = cast(varargin{1} * 32767,'int16');
        [~,I] = max(size(y));
        if 1==I, y = y'; end
		fs = varargin{2};
		id = mdqmex(28,y,fs);
end
