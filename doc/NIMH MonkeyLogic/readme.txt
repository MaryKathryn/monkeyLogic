
                      NIMH MonkeyLogic distribution

  Introduction
  ------------

  The "Oct 2014" version of MonkeyLogic which used to be released from the
  official website (http://www.brown.edu/Research/monkeylogic/) for a while
  had two main issues that prevented it from being used with the latest MATLAB:
  Lack of 64-bit MATLAB support and slow graphic performance in R2014b or later.
  NIMH DAQ Toolbox that I previously wrote solved the first problem succesfully.
  Now I release another toolbox, called MonkeyLogic Graphic Library (MGL), to
  address the second issue.  MGL has many advanced features, compared to the
  old graphic library.  See changes.txt for details.

  Unlike NIMH DAQ Toolbox, MGL cannot be released as a separate package, due to
  its tight integration with MonkeyLogic. Therefore, the MonkeyLogic
  distribution released with MGL will be called NIMH MonkeyLogic.


  Development history
  -------------------
  
  See changes.txt


  Requirements
  ------------

  - Windows 7 or later (32-bit or 64-bit)

  - MATLAB R2011a or later (32-bit or 64-bit version for Windows)

  - Visual C++ Redistributable for Visual Studio 2013
   (https://www.microsoft.com/en-us/download/details.aspx?id=40784)

  - The latest DirectX (9.0c) runtime
   (https://www.microsoft.com/en-us/download/details.aspx?displaylang=en&id=35)
   
  You may install Visual C++ Redistributable for Visual Studio 2013 included in
  this package or download from the above link. The version of the
  Redistributable package to install is dependent on your MATLAB. If your
  MATLAB is 32-bit, the 32-bit Redistributable is needed, even if your Windows
  is 64-bit.

  Your MATLAB is 32-bit --> Install VC_redist.x86.exe
  Your MATLAB is 64-bit --> Install VC_redist.x64.exe
  You have both         --> Install both x86 and x64
  
  You probably don't need to install the DirectX runtime, if the latest service
  pack is applied to your Windows. Otherwise, please update the runtime.

  If you are using high-resolution monitors with high DPI settings, you may
  see that the font and figure sizes of MATLAB decrease when NIMH MonkeyLogic
  is launched.  For old applications that do not support DPI scaling
  (R2015aSP1 or earlier versions), Windows magnifies their windows so that
  their fonts may not look small.  However, this pseudo-scaling also makes all
  graphic elements look blurry (including stimuli on the subject screen) and
  prevents the applications from detecting screen sizes correctly.  To avoid
  it, MGL turns on the DPI awareness of MATLAB so that Windows stops the
  pseudo-scaling.  If this makes fonts and figures of MATLAB uncomfortably
  small, I recommend switching to R2015b or later.  MGL does not support per-
  monitor DPI awareness in Windows 8.1 and Windows 10 yet, so do not set the
  subject and control screen monitors with different DPIs.
  
  In addition, MATLAB must be Java-enabled to use NIMH MonkeyLogic. Otherwise
  you will see an error message.


  Installation
  ------------

  Unpack the zip file wherever you like and add the main directory of NIMH
  MonkeyLogic (e.g., C:\MonkeyLogic) to the MATLAB path.  Add the main
  directory only!  The subdirectories will be added automatically when you run
  MonkeyLogic.

  Change the subject screen size as you want in the Windows display setting.
  You may want to do it before opening MATLAB, because some MATLAB versions do
  not detect the screen resolution change once they start.  NIMH MonkeyLogic
  creates the subject screen with the resolution and the refresh rate that you
  set in Windows and you don't get to choose them in the MonkeyLogic main menu
  any more.  You can still use different resolutions for the subject and
  control screens.


  Contact
  -------

  Email Jaewon for any question. (jaewon.hwang@nih.gov)
