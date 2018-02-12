import socket
import threading
import re
from timeit import default_timer as timer

global TCPHolder = None

 #define subclass for TCP socket holder
class subTCPHolder():
    def __init__(self, Address, Port, BuffSize, InTerminator, OutTerminator, TimeOut):
        #TCP vars =========================================================================
        self.Address = Address
        self.Port = Port 
        self.BuffSize = BuffSize
        self.InTerminator = InTerminator #wait for exp in data to stop acquisition
        self.OutTerminator = OutTerminator #adds at the end of output string
        self.TimeOut = TimeOut 
        self.Socket = None #socket holder

class ML_MatlabTcpTunnel_V2():
   
    def __init__(self, Address, Port, BuffSize, InTerminator, OutTerminator, TimeOut): 
        self.TCPHolder = subTCPHolder(Address, Port, BuffSize, InTerminator, OutTerminator, TimeOut)

        #Defines class variables ===========================================================
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

        #Trial variables
        self.SOT = timer() #Start Of Trial time; inits to creation time, reset on each trial

        # Threading to check TCP socket
        self.Thread = None #Running Thread
        self.e = threading.Event() #declaration of event being passed across threads

        #Other
        self.Timer = timer; #self explanatory
        self.reProg = re.compile('^(PlayerInfos&&PlayerPosition#)(?P<Pos>.*)(&&PlayerRotation#)(?P<Rot>.*)(&&SampleTimes#)(?P<ST>.*)(&&PlayerState#)(?P<Sta>.*)(&&QueryTime#)(?P<QT>\d{1,}\:\d{1,}\:\d{1,}\.\d{1,})(\r\n)*') # reg exp to split UE data
    
    #Initialize connection to UE  
    def Connect(self):
        #Creates socket object
        socket.setdefaulttimeout(self.TimeOut)
        self.Socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        
        #Connects to server
        connectError = self.Socket.connect_ex((self.Address, self.Port))
        if (connectError==0):
            self.Socket.setblocking(0)
            #Starts thread to read socket
            self.e.clear()
            self.Thread = threading.Thread(target = self.Read_Socket, args=())
            self.Thread.start()
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
        self.e.set()
        self.Socket.close()
        self.Socket = None
        
    #Trial Timer start
    def Init_Timer(self):
        #since we can have data in the buffer, we will compute negative time from the new SOT
        oldSOT = self.SOT
        self.SOT = self.Timer()
        if len(self.SampleTime) > 0:
            self.SampleTime[:] = [ (((x /1000) - self.SOT + oldSOT )*1000) for x in self.SampleTime]
        
    
    def ReturnAllBuffers(self):
        return self.Pos_Buffer, self.Rot_Buffer, self.Sta_Buffer, self.ST_Buffer, self.QT_Buffer, self.SampleTime, self.E_Buffer, self.E_SampleTime
        
    def ReturnSingleData(self, Buffer, tempTimer):
        print(self.Timer() - tempTimer)
        if Buffer == 'Pos': # Position buffer
            if len(self.Pos_Buffer) > 0:
                return self.Pos_Buffer[-1]
        elif Buffer == 'Rot': # Rotation buffer
            if len(self.Rot_Buffer) > 0:
                return self.Rot_Buffer[-1]
        elif Buffer == 'Sta': # Player State buffer
            if len(self.Sta_Buffer) > 0:
                print(self.Timer() - tempTimer)
                return self.Sta_Buffer[-1]
        elif Buffer == 'UST': # Unreal Sample Times buffer
            if len(self.ST_Buffer) > 0:
                return self.ST_Buffer[-1]
        elif Buffer == 'QT': # Unreal Query Time buffer
            if len(self.QT_Buffer) > 0:
                return self.QT_Buffer[-1]
        elif Buffer == 'PST': # Python sample time buffer
            if len(self.SampleTime) > 0:
                return self.SampleTime[-1]
        elif Buffer == 'E':  # Error buffer
            if len(self.E_Buffer) > 0:
                return self.E_Buffer[-1]
        elif Buffer == 'ET': # Error Times buffer
            if len(self.E_SampleTime) > 0:
                return self.E_SampleTime[-1]
        else:
            return 'Empty'

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

    def Read_Socket(self):
        
        #Since the thread is running at maximum speed, it saturates the global scope so 
        #we will define a thread specific Receive function
        def Thread_Receive(self):
            Message = '' 
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
        
        #Threads communicate with events, event is set when socket sampling is terminated
        while not self.e.is_set():
            
            #creates a short pause
            #WaitTime = self.Timer()+0.01
            #while self.Timer() < WaitTime:
            #    do = 'nothing'
                
            #Sometimes pools between socket being closed and event being set
            if not self.Socket._closed:
                tempMsg = Thread_Receive(self)
                if len(tempMsg) > 0:
                    #parse message
                    tempSplit = self.reProg.match(tempMsg)
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
                        self.E_Buffer.append(tempMsg)
       
                