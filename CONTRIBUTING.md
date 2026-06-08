## Getting Started
Read the [documentation](Documentation) pages to familiarize yourself with the codebase and development environment. The [issues tracker](https://github.com/utmapp/UTM/issues) contains outstanding issues. Look for the "help wanted" and "good first issue" tags for any issues that a maintainer selected for attention. We also maintain a higher level [ideas page](https://github.com/utmapp/UTM/wiki/Project-Ideas) for larger tasks that are planned.

You can join our [Discord](https://discord.gg/UV2RUgD) to converse directly with maintainers. We strongly recommend talking with other developers before attempting to tackle a large issue.

## Style Guide
Most of the codebase is in Swift and should follow [Swift API design guidelines](https://www.swift.org/documentation/api-design-guidelines/). For older Objective-C code, we follow the [Coding Guidelines for Cocoa](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CodingGuidelines/CodingGuidelines.html) which is important for seamless Swift interoperability (pay special attention to [naming conventions](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CodingGuidelines/Articles/NamingMethods.html)).

We use Swift Concurrency extensively and adopt the async variants of APIs where possible. To keep things simple, we keep most UI related logic in @MainActor.

When committing changes use the title "component: short description" where "component" is the main component you are modifying. Make sure to detail in the commit the reasoning for the change and reference the bug that you are trying to resolve.

## Design Philosophy
- Prefer simplicity over options: it can be intimating to see a wall of options when using a program for the first time. When you are tempted to add a new setting, option, configuration, or anything that requires user input ask the following question: will the majority of users need to touch this option? If the answer is no, consider choosing a safe default, putting it somewhere that is not immediately visible (e.g. menu bar or scripting interface), or even not implementing the feature at all. Avoid prompting the user for a choice unless absolutely needed.
- Avoid jargon, acronyms, and technical terms: things should be as clear as possible for most users. You can assume the user has basic technical knowledge but may not know what "JIT" means or why they should choose "Vulkan" over "OpenGL." On macOS you can use the .hint() qualifier to show tooltips to explain a field or control, but do not overly rely on this. Be descriptive: "SATA Drive" is preferred over just "SATA". Do not assume the technology name is known to the user: e.g. "GPU Acceleration" is preferred over "Venus Support". Since we are on Apple platforms, we also use Apple marketing terms over the technology name when possible: e.g. "Retina" over "HiDPI" and "Apple Silicon" over ARM64 (when referring to the host machine).
- Use standard technology when possible: UTM is built on shoulders of giants (QEMU, SPICE, etc). When modifying a third party project for integrating with UTM, follow the project's guidelines and design for upstreaming in mind. 
- Backwards compatibility: Currently we support iOS 14+ and macOS 11.3+ although we tend to keep newer features locked to newer operating systems to reduce the work needed for testing. One challenge currently is that SwiftUI on macOS 11 is extremely buggy. Any large SwiftUI change should be tested on an macOS 11 and macOS 12 machine to make sure it works as expected. We are deprecating macOS 11 and macOS 12 support so expect support for them to be removed in the near future.

## Dependency Projects
UTM is built on top of several open source projects such as QEMU and SPICE. All changes to dependent projects should be made with the intention of upstreaming. That means following the style and convention of the project. We maintain a [fork of QEMU](https://github.com/utmapp/qemu) with changes that have been either rejected upstream or picked up downstream from mainline. Every so often, we will merge the latest QEMU release into the fork.

Dependencies are always fetched from the upstream source release tar and patched with UTM changes. These patches are maintained in the UTM repository as long as they are not in the upstream release (after which, they are deleted). The exception is QEMU, which we base the patches off the latest release of the UTM fork.

The [development documentation](Documentation/iOSDevelopment.md) contains steps for building the dependencies.

## AI Contribution Guidelines
We support contributions that are AI assisted but they must follow the following additional rules:

1. Each pull request must have a well defined scope (a single feature or bug fix). Do not submit large PRs containing multiple features/bug fixes.
2. The attribution policy below is followed.
3. **AI written code must be tested by a human before opening a PR. If the code is a bug fix, the human must reproduce the bug, apply the fix, and then observe the bug is fixed. If the code is a feature or change, the human must test the feature. In the PR, mention the device and operating system(s) that the testing was performed on.**
4. Do not touch unrelated files. Do not refactor unrelated code. Do not change headers/whitespace in unrelated files. Do not add logging to unrelated files.
5. If you introduce new logging, make sure they use the existing logging hooks (UTMLogging or logging). Give the log entries debug level unless they are errors or warnings. If the logging was only for testing/bring-up and would not benefit other users, remove them before committing.
6. On supported AI coding tools, use the `/utm-review` and `/utm-submit` skills to create the pull request. This ensures that all the guidelines are followed. If you chose to submit the PR manually, you must include the following statement: "I have read the AI contribution guidelines and have followed them to the best of my ability."

### Attribution
We use the same attribution policy as the Linux Kernel. When AI tools contribute to development, proper attribution helps track the evolving role of AI in the development process. Note we do NOT use `Co-authored-by` and all commits should remove `Co-authored-by` that a tool might add automatically. This is to ensure tha humans take full responsibility for all code that is written.

Contributions should include an Assisted-by tag in the following format:

```
Assisted-by: AGENT_NAME:MODEL_VERSION [TOOL1] [TOOL2]
```

Where:

* `AGENT_NAME` is the name of the AI tool or framework
* `MODEL_VERSION` is the specific model version used
* `[TOOL1] [TOOL2]` are optional specialized analysis tools used
  (e.g., coccinelle, sparse, smatch, clang-tidy)

Basic development tools (git, gcc, make, editors) should not be listed.

Example:

```
Assisted-by: Claude:claude-3-opus coccinelle sparse
```
