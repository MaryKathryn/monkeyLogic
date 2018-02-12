function out = dec2binvec(dec,n)

if ~exist('n','var')
    out = dec2bin(dec);
else
    out = dec2bin(dec,n);
end

out = fliplr('1' == out);
