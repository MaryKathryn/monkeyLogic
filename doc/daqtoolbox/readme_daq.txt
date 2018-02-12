
                              NIMH DAQ Toolbox

  If you are reading this document from the NIMH MonkeyLogic package, note that
  NIMH Monkeylogic is distributed with the latest NIMH DAQ Toolbox and there is
  no need of separate installation of the DAQ Toolbox.  
							  
  What is it?
  -----------
  
  NIMH DAQ Toolbox (NIMH DAQ) is a pacakge of MATLAB scripts and mex binaries
  that enable MATLAB to acquire digital samples or generate analout output
  through data acquisition hardware such as National Instruments, sound boards
  and parallel ports.  There is MATLAB's own Data Acquisition Toolbox (MATLAB
  DAQ) for this purpose already, but MATLAB DAQ does not support its legacy
  interface on 64-bit MATLAB nor in the future releases from R2016a.
  NIMH DAQ is developed to extend the legacy interface to 64-bit MATLAB and
  continue to support it so that users can keep running mission-critical MATLAB
  code written based on the legacy DAQ interface.  NIMH DAQ can also collect
  data from mouse/touchscreen and USB joysticks.
  
  NIMH DAQ includes some improvements in DAQ functions to support near-realtime
  behavior monitoring and stimulation that are required in neuroscience
  research.  For example, MonkeyLogic (a behavioral control toolbox for MATLAB,
  http://www.brown.edu/Research/monkeylogic) recommends using two DAQ boards
  to compensate long sample update intervals in MATLAB DAQ (Asaad and Eskandar,
  2008), but, with NIMH DAQ, such a dual board setting is not necessary for
  1-kHz behavior monitoring.  (See the included documents for details.)  NIMH
  DAQ also allows you to trigger waveforms multiple times without reloading
  them. (See the example scripts.)
  
  For implementation of 'winsound' and 'parallel' adapters, NIMH DAQ depends on
  PortAudio (http://www.portaudio.com/) and InpOut32
  (http://www.highrez.co.uk/downloads/inpout32/).  Currently low latency analog
  input/output is supported for NI-DAQmx only.  Do not use sound boards to do
  time-critical tasks.
  
  Asaad WF, Eskandar EN (2008) Achieving behavioral control with millisecond
  resolution in a high-level programming environment. J Neurosci Methods
  173:235-240.
	

  Development history
  -------------------
  
  See changes_daq.txt


  Requirements
  ------------
  
  - Windows 7 or later (32-bit or 64-bit)
  
  - MATLAB R2011a or later version (32-bit or 64-bit version for Windows)
 
  - Visual C++ Redistributable for Visual Studio 2013
   (https://www.microsoft.com/en-us/download/details.aspx?id=40784)
  
  - (optional) NI-DAQmx Software (https://www.ni.com/dataacquisition/nidaqmx.htm)
  
  - (optional) Sound cards
  
  - (optional) parallel ports
  
  Visual C++ Redistributable for Visual Studio 2013 is required because all mex
  files are compiled with Microsoft Visual Studio Community 2013.  If it is not
  installed, MATLAB will not recognize mex binaries included in this package.
  There are two Redistributable packages, 32-bit (x86) and 64-bit (x64).
  Choose one or both, depending on the CPU architecture that your MATLAB is
  built for (not based on your Windows version).  If your MATLAB is a 32-bit
  version, you need 32-bit Redistributable, whether your Windows is 32-bit or
  64-bit.  If you are using 64-bit Windows and want to run NIMH DAQ on both
  32-bit and 64-bit MATLAB, you need to install both Redistributable packages.
  
  Your MATLAB is 32-bit --> Install VC_redist.x86.exe
  Your MATLAB is 64-bit --> Install VC_redist.x64.exe
  You have both         --> Install both x86 and x64

  
  Installation
  ------------
  
  The zip file has a directory structure like the following.
  
  \daqtoolbox
  \daqtoolbox\+daq
  \daqtoolbox\doc       (documents)
  \daqtoolbox\examples  (example m scripts)
  \kdb                	(64-bit mex binary for MonkeyLogic)
  \prttoolbox         	(32-bit & 64-bit mex files for MonkeyLogic)

  If you are using MonkeyLogic (ML), the simplest way to install this package
  is to copy all the directories into the ML directory (merge 'kdb' and
  'prttoolbox' with the existing ones) and add 'daqtoolbox' to the MATLAB path.

  As long as 'daqtoolbox' is in the MATLAB path, its location is not important.
  However, '+daq' must be a subdirectory of 'daqtoolbox'. (You can't add '+daq'
  to the MATLAB path.)  Make it sure that 'daqtoolbox' is added above MATLAB
  DAQ, if you want it to replace MATLAB DAQ in 32-bit MATLAB.  Since NIMH DAQ
  provides the same interface as MATLAB DAQ, you may see a "class redefinition"
  error when you start ML with NIMH DAQ, due to name conflicts. Then just close
  the current MATLAB session and restart.  (The 'clear classes' command never
  worked.)

  The 'kdb' and 'prttoolbox' directories include tools that are needed to run
  MonkeyLogic (ML) on 64-bit MATLAB.  Copy (or move) them over your ML
  directory and merge with the directories that have the same names.  If you
  are not installing NIMH DAQ for ML, you can skip this part.
  
  To access 'parallel' ports, you need to install a driver by running MATLAB as
  administrator and typing the following on the MATLAB command window.
  
  daqhwinfo('parallel');
  
  If you don't see any warning when you issue the command, it means that the
  driver is succesfully installed. Then administrator privilege is no longer
  needed thereafter.
  
  
  Contact infomation
  ------------------
  
  Please email me if you have any question or suggestion.
  
  Jaewon Hwang (jaewon.hwang@nih.gov)
