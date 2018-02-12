import socket
import multiprocessing
import re
from timeit import default_timer as timer
import time
#replacing threading with multiprocessing
          
    #define subclass for TCP socket holder
class TCPHolder():
    def __init__(self, Address, Port, BuffSize, InTerminator, OutTerminator, TimeOut, Timer):
        #TCP vars =========================================================================
        self.Address = Address
        self.Port = Port 
        self.BuffSize = BuffSize
        self.InTerminator = InTerminator #wait for exp in data to stop acquisition
        self.OutTerminator = OutTerminator #adds at the end of output string
        self.TimeOut = TimeOut 
        self.Socket = None #socket holder
        self.Timer = Timer 

    #Initialize connection to UE  
    def Connect(self):
        #Creates socket object
        socket.setdefaulttimeout(self.TimeOut)
        self.Socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        
        #Connects to server
        connectError = self.Socket.connect_ex((self.Address, self.Port))
        if (connectError==0):
            self.Socket.setblocking(0)
            return True
        else:
            return False
    
    #Write to socket. Appends terminator automatically
    def SendMessage(self, Message):
        Message = Message + self.OutTerminator
        sent = self.Socket.send(Message.encode('utf-8'))
        return True

    #Read socket. Removes terminator and \r\n 
    def ReceiveMessage(self):
        Message = '' 
        
        if not self.Socket._closed:
            try:
                tempMessage = self.Socket.recv(self.BuffSize)
                Message = tempMessage.decode('utf-8')
        
                while self.InTerminator not in Message:
                    tempMessage = self.Socket.recv(self.BuffSize)    
                    Message += tempMessage.decode('utf-8')
            
                    if self.InTerminator != '\r\n':
                        Message = Message.replace('\n','')
                        Message = Message.replace('\r','')
            except BaseException as err: # it is possible that connection is terminated while the read operation is underway, catches exception
                Message = ''
            
        return Message.replace(self.InTerminator, '')

    #Terminates socket
    def Close(self):
        self.Socket.close()
        self.Socket = None

class DataHolder():
    def __init__(self, Timer, SOT):
        # Position buffers. Will separate the data string into sections and append them to a
        # list. 
        self.Pos_Buffer = list() #Position X,Y,Z\X,Y,Z\... in string
        self.Rot_Buffer = list() # Rotation in Unreal Units (to get degrees : ROT / 2^15 * 180 == ROT / signed int 16 * 180 degrees)
        self.ST_Buffer = list() # Sample times: time at which the player position is sampled
        self.Sta_Buffer = list() # Player state
        self.QT_Buffer = list() # Query Time: time at which the player data is sent on the TCP socket
        self.E_Buffer = list() # String received if reg exp doesn't work
        
        self.SampleTime = list() #Python time when sample is received 
        self.E_SampleTime = list() #Python time when sample is received for error messages
     
        self.reProg = re.compile('^(PlayerInfos&&PlayerPosition#)(?P<Pos>.*)(&&PlayerRotation#)(?P<Rot>.*)(&&SampleTimes#)(?P<ST>.*)(&&PlayerState#)(?P<Sta>.*)(&&QueryTime#)(?P<QT>\d{1,}\:\d{1,}\:\d{1,}\.\d{1,})(\r\n)*') # reg exp to split UE data
        self.Timer = Timer 
        self.SOT = SOT
        #self.Lock = threading.RLock()

    def AppendData(self, Data):
        tempSplit = self.reProg.match(Data)
        if tempSplit.__class__ != type(None): 
            if len(tempSplit.group('Pos')) > 0:
                self.SampleTime.append((self.Timer() - self.SOT)*1000) #in ms
                self.Pos_Buffer.append(tempSplit.group('Pos'))
                self.Rot_Buffer.append(tempSplit.group('Rot'))
                self.ST_Buffer.append(tempSplit.group('ST'))
                self.Sta_Buffer.append(tempSplit.group('Sta'))
                self.QT_Buffer.append(tempSplit.group('QT'))
        else:
            self.E_SampleTime.append((self.Timer() - self.SOT)*1000) #in ms
            self.E_Buffer.append(Data)

    def NewTimer(self, OldSOT, NewSOT):
        self.SOT = NewSOT
        if len(self.SampleTime) > 0:
            self.SampleTime[:] = [ (((x /1000) - NewSOT + OldSOT )*1000) for x in self.SampleTime]
    
        if len(self.E_SampleTime) > 0:
            self.E_SampleTime[:] = [ (((x /1000) - NewSOT + OldSOT )*1000) for x in self.E_SampleTime]

    def Return_Buffers(self):
        tempPos = self.Pos_Buffer
        tempRot = self.Rot_Buffer
        tempSta = self.Sta_Buffer
        tempST = self.ST_Buffer
        tempPST = self.SampleTime
        tempQT = self.QT_Buffer
        tempE = self.E_Buffer
        tempEST = self.E_SampleTime
        self.Clear_Buffers()
        return tempPos, tempRot, tempSta, tempST, tempQT, tempPST, tempE, tempEST
              
    def Return_SingleData(self, Buffer):
        if Buffer == 'Pos': # Position buffer
            if len(self.Pos_Buffer) > 0:
                tempData = self.Pos_Buffer[-1]
        elif Buffer == 'Rot': # Rotation buffer
            if len(self.Rot_Buffer) > 0:
                tempData = self.Rot_Buffer[-1]
        elif Buffer == 'Sta': # Player State buffer
            if len(self.Sta_Buffer) > 0:
                tempData = self.Sta_Buffer[-1]
        elif Buffer == 'UST': # Unreal Sample Times buffer
            if len(self.ST_Buffer) > 0:
                tempData = self.ST_Buffer[-1]
        elif Buffer == 'QT': # Unreal Query Time buffer
            if len(self.QT_Buffer) > 0:
                tempData = self.QT_Buffer[-1]
        elif Buffer == 'PST': # Python sample time buffer
            if len(self.SampleTime) > 0:
                tempData = self.SampleTime[-1]
        elif Buffer == 'E':  # Error buffer
            if len(self.E_Buffer) > 0:
                tempData = self.E_Buffer[-1]
        elif Buffer == 'ET': # Error Times buffer
            if len(self.E_SampleTime) > 0:
                tempData = self.E_SampleTime[-1]
        else:
            tempData = 'Empty'

        return tempData

        #Once the buffers have been read, clear them for the next trial
    def Clear_Buffers(self):
        self.Pos_Buffer = list() #Position X,Y,Z\X,Y,Z\... in string
        self.Rot_Buffer = list() # Rotation in Unreal Units (to get degrees : ROT / 2^15 * 180 == ROT / signed int 16 * 180 degrees)
        self.ST_Buffer = list() # Sample times: time at which the player position is sampled
        self.Sta_Buffer = list() # Player state
        self.QT_Buffer = list() # Query Time: time at which the player data is sent on the TCP socket
        self.E_Buffer = list() # String received if reg exp doesn't work
        self.SampleTime = list() #Python time when sample is received 
        self.E_SampleTime = list() #Python time when sample is received for error messages

class TCPProcess(multiprocessing.Process):#threading.Thread):
    #def __init__(self, TCPHolder, DataHolder, Timer, e, Parent_Pipe):
    def __init__(self, e, Parent_Pipe):
        multiprocessing.Process.__init__()
        #self.TCPHolder = TCPHolder
        #self.DataHolder = DataHolder
        #self.Timer = Timer
        self.e = e
        self.Parent_Pipe = Parent_Pipe
    
    def run(self):
        print('gne gne gne')  
        self.Parent_Pipe.send('gne gne gne')
        #Threads communicate with events, event is set when socket sampling is terminated
        while not self.e.is_set():
            print('gne gne gne')    
                #creates a short pause
                #WaitTime = self.Timer()+0.1
                #while self.Timer() < WaitTime:
                #    do = 'nothing'
    
            #Sometimes pools between socket being closed and event being set
            #if not self.TCPHolder.Socket._closed:
            #    tempMsg = self.TCPHolder.ReceiveMessage()
            #    if len(tempMsg) > 0:
            #        self.DataHolder.AppendData(tempMsg) #parse message
            #       self.Parent_Pipe.send(self.DataHolder.Return_SingleData('Sta'))
                    
class ML_MatlabTcpTunnel_V4():
    def __init__(self, Address, Port, BuffSize, InTerminator, OutTerminator, TimeOut): 
        #Trial variables
        self.Timer = timer; #self explanatory
        self.SOT = timer() #Start Of Trial time; inits to creation time, reset on each trial
        
        self.TCPHolder = TCPHolder(Address, Port, BuffSize, InTerminator, OutTerminator, TimeOut, self.Timer)
        self.DataHolder = DataHolder(self.Timer, self.SOT)
        self.Parent_Pipe, self.Child_Pipe = multiprocessing.Pipe()
        self.e = multiprocessing.Event() #declaration of event being passed across threads
        #self.TCPProcess = TCPProcess(self.TCPHolder, self.DataHolder, self.Timer, self.e, self.Child_Pipe)
        self.TCPProcess = multiprocessing.Process(target = self.fRunProcess, args=(self.e, self.Child_Pipe))
        #self.TCPThread.daemon = True

    #Trial Timer start
    def Init_Timer(self):
        #since we can have data in the buffer, we will compute negative time from the new SOT
        oldSOT = self.SOT
        self.SOT = self.Timer()
        self.DataHolder.NewTimer(oldSOT, self.SOT)
        
    def Connect(self):
        out = self.TCPHolder.Connect()
        if out == 0:
            return False
        else:
            self.e.clear()
            self.TCPProcess.daemon = True
            self.TCPProcess.start()
            return True
        
    def Close(self):
        #stops thread
        self.e.set()
        self.TCPHolder.Close()

    def ReturnSingleData(self, Buffer):
        return self.DataHolder.Return_SingleData(Buffer)
        
    def ReturnAllBuffers(self):
        return self.DataHolder.Return_Buffers()

    def ClearAllBuffers(self):
        self.DataHolder.Clear_Buffers()

    def SendMessage(self, Message):
        return self.TCPHolder.SendMessage(Message)

    def ReturnLastState(self, Timer):
        print('Script Start : ' + str(self.Timer() - Timer))
        tempData = self.Child_Pipe.recv()
        
        #self.DataHolder.Lock.acquire()
        #tempData = self.DataHolder.Return_SingleData('Sta')
        #self.DataHolder.Lock.release()
        print('Script End: ' + str(self.Timer() - Timer))
        return tempData

    def fRunProcess(self, Pipe):
        #Threads communicate with events, event is set when socket sampling is terminated
        while not self.e.is_set():
            time.sleep(0.0001)
            
            if not self.TCPHolder.Socket._closed:
                tempMsg = self.TCPHolder.ReceiveMessage()
                if len(tempMsg) > 0:
                    self.DataHolder.AppendData(tempMsg) #parse message
                    self.Child_Pipe.send(self.DataHolder.Return_SingleData('Sta'))