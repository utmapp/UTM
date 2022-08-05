---
name: macOS issue
about: Report an issue or crash for macOS
title: ''
labels: ''
assignees: ''

---

**BEFORE SUBMITTING YOUR ISSUE, PLEASE LOOK AT THE PINNED ISSUES AND USE THE SEARCH FUNCTION TO MAKE SURE IT IS NOT ALREADY REPORTED. ALWAYS COMMENT ON AN EXISTING ISSUE INSTEAD OF MAKING A NEW ONE.**

**Describe the issue**  
Replace this text with a clear and concise description of what the issue is.

**Configuration**  
* UTM Version: 
* macOS Version: 
* Mac Chip (Intel, M1, ...): 

**Crash log**  
If the app crashed, you need a crash log. To get your crash log, open Console.app, go to `Crash Reports`, and find the latest entry for either UTM, QEMU, QEMUHelper, or qemu-\*. Right click and choose `Reveal in Finder`. Attach the report here.

**Debug log**  
For all issues related to running a VM, _including_ crashes, you should attach a debug log. (This is unavailable for macOS-on-macOS VMs. Attach an excerpt of your system log instead.)
To get the Debug log: open UTM, and open the settings for the VM you wish to launch. Near the top of the `QEMU` page is `Debug Log`. Turn it on and save the VM. After you experience the issue, open the VM settings again and select `Export Log...` and attach it here.

**Upload VM**  
If your issue is related to a specific VM, please upload the config.plist from your VM's .utm directory. To get this, right-click the VM in UTM and choose "Show in Finder". Then right-click the selected file in Finder and choose "Show Package Contents". The config.plist file is now visible. Right-click it and choose "Compress". Attach the resulting config.plist.zip file here.
You can upload the entire .utm if needed, but note this includes your VM's drive image and may contain personal data. Since Github has an attachment size limit, you may want to upload to another service such as Google Drive. Link it here.
