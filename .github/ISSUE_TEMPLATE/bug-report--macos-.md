---
name: macOS issue
about: Report an issue or crash for macOS
title: ''
labels: ''
assignees: ''

---

**Describe the issue**
A clear and concise description of what the issue is. **BEFORE SUBMITTING YOUR ISSUE, PLEASE LOOK AT THE PINNED ISSUES AND USE THE SEARCH FUNCTION TO MAKE SURE IT IS NOT ALREADY REPORTED. ALWAYS COMMENT ON AN EXISTING ISSUE INSTEAD OF MAKING A NEW ONE.**

**Configuration**
* UTM Version: 
* OS Version: 
* Intel or Apple Silicon? 

**Crash log**
If the app crashed, you need a crash log. To get your crash log, open Console.app, go to `Crash Reports`, and find the latest entry for either QEMU, QEMUHelper, or qemu-\*. Right click and choose `Reveal in Finder`. Attach the report here.

**Debug log**
For all issues, _including_ crashes, you should attach a debug log. Open UTM, and open the settings for the VM you wish to launch. Near the top of the `QEMU` page is `Debug Log`. Turn it on and save the VM. After you experience the issue, open the VM settings again and select `Export Log...` and attach it here.

**Upload VM**
(Optional) If possible, upload the `config.plist` inside the `.utm`. If you do not have this, you can upload the entire `.utm` but note this contains your personal data. Since Github has an attachment size limit, you may want to upload to another service such as Google Drive. Link it here.
