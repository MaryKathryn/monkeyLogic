function vendorInfo = getVendors()

hw = daqhwinfo;
[~,~,~,vendorInfo] = mdqmex(51,hw.InstalledAdaptors{1}); %#ok<*AGROW>
vendorInfo.AdaptorVersion = hw.ToolboxVersion;
