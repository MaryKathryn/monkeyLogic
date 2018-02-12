import os
import time

class Tunnel_test():

    def __init__(self):

        os.chdir('D:\\ML_UE4_Project\\MonkeyLogic\\TCP\\')
        import ML_MatlabTcpTunnel_V3 as f 
        Conn = f.ML_MatlabTcpTunnel_V3('localhost', 3000, 2**16, ' END OF TRANSMISSION', '\r\n', 1.00)
        Conn.Connect()
        for x in range (10):
            time.sleep(0.05)
            start = Conn.Timer()
            Conn.ReturnLastState(start)
            print('Total time: ' + str(Conn.Timer()-start))

