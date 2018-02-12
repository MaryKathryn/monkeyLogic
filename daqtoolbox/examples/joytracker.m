% This is an example of tracking the position of the joystick cursor
% approximately at 1 kHz. The joystick should a USB type or something
% directly pluggable to the computer without a DAQ device.

joy = pointingdevice('joystick',0);
start(joy);  % start sampling

timer = tic;
while toc(timer) < 10  % run for 10 sec
    % check the current position
    [xy,buttons] = getsample(joy);

    fprintf('%4d %4d',xy);
    fprintf(' %1d',buttons);
    fprintf('\n');
    pause(0.02);
end

stop(joy);  % stop sampling

% retrieve all samples collected
[xy,buttons,timestamps] = getdata(joy);
