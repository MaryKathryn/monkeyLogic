import socket
from timeit import default_timer as timer

class ML_MatlabTcpTunnel():
    def __init__(self, Address, Port, BuffSize, InTerminator, OutTerminator, TimeOut): 
        self.Address = Address
        self.Port = Port 
        self.BuffSize = BuffSize
        self.InTerminator = InTerminator #wait for exp in data to stop acquisition
        self.OutTerminator = OutTerminator #adds at the end of output string
        self.TimeOut = TimeOut
        self.Socket = None
        
    def Connect(self):
        socket.setdefaulttimeout(self.TimeOut)
        self.Socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

        #Connects to server
        connectError = self.Socket.connect_ex((self.Address, self.Port))
        if (connectError==0):
            return True
        else:
            return False


    def SendMessage(self, Message):
        Message = Message + self.OutTerminator
        sent = self.Socket.send(Message.encode('utf-8'))
        return True

    def ReceiveMessage(self):
        Message = '' 
        tempMessage = self.Socket.recv(self.BuffSize)
        Message = tempMessage.decode('utf-8')
        
        while self.InTerminator not in Message:
            tempMessage = self.Socket.recv(self.BuffSize)    
            Message += tempMessage.decode('utf-8')
        
        return Message.replace(self.InTerminator, '')

    def Close(self):
        self.Socket.close()

    def TimingTest(self):
        start = timer()

        self.SendMessage('GETPLAYERINFOS')

        out = self.ReceiveMessage()

        end = timer()
        return (end - start)

