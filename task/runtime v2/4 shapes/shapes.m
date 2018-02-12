if ~exist('eye_','var'), error('This demo requires eye signal input. Please set it up or try the simulation mode.'); end
showcursor(false);  % remove the joystick cursor

dashboard(1,'FINDING STAR',[0 1 0]);
dashboard(2,'What shape can we use as a stimulus?');
dashboard(3,'Anything that you can draw!',[1 0 0]);

nstim = 10;  % we will draw 9 stimuli
sz = ones(nstim,2) + 4 * repmat(rand(nstim,1),1,2);  % 1-5 degrees
color = [163 73 164; 63 72 204; 0 162 232; 34 177 76; 255 242 0; 255 127 39; 237 28 36];  % 7 preset colors
c = color(ceil(7*rand(nstim,1)),:);  % 9-by-3 matrix
scrsize = Screen.SubjectScreenFullSize / Screen.PixelsPerDegree;  % screen size in degrees
position = repmat(2.5,nstim,2) + repmat(scrsize-5,nstim,1).*rand(nstim,2) - repmat(scrsize/2,nstim,1);  % [0 0] is the screen center

fix1 = SingleTarget(eye_);
fix1.Target = position(9,:);
fix1.Threshold = sz(9,1);

wth1 = WaitThenHold(fix1);
wth1.WaitTime = 5000;
wth1.HoldTime = 0;

crc1 = CircleGraphic(wth1);
crc1.EdgeColor = c(1,:);
crc1.FaceColor = c(1,:);
crc1.Size = sz(1,:);
crc1.Position = position(1,:);

pie1 = PieGraphic(crc1);
pie1.EdgeColor = c(2,:);
pie1.FaceColor = c(2,:);
pie1.Size = sz(2,:);
pie1.Position = position(2,:);
pie1.StartDegree = 360 * rand;
pie1.CenterAngle = 45 + 270 * rand;

tri1 = PolygonGraphic(pie1);
tri1.EdgeColor = c(3,:);
tri1.FaceColor = c(3,:);
tri1.Size = sz(3,:);
tri1.Position = position(3,:);
tri1.Vertex = [0.5 1; 0.067 0.25; 0.9333 0.25];  % normalized coordinates

sqr1 = BoxGraphic(tri1);
sqr1.EdgeColor = c(4,:);
sqr1.FaceColor = c(4,:);
sqr1.Size = sz(4,:) * cosd(45);
sqr1.Position = position(4,:);

dia1 = PolygonGraphic(sqr1);
dia1.EdgeColor = c(5,:);
dia1.FaceColor = c(5,:);
dia1.Size = sz(5,:);
dia1.Position = position(5,:);
dia1.Vertex = [0.5 1; 0 0.5; 0.5 0; 1 0.5];

pen1 = PolygonGraphic(dia1);
pen1.EdgeColor = c(6,:);
pen1.FaceColor = c(6,:);
pen1.Size = sz(6,:);
pen1.Position = position(6,:);
pen1.Vertex = [0.5 1; 0.0245 0.6545; 0.2061 0.0955; 0.7939 0.0955; 0.9755 0.6545];

hex1 = PolygonGraphic(pen1);
hex1.EdgeColor = c(7,:);
hex1.FaceColor = c(7,:);
hex1.Size = sz(7,:);
hex1.Position = position(7,:);
hex1.Vertex = [0.5 1; 0.067 0.75; 0.067 0.25; 0.5 0; 0.933 0.25; 0.933 0.75];

oct1 = PolygonGraphic(hex1);
oct1.EdgeColor = c(8,:);
oct1.FaceColor = c(8,:);
oct1.Size = sz(8,:);
oct1.Position = position(8,:);
oct1.Vertex = [0.5 1; 0.1464 0.8536; 0 0.5; 0.1464 0.1464; 0.5 0; 0.8536 0.1464; 1 0.5; 0.8536 0.8536];

star1 = PolygonGraphic(oct1);
star1.EdgeColor = c(9,:);
star1.FaceColor = c(9,:);
star1.Size = sz(9,:);
star1.Position = position(9,:);
star1.Vertex = [0.5 1; 0.375 0.625; 0 0.625; 0.25 0.375; 0.125 0; 0.5 0.25; 0.875 0; 0.75 0.375; 1 0.625; 0.625 0.625];

text1 = TextGraphic(star1);
text1.Text = 'Star';
text1.FontSize = sz(10,1)*20;
text1.FontColor = c(10,:);
text1.Position = position(10,:);
text1.HorizontalAlignment = 'center';
text1.VerticalAlignment = 'middle';

scene1 = create_scene(text1);
run_scene(scene1);

if wth1.Success
    trialerror(0);  % correct
else
    trialerror(2);  % no or late response
end

set_iti(500);
