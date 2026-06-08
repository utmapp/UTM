# Test Plan

## Scope
The scope of test plan is limited to the following area and platform:

| App Area |  Platform       |
|----------|-----------------|
|   UI     |  macOS          |

## Test Environment
- macOS mini
- OS: macOS Tahoe 26.3
- Tools: XCUITest

## Running Tests

### Using Xcode

1. Open the project in Xcode
2. Select the test target from the scheme selector
3. Run tests using one of these methods:
   - **All tests**: Press `⌘U` (Command + U)
   - **Single test class**: Click the diamond icon next to the class name
   - **Single test method**: Click the diamond icon next to the method name
   - **Test Navigator**: Open Test Navigator (`⌘6`) and click the play button next to any test

### Command line

```bash
# Run all tests
xcodebuild test -scheme "macOS" -destination 'platform=macOS'

# Run without code signing (useful for CI or local testing)
xcodebuild test -scheme "macOS" -destination 'platform=macOS' -only-testing:UTMUITests/VMWizardViewTest/testClickExitButton
```

## How to contribute to test cases definition
1. Create a GitHub issue for the test case and note the issue number.
2. Add a new section under **Test Cases** using the following format:

```markdown
### <short description>
- **Issue:** <link to GitHub issue>
- **Steps:** <numbered list of steps to reproduce>
- **Expected:** <what should happen>
- **Status:** <Test case status>
```
3. Make sure the description is concise and matches the issue title.
4. Steps should be specific enough for someone unfamiliar with the feature to follow.
5. Expected result should be observable and unambiguous.
6. Test case status.

## How to contribute to test case implementation

Each test case defined in **Test Cases** should be implemented as an XCUITest in Swift. Follow these steps:
1. **Locate or create the test file** — test files live in `Test/` and follow the naming convention `<FeatureArea>Test.swift`. If a suitable file exists, add your test there; otherwise create a new one.
2. **Name the test method** — use the `test_` prefix followed by a descriptive snake_case name that matches the test case title, e.g. `test_userGuideLink_navigatesToDocumentation`.
3. **Reference the issue** — add a comment above the method with the GitHub issue URL so reviewers can trace intent:
   ```swift
   // https://github.com/utmapp/UTM/issues/<number>
   func test_userGuideLink_navigatesToDocumentation() { … }
   ```
4. **Update the test case status** — once the test is merged, change **Status**.


### Example skeleton

```swift
// https://github.com/utmapp/UTM/issues/1234
func test_userGuideLink_navigatesToDocumentation() {
    let app = XCUIApplication()
    app.launch()

    app.menuItems["User Guide"].click()

    // Assert the documentation URL opened in the default browser
    // (use NSWorkspace / URL event interceptor as appropriate)
    XCTAssertTrue(/* condition */)
}
```


## Test Cases

### VM Wizard close button dismisses window
- **Issue:** NOT CREATED YET
- **File:** `Test/VMWizardViewTest.swift` — `testClickExitButton`
- **Steps:**
  1. Launch UTM
  2. Click the red close button in the top-left corner of the window
- **Expected:** The window closes
- **Status:** IMPLEMENTED

### User Guide link navigates to documentation
- **Issue:** NOT CREATED YET
- **Steps:**
  1. open UTM 
  2. click on User Guide
- **Expected:** Clicking on user guide doc is reached
- **Status:** NOT IMPLEMENTED

### Support link navigates to UTM Home website
- **Issue:** NOT CREATED YET
- **Steps:**
  1. open UTM
  2. click on Support
- **Expected:** Clicking on Support buttom UTM home page is reached
- **Status:** NOT IMPLEMENTED

### Gallery link navigate to VM Download Gallery
- **Issue:** NOT CREATED YET
- **Steps:**
  1. open UTM
  2. click on Gallery button
- **Expected:** Clicking on Gallery buttom UTM gallery page is reached
- **Status:** NOT IMPLEMENTED

### Download VM from gallery and start it
- **Issue:** NOT CREATED YET
- **Steps:**
  1. open UTM
  2. click on Download VM from UTM
  3. start it
- **Expected:** starting the VM login page is reached
- **Status:** NOT IMPLEMENTED

---

## VM Wizard — Other Boot Configuration

### Other boot step shows title "Other"
- **Issue:** NOT CREATED YET
- **File:** `Test/VMWizardViewTest.swift`
- **Steps:**
  1. Launch UTM
  2. Open the VM Wizard → Emulate → Other
- **Expected:** The large-title text "Other" is visible at the top of the wizard
- **Status:** NOT IMPLEMENTED

### Go Back from Other boot returns to OS selection
- **Issue:** NOT CREATED YET
- **File:** `Test/VMWizardViewTest.swift`
- **Steps:**
  1. Launch UTM
  2. Open the VM Wizard → Emulate → Other
  3. Click "Go Back"
- **Expected:** The wizard returns to the OS selection step
- **Status:** NOT IMPLEMENTED

---

## VM Wizard — Hardware Step

### Hardware step title "Hardware" is visible
- **Issue:** NOT CREATED YET
- **File:** `Test/VMWizardViewTest.swift`
- **Steps:**
  1. Launch UTM
  2. Open the VM Wizard → Emulate → Other → Continue
- **Expected:** The large-title text "Hardware" is visible at the top of the wizard
- **Status:** NOT IMPLEMENTED

### Hardware step shows Machine picker in normal mode
- **Issue:** NOT CREATED YET
- **File:** `Test/VMWizardViewTest.swift`
- **Steps:**
  1. Launch UTM
  2. Open the VM Wizard → Emulate → Other → Continue to Hardware
- **Expected:** A "Machine" inline picker with hardware options is visible
- **Status:** NOT IMPLEMENTED

### Hardware step shows Memory section
- **Issue:** NOT CREATED YET
- **File:** `Test/VMWizardViewTest.swift`
- **Steps:**
  1. Launch UTM
  2. Open the VM Wizard → Emulate → Other → Continue to Hardware
- **Expected:** A "Memory" section header and RAM slider are visible
- **Status:** NOT IMPLEMENTED

### Hardware step shows Expert Mode toggle when emulating
- **Issue:** NOT CREATED YET
- **File:** `Test/VMWizardViewTest.swift`
- **Steps:**
  1. Launch UTM
  2. Open the VM Wizard → Emulate → Other → Continue to Hardware
- **Expected:** An "Expert Mode" toggle is visible on the Hardware step when using emulation
- **Status:** NOT IMPLEMENTED

### Go Back from Hardware returns to boot configuration
- **Issue:** NOT CREATED YET
- **File:** `Test/VMWizardViewTest.swift`
- **Steps:**
  1. Launch UTM
  2. Open the VM Wizard → Emulate → Other → Continue to Hardware
  3. Click "Go Back"
- **Expected:** The wizard returns to the Other boot configuration step
- **Status:** NOT IMPLEMENTED

---

## VM Wizard — Drives Step

### Storage step title "Storage" is visible
- **Issue:** NOT CREATED YET
- **File:** `Test/VMWizardViewTest.swift`
- **Steps:**
  1. Launch UTM
  2. Navigate the VM Wizard through Emulate → Other → Hardware → Continue
- **Expected:** The large-title text "Storage" is visible at the top of the wizard (VMWizardDrivesView renders VMWizardContent("Storage"))
- **Status:** NOT IMPLEMENTED

### Continue from Hardware advances to Storage step
- **Issue:** NOT CREATED YET
- **File:** `Test/VMWizardViewTest.swift`
- **Steps:**
  1. Launch UTM
  2. Open the VM Wizard → Emulate → Other → Hardware
  3. Click "Continue"
- **Expected:** The wizard advances to the Storage step showing a "Size" section with a GiB input field
- **Status:** NOT IMPLEMENTED

### Go Back from Storage returns to Hardware step
- **Issue:** NOT CREATED YET
- **File:** `Test/VMWizardViewTest.swift`
- **Steps:**
  1. Launch UTM
  2. Navigate to the Storage step
  3. Click "Go Back"
- **Expected:** The wizard returns to the Hardware step and "Memory" section is visible again
- **Status:** NOT IMPLEMENTED

---

## VM Wizard — Sharing Step

### Sharing step title "Sharing" is visible
- **Issue:** NOT CREATED YET
- **File:** `Test/VMWizardViewTest.swift`
- **Steps:**
  1. Launch UTM
  2. Navigate the VM Wizard to the Sharing step (Emulate → Other → Hardware → Drives → Continue)
- **Expected:** The large-title text "Sharing" is visible at the top of the wizard
- **Status:** NOT IMPLEMENTED

### Go Back from Sharing returns to Storage step
- **Issue:** NOT CREATED YET
- **File:** `Test/VMWizardViewTest.swift`
- **Steps:**
  1. Launch UTM
  2. Navigate to the Sharing step
  3. Click "Go Back"
- **Expected:** The wizard returns to the Storage step
- **Status:** NOT IMPLEMENTED

---

## Window Controls

### Minimize button minimizes the main window
- **Issue:** NOT CREATED YET
- **File:** `Test/WindowControlsTest.swift`
- **Steps:**
  1. Launch UTM
  2. Click the yellow minimize button in the top-left corner
- **Expected:** The main window is minimized to the Dock
- **Status:** NOT IMPLEMENTED

### Zoom button resizes the main window
- **Issue:** NOT CREATED YET
- **File:** `Test/WindowControlsTest.swift`
- **Steps:**
  1. Launch UTM
  2. Click the green zoom button in the top-left corner
- **Expected:** The window resizes (enters or exits full-size mode)
- **Status:** NOT IMPLEMENTED

### What's New view is shown via Help menu
- **Issue:** NOT CREATED YET
- **File:** `Test/MenuBarTest.swift`
- **Steps:**
  1. Launch UTM
  2. Click Help > What's New
- **Expected:** A release notes view appears within the app
- **Status:** NOT IMPLEMENTED

---

## End-to-End Flows

> **Pre-condition note:** E2E tests run against a clean UTM install with no existing VMs unless otherwise stated. Tests that start or stop a VM require a suitable guest image (ISO or kernel) to be available on the test machine and referenced in the **Pre-condition** field.

### [E2E] Full wizard creates a VM visible in the sidebar
- **Issue:** NOT CREATED YET
- **File:** `Test/VMLifecycleTest.swift`
- **Pre-condition:** Clean UTM install, no existing VMs
- **Steps:**
  1. Launch UTM
  2. Click "Create a New Virtual Machine"
  3. Click "Emulate" → select "Other" → click "Continue" through Hardware, Storage, Sharing steps
  4. On Summary, note the auto-generated VM name then click "Save"
- **Expected:** The wizard closes, the new VM entry appears in the sidebar list with the name shown on the Summary step, and the details panel shows "Status: Stopped"
- **Status:** NOT IMPLEMENTED

### [E2E] Create a VM then delete it restores the empty state
- **Issue:** NOT CREATED YET
- **File:** `Test/VMLifecycleTest.swift`
- **Pre-condition:** One VM already created (can reuse result of the previous E2E test)
- **Steps:**
  1. Launch UTM with one VM in the list
  2. Select the VM in the sidebar
  3. Click the "Delete" (trash) button in the details toolbar
  4. In the confirmation alert "Do you want to delete this VM and all its data?", click "Delete"
- **Expected:** The VM is removed from the sidebar list, the welcome placeholder screen is shown again
- **Status:** NOT IMPLEMENTED

### [E2E] Create a VM then clone it produces two entries in the sidebar
- **Issue:** NOT CREATED YET
- **File:** `Test/VMLifecycleTest.swift`
- **Pre-condition:** One VM already created
- **Steps:**
  1. Launch UTM with one VM in the sidebar
  2. Right-click the VM card → "Clone…"
  3. In the confirmation alert "Do you want to duplicate this VM and all its data?", click "Yes"
- **Expected:** A second VM entry appears in the sidebar. Both VMs are visible and show "Status: Stopped". The clone's name differs from the original (appended copy indicator)
- **Status:** NOT IMPLEMENTED

### [E2E] Create a VM then rename it via Settings and verify the new name in the sidebar
- **Issue:** NOT CREATED YET
- **File:** `Test/VMLifecycleTest.swift`
- **Pre-condition:** One VM already created
- **Steps:**
  1. Launch UTM with one VM in the sidebar
  2. Select the VM, click the "Edit" button in the details toolbar
  3. In the Settings sheet, navigate to "Information"
  4. Clear the Name field and type "RenamedVM"
  5. Click "Save"
- **Expected:** The Settings sheet closes, the VM entry in the sidebar now shows "RenamedVM"
- **Status:** NOT IMPLEMENTED

### [E2E] Edit VM settings then cancel discards changes
- **Issue:** NOT CREATED YET
- **File:** `Test/VMLifecycleTest.swift`
- **Pre-condition:** One VM already created with a known name
- **Steps:**
  1. Launch UTM with one VM in the sidebar
  2. Select the VM, click the "Edit" button in the details toolbar
  3. In the Settings sheet, navigate to "Information" and change the Name field
  4. Click "Cancel"
- **Expected:** The Settings sheet closes, the VM name in the sidebar is unchanged
- **Status:** NOT IMPLEMENTED

### [E2E] Delete VM via context menu shows confirmation dialog
- **Issue:** NOT CREATED YET
- **File:** `Test/VMLifecycleTest.swift`
- **Pre-condition:** One VM already created
- **Steps:**
  1. Launch UTM with one VM in the sidebar
  2. Right-click the VM card → "Delete"
- **Expected:** A confirmation alert appears with the message "Do you want to delete this VM and all its data?" and buttons "Cancel" and "Delete"
- **Status:** NOT IMPLEMENTED

### [E2E] Cancelling VM deletion confirmation keeps the VM in the list
- **Issue:** NOT CREATED YET
- **File:** `Test/VMLifecycleTest.swift`
- **Pre-condition:** One VM already created
- **Steps:**
  1. Launch UTM with one VM in the sidebar
  2. Right-click the VM card → "Delete"
  3. In the confirmation alert, click "Cancel"
- **Expected:** The alert dismisses, the VM remains in the sidebar list unchanged
- **Status:** NOT IMPLEMENTED

### [E2E] Right-click context menu shows all expected actions
- **Issue:** NOT CREATED YET
- **File:** `Test/VMLifecycleTest.swift`
- **Pre-condition:** One VM already created and in Stopped state
- **Steps:**
  1. Launch UTM with one stopped VM in the sidebar
  2. Right-click the VM card
- **Expected:** The context menu shows: "Show in Finder", "Edit", "Run", "Run without saving changes", "Share…", "Move…", "Clone…", "New from template…", "Delete"
- **Status:** NOT IMPLEMENTED

### [E2E] "Show in Finder" context menu action opens Finder at the VM bundle
- **Issue:** NOT CREATED YET
- **File:** `Test/VMLifecycleTest.swift`
- **Pre-condition:** One VM already created
- **Steps:**
  1. Launch UTM with one VM in the sidebar
  2. Right-click the VM card → "Show in Finder"
- **Expected:** Finder opens and the .utm bundle file is highlighted/selected
- **Status:** NOT IMPLEMENTED

### [E2E] Run VM from details toolbar opens a VM display window
- **Issue:** NOT CREATED YET
- **File:** `Test/VMLifecycleTest.swift`
- **Pre-condition:** One QEMU VM with a valid bootable image attached
- **Steps:**
  1. Launch UTM with a bootable VM in the sidebar
  2. Select the VM
  3. Click the "Run" button in the details toolbar (or click the play button on the screenshot area)
- **Expected:** A separate VM display window opens; the VM status in the sidebar changes from "Stopped" to "Started"
- **Status:** NOT IMPLEMENTED

### [E2E] Stop a running VM via context menu returns it to stopped state
- **Issue:** NOT CREATED YET
- **File:** `Test/VMLifecycleTest.swift`
- **Pre-condition:** One VM currently in "Started" state
- **Steps:**
  1. Launch UTM with a running VM
  2. Right-click the VM card → "Stop"
  3. In the confirmation alert "Do you want to force stop this VM and lose all unsaved data?", click "Stop"
- **Expected:** The VM display window closes (or becomes inactive), the VM status in the sidebar returns to "Stopped"
- **Status:** NOT IMPLEMENTED

### [E2E] "Run without saving changes" starts VM in disposable mode
- **Issue:** NOT CREATED YET
- **File:** `Test/VMLifecycleTest.swift`
- **Pre-condition:** One QEMU VM with a valid bootable image attached
- **Steps:**
  1. Launch UTM with a bootable QEMU VM
  2. Right-click the VM card → "Run without saving changes"
- **Expected:** The VM starts and a display window opens; disk writes are not persisted when the VM is stopped
- **Status:** NOT IMPLEMENTED

### [E2E] Create two VMs and reorder them by dragging in the sidebar
- **Issue:** NOT CREATED YET
- **File:** `Test/VMLifecycleTest.swift`
- **Pre-condition:** Two VMs already created (VM-A and VM-B, in that order)
- **Steps:**
  1. Launch UTM with two VMs listed as VM-A (first) and VM-B (second)
  2. Drag VM-B above VM-A in the sidebar list
- **Expected:** VM-B now appears first and VM-A appears second in the sidebar list; the new order persists after the drag
- **Status:** NOT IMPLEMENTED

### [E2E] Import a VM via File > Open adds it to the sidebar
- **Issue:** NOT CREATED YET
- **File:** `Test/VMLifecycleTest.swift`
- **Pre-condition:** A valid .utm bundle exists on the local filesystem
- **Steps:**
  1. Launch UTM with no VMs
  2. Click File > Open… (⌘O)
  3. In the file picker, navigate to and select a .utm bundle, then click Open
- **Expected:** The file picker closes and the imported VM appears in the sidebar list
- **Status:** NOT IMPLEMENTED

### [E2E] VM details panel shows correct metadata after creation
- **Issue:** NOT CREATED YET
- **File:** `Test/VMLifecycleTest.swift`
- **Pre-condition:** Clean UTM install
- **Steps:**
  1. Launch UTM
  2. Create a new VM via the wizard using Emulate → Other → x86_64 architecture → 2 GiB RAM → Save
  3. Select the newly created VM in the sidebar
- **Expected:** The details panel shows: Status "Stopped", Architecture matching the wizard selection, Memory matching the RAM set in the wizard, a non-zero disk Size
- **Status:** NOT IMPLEMENTED
