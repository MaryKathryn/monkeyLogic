function out = binvec2dec(bin)

bin = double(0<bin(:)');

out = bin * pow2(0:length(bin)-1)';
