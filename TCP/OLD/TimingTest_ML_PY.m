%to compare Matlab v. Python in TCP speed across UE3 and UE4

clear
clc

%Set to your screen resolution
resX = 640;
resY = 480;

%Windowed or FullScreen
WorF = 'WINDOWED';

% system(['UDK INSTAL PATH\Binaries\UDKLift MAPNAME?game=TASKFOLDER.GAMEINFO -NOSPLASH -WINDOWED or FULLSCREEN ResX=' num2str(resX) ' ResY=' num2str(resY)])
system(['C:\UDK\UDK_MLClean\Binaries\UDKLift Hc_TrainingX_med_12?game=ML_Utilities.ML_GameInfo -log -NOSPLASH -USEALLAVAILABLECORES -VSync -' WorF ' ResX=' num2str(resX) ' ResY=' num2str(resY)]);
%%

%% Matlab

TCP = tcpip(IP, Port);

set(TCP, 'Terminator', {'CR/LF','CR/LF'});
set(TCP, 'InputBufferSize', Buffer);
set(TCP, 'OutputBufferSize', Buffer);

fopen(TCP);

%%
TimerML = nan(1000,1);
for k = 1: 1000
    tic
    variable = [];
    fprintf(TCP, 'GETPLAYERINFOS');
    
    temp = fscanf(TCP);
    variable = strcat(variable, temp);
    while isempty(strfind(temp, InTerminator))
        temp = fscanf(TCP);
        
        %Looks for END OF TRANSMISSION in the first 20 characters of temp
        %because UDK returns 2 line breaks after the string.
        if ~strncmp(temp, InTerminator, 20)
            variable = strcat(variable, temp);
        end
        
    end
    TimerML(k) = toc;
    pause(0.01)
end

%% Python
clear classes
% clc
module = py.importlib.import_module('ML_MatlabTcpTunnel_V2');
py.importlib.reload(module);
%%
pyObj = py.ML_MatlabTcpTunnel_V2.ML_MatlabTcpTunnel_V2(IP,Port,Buffer,InTerminator, OutTerminator, TimeOut );
tic
(pyObj.Connect())
toc
%pyObj.SendMessage('Test');
% else
%    a=0
% end
% pyObj.Close()
%%
TimerPy = nan(1000,1);
for k = 1: 1000
    tic
    variable = [];
    pyObj.SendMessage('GETPLAYERINFOS');
    toc
    temp = char(pyObj.ReceiveMessage());
    
    TimerPy(k) = toc;
    % pause(0.1)
end
mean(TimerPy)
%% For UE3 @ 120Hz
% Mean TImer ML  = 13 ms
% Mean Timer Py = 5 ms

%@ 75 Hz
% Mean TImer ML  = 15 ms
% Mean Timer Py = 7 ms


%% For UE4
% Mean TImer ML  = 12 ms
% Mean Timer Py = 0.2 ms

%%  Timing test where UDK sends the frame data on every frame and we simply
%loop the python script to gather it

%when UDK connection gets initialized, it will output the player data on
%each tick / frame, so we will only look to gather data

pyObj.Connect();
tempStr = cell(1000,1);
tempTime = NaN(1000,1);
tic
for k=1:1000
    tempStr{k} = char(pyObj.ReceiveMessage());
    tempTime(k) = toc;
end



pyObj.Close()


%%
tic
tempBuffers2 = cell(pyObj.ReturnAllBuffers());
toc
tic
%Clear buffers (trial has ended)
pyObj.Clear_Buffers();
toc
pyObj.Close()

%%
clearvars obj
%Separates tempBuffers into appropriate variables
tic
obj.UE_Position = cellfun(@(x) (char(x)), cell(tempBuffers{1}), 'uni', 0)';
toc
%%
tic
obj.UE_Rotation = cellfun(@(x) (char(x)), cell(tempBuffers{2}), 'uni', 0)';
toc
%%
obj.UE_State = cellfun(@(x) (char(x)), cell(tempBuffers{3}), 'uni', 0)';
obj.UE_Time = cellfun(@(x) (char(x)), cell(tempBuffers{4}), 'uni', 0)';
obj.UE_QueryTime = cellfun(@(x) (char(x)), cell(tempBuffers{5}), 'uni', 0)';
obj.P_SampleTime = cellfun(@(x) (char(x)), cell(tempBuffers{6}), 'uni', 0)';
obj.P_Error = cellfun(@(x) (char(x)), cell(tempBuffers{7}), 'uni', 0)';
obj.P_ErrorTime = cellfun(@(x) (char(x)), cell(tempBuffers{8}), 'uni', 0)';

%%

%% Python
clear classes

pyPath = py.sys.path;
mlPath = 'D:\ML_UE4_Project\MonkeyLogic\TCP\';

if count(pyPath,mlPath) == 0
    insert(pyPath,int32(0),mlPath);
end

module = py.importlib.import_module('ML_MatlabTcpTunnel');
py.importlib.reload(module);

%%
IP = 'localhost'; %'127.0.0.1';
Port = uint16(3000);
Buffer = uint16(2^16);
InTerminator = ' END OF TRANSMISSION';
OutTerminator = [char(13) char(10)];
TimeOut = 1.00;

pyObj = py.ML_MatlabTcpTunnel.ML_MatlabTcpTunnel(IP,Port,Buffer,InTerminator, OutTerminator, TimeOut );
tic
(pyObj.Connect())
toc

%%
test = nan(1000,1);
for k=1:1000

tic
pyObj.ReturnSingleData('Pos');
test(k) = toc;
pause(0.01)
end

%%
clc
tic
Timer = pyObj.Timer();
toc
tic
ReturnLastState(pyObj)
toc

%%
for k=1:1000
tic
data = char(pyObj.ReturnLastState(pyObj.Timer()));
toc
end