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

