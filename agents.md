# App Check - Agent Workflow Instructions

The goal of this document is to ensure high-quality, reproducible, and
verifiable contributions in a fully autonomous loop for the App Check
repository.

---

## 📥 Input Requirements

Before starting any work, the agent must require or acquire:
1.  **Feature Specification**: A detailed description of the feature, bug, or
    task.
2.  **Project Configuration**: Access to necessary credentials or configurations
    if applicable.
3.  **External Scripts**: Access to the `firebase-ios-sdk` scripts. If not using
    the cloned scripts via `./setup-scripts.sh`, ensure they are available in a
    local clone of `firebase-ios-sdk` (commonly at
    `<path_to_firebase_ios_sdk>/scripts` but path may vary). If the path is not
    found, ask the human for it.

## 📤 Output Requirements

A successful task completion MUST produce:
1.  **Code Changes**: The implemented feature or fix and corresponding tests.
2.  **Unit & Integration Tests**: Demonstrating success and handling edge cases.
3.  **Implementation Plan** (For complex tasks only): A scannable proposal
    before starting work.
4.  **Walkthrough Artifact**: A summary containing verification results and
    reproduction snippets.

---

## 💬 Communication Guidelines

When reporting back to the user, prioritize scannability and clarity:
1.  **Use Categorized Bullet Points**: Group findings and results into clear categories (e.g., "Build & Test Results", "Code Changes").
2.  **Use Indicators**: Prefix status updates with checkmarks (✅) or caution symbols (⚠️) for immediate visual parsing.
3.  **Be Concise**: Avoid conversational filler. Get straight to the results and next steps.

---

## 🔄 The Agentic Loop: Step-by-Step

### Step 0: Workflow Selection & Planning (Hybrid Approach)
- **Prerequisite**: Verify that external scripts are accessible or that
  `./setup-scripts.sh` has been run to link them. If you cannot find them, ask
  the human for the path to the `firebase-ios-sdk` repository.
- **Action**: Assess the complexity of the task.
    - **Simple Task**: Proceed directly to **Step 1: TDD**.
    - **Complex Task**: Create a highly scannable **Implementation Plan** and
      get human approval.
- **Plan Requirements (Highly Scannable)**:
    - Keep it brief and hit key points.
    - Use bullet points for readability.
    - Focus on *what* changes and *why*, avoiding detailed *how*.
    - Highlight any open questions or design decisions requiring human input.

### Step 1: Test-Driven Development (TDD)
- **Constraint**: You MUST write tests before writing implementation code.
- **Action**:
    1. Write a failing unit or integration test asserting the new behavior.
    2. Verify it fails by running the appropriate test command.

### Step 2: Implementation
- Implement the feature or fix.
- Follow project conventions and guidelines if available.

### Step 3: Verification
- **Action**: Run tests using the cloned scripts or by referencing the external
  ones (e.g., in `<path_to_firebase_ios_sdk>`).
- **Iteration Workflow**: To get into a faster iterative loop, use the external
  scripts directly if possible. Set an environment variable like
  `FIREBASE_IOS_SDK_PATH` if your path differs from the default
  `<path_to_firebase_ios_sdk>`.
  - To bypass the CI secret check in `check_secrets.sh` when running external
    scripts in a trusted environment, export `FIREBASECI_IS_TRUSTED_ENV="true"`.
- **Commands**:
    - **Primary (Fast Iteration)**: For SPM testing (which uses `xcodebuild`
      under the hood):
      `${FIREBASE_IOS_SDK_PATH:-<path_to_firebase_ios_sdk>}/scripts/build.sh AppCheck <platform> spm`
      (where `<platform>` is `iOS`, `tvOS`, `macOS`, or `catalyst`).
    - For CocoaPods linting:
      `${FIREBASE_IOS_SDK_PATH:-<path_to_firebase_ios_sdk>}/scripts/pod_lib_lint.rb AppCheckCore.podspec --platforms=ios`
      (or other platforms: `tvos`, `macos --skip-tests`, `watchos`).
    - Alternatively, run `./setup-scripts.sh` to clone scripts locally and use
      `scripts/pod_lib_lint.rb`.
    - For Catalyst testing:
      `${FIREBASE_IOS_SDK_PATH:-<path_to_firebase_ios_sdk>}/scripts/test_catalyst.sh AppCheckCore test`.
- **xcodebuild Iteration**: For direct `xcodebuild` invocations, follow the
  order: `build`, `build-for-testing`, then `test`. This allows for faster
  iteration.

### Step 4: Public API Visibility
- **Requirement**: Identify and report any new public APIs created.
- **Method**: Check for changes in public headers or symbols.

---

## 🏆 Quality Gates & Best Practices

- **Error Handling**: Test edge cases and error paths.
- **Code Style**: You MUST run `<path_to_firebase_ios_sdk>/scripts/style.sh` to
  maintain consistency. Since style changes are non-functional, you do NOT need
  to re-run tests after applying style fixes.
- **No Hardcoded Secrets**: Ensure no secrets are committed.
- **Code Reuse & Refactoring**: Prioritize understanding existing structures
  to reuse or extend them with minor refactors rather than adding redundant
  code.

---

## ✅ Pre-Commit Checklist
- [ ] **Unit Tests**: Passed all unit tests.
- [ ] **Integration Tests**: Passed all integration tests.
- [ ] **Style Applied**: Verified code style if applicable.
- [ ] **Concurrency**: Verified that the changes do not introduce potential
  race conditions or deadlocks.
- [ ] **Memory Management**: Ensured no retain cycles or memory leaks are
  introduced.

---

## 📦 Git & Commits

- **Commit Often**: Pause and commit work frequently.
- **Scope**: Optimize for smaller commits that represent a complete piece of work
  or a specific milestone within a larger task.
- **Convention**: Follow conventional commit practices (e.g. `feat:`, `fix:`, `refactor:`).

---

## 🛠️ Environment & Troubleshooting

When operating in a restricted or sandboxed environment (like the Jetski IDE),
you may encounter the following blockers. Use these workarounds:

- **Terminal Sandbox (SPM `sandbox-exec` errors)**: `swift build` may fail if
  run inside a sandbox. Disable the terminal sandbox in the IDE settings
  (`enableTerminalSandbox: false`) or use `swift build --disable-sandbox`.
- **Missing `python` Command**: Modern macOS lacks `python` (Python 2). If
  external scripts fail, create a local wrapper script that forwards to
  `python3` and add it to the `PATH`:
  `mkdir -p tmp/bin && echo '#!/bin/sh\nexec python3 "$@"' > tmp/bin/python && chmod +x tmp/bin/python && export PATH="$PWD/tmp/bin:$PATH"`
- **Ruby Version Conflicts**: External scripts (like `pod_lib_lint.rb`) may
  fail if `rbenv` tries to use the external repo's `.ruby-version`. Force the
  local Ruby version by prefixing the command with `RBENV_VERSION=2.7.5`.
- **Quality Gates**: Do not skip `style.sh` and `pod_lib_lint.rb`. They are
  critical for verification.

---

## 📝 Final Walkthrough Structure
The task is not done until a `walkthrough.md` artifact is created containing:
1.  **Summary of Changes**: High-level overview.
2.  **Public API Diff**: Any new public APIs.
3.  **Verification Results**: Snippets showing successful test runs.

---

## 🧠 Post Change: Continuous Improvement
Perform self-reflection after completing the task and update this file or
create/update a Knowledge Item to help future agents.
