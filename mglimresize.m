function imdata2 = mglimresize(imdata,scale,method)

if ~exist('method','var'), method = 'bilinear'; end

sz = size(imdata);
if isscalar(scale)
    numrows = round(sz(2) * scale);
    numcols = round(sz(1) * scale);
else
    numrows = round(scale(2));
    numcols = round(scale(1));
end

imdata2 = zeros(numcols,numrows,sz(3),'uint8');
for m=1:sz(3)
    [x,y] = meshgrid(1:sz(2),1:sz(1));
    [nx,ny] = meshgrid(linspace(1,sz(2),numrows),linspace(1,sz(1),numcols));
    imdata2(:,:,m) = uint8(interp2(x,y,double(imdata(:,:,m)),nx,ny,method));
end

end
