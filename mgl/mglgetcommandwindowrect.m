function rect = mglgetcommandwindowrect()

desktop = com.mathworks.mde.desk.MLDesktop.getInstance;
mainframe = desktop.getMainFrame;

rect = [mainframe.getX mainframe.getY mainframe.getX+mainframe.getWidth mainframe.getY+mainframe.getHeight];
