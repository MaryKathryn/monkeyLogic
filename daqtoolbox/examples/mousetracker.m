% This example demonstrates how to acquired the position of the mouse cursor
% continuously (at ~1 kHz).

mouse = pointingdevice;  % equivalent to pointingdevice('mouse',0);
start(mouse);  % start sampling

timer = tic;
while toc(timer) < 10  % run for 10 sec
    % check the current position
    [xy,buttons] = getsample(mouse);

    fprintf('%4d %4d %1d %1d\n',xy,buttons);
    pause(0.02);
end

stop(mouse);  % stop sampling

% retrieve all samples collected
[xy,buttons,timestamps] = getdata(mouse);
