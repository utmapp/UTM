# Testing Guide

This document explains how to run tests and extend the test suite for the VM Wizard application.

## Table of Contents

- [Running Tests](#running-tests)
- [Test Structure](#test-structure)
- [Extending Tests](#extending-tests)
- [Best Practices](#best-practices)

## Running Tests

### Using Xcode

1. Open the project in Xcode
2. Select the test target from the scheme selector
3. Run tests using one of these methods:
   - **All tests**: Press `⌘U` (Command + U)
   - **Single test class**: Click the diamond icon next to the class name
   - **Single test method**: Click the diamond icon next to the method name
   - **Test Navigator**: Open Test Navigator (`⌘6`) and click the play button next to any test

### Using Command Line

```bash
# Run all tests
xcodebuild test -scheme "macOS" -destination 'platform=macOS'

# Run without code signing (useful for CI or local testing)
xcodebuild test -scheme "macOS" -destination 'platform=macOS' -only-testing:UTMUITests/VMWizardViewTest/testClickExitButton
```

## Test Structure

### Current Test Suite

The test suite currently includes:

- **VMWizardViewTest**: UI tests for the VM Wizard interface
  - `testClickExitButton()`: Tests the window close button functionality

### Test Organization

```
UTMUITests/
├── VMWizardViewTest.swift    # UI tests for VM Wizard
└── TESTING.md                # This file
```

## Extending Tests

### 1. Adding a New Test Method

To add a new test to an existing test class:

```swift
@MainActor
func testYourNewTest() throws {
    // 1. Launch the application
    let app = XCUIApplication()
    app.launch()
    
    // 2. Wait for UI elements
    let window = app.windows.firstMatch
    XCTAssertTrue(window.waitForExistence(timeout: 5))
    
    // 3. Interact with UI elements
    let button = app.buttons["ButtonName"]
    button.click()
    
    // 4. Assert expected results
    XCTAssertTrue(someCondition, "Description of what should happen")
}
```

### 2. Creating a New Test Class

Create a new test file that inherits from `XCTestCase`:

```swift
import XCTest

final class YourNewTestClass: XCTestCase {
    
    override func setUpWithError() throws {
        continueAfterFailure = false
    }
    
    override func tearDownWithError() throws {
        // Cleanup code
    }
    
    @MainActor
    func testSomething() throws {
        // Your test code
    }
}
```

## Best Practices

### 1. Test Naming

- Use descriptive names that explain what is being tested
- Prefix with `test` (required by XCTest)
- Format: `test<WhatIsBeingTested><ExpectedOutcome>`
- Example: `testClickExitButton`, `testNavigateToHardwarePage`


## Additional Resources

- [Apple's XCTest Documentation](https://developer.apple.com/documentation/xctest)
- [UI Testing in Xcode](https://developer.apple.com/library/archive/documentation/DeveloperTools/Conceptual/testing_with_xcode/)
- [XCUI Element Query Reference](https://developer.apple.com/documentation/xctest/xcuielementquery)

## Contributing

When adding new tests:

1. Follow the existing code style and patterns
2. Add appropriate documentation comments
3. Ensure tests pass consistently
4. Update this README if adding new testing patterns or utilities
5. Consider adding helper methods for commonly repeated operations

---

**Last Updated**: February 2026

