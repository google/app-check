# App Check Core

This library is for internal Google use only. It contains core components of `FirebaseAppCheck`,
from the [`firebase-ios-sdk`](https://github.com/firebase/firebase-ios-sdk) project, for use in
other Google SDKs. External developers should integrate directly with the
[Firebase App Check SDK](https://firebase.google.com/docs/app-check).

## Staging a release

* Determine the next version for release by checking the
  [tagged releases](https://github.com/google/app-check/tags). If the next release will be
  available for both CocoaPods and SPM, ensure that the next release version has been
  incremented accordingly so that the same version tag is used for both CocoaPods and SPM.
* Verify that the releasing version is the latest entry in the [CHANGELOG.md](CHANGELOG.md),
  updating it if necessary.
* Update the version in the podspec to match the latest entry in the [CHANGELOG.md](CHANGELOG.md)
* Checkout the `main` branch and ensure it is up to date
  ```console
  git checkout main
  git pull
  ```
* Add the CocoaPods tag (`{version}` will be the latest version in the [podspec](AppCheckCore.podspec#L3))
  ```console
  git tag CocoaPods-{version}
  git push origin CocoaPods-{version}
  ```
* Push the podspec to the designated repo
  * If this version of GoogleUtilities is intended to launch **before or with** the next Firebase release:
    <details>
    <summary>Push to <b>SpecsStaging</b></summary>

    ```console
    pod repo push --skip-tests --use-json staging AppCheckCore.podspec
    ```

    If the command fails with `Unable to find the 'staging' repo.`, add the staging repo with:
    ```console
    pod repo add staging git@github.com:firebase/SpecsStaging.git
    ```
    </details>
  * Otherwise:
    <details>
    <summary>Push to <b>SpecsDev</b></summary>

    ```console
    pod repo push --skip-tests --use-json dev AppCheckCore.podspec
    ```

    If the command fails with `Unable to find the 'dev' repo.`, add the dev repo with:
    ```console
    pod repo add dev git@github.com:firebase/SpecsDev.git
    ```
    </details>
* Run Firebase CI by waiting until next nightly or adding a PR that touches `Gemfile`.
* To copybara, run the following command on gLinux:
  ```console
  /google/data/ro/teams/copybara/copybara third_party/app_check/copy.bara.sky
  ```

## Contributing

See [Contributing](CONTRIBUTING.md) for more information about contributing to the App Check Core
SDK.

## License

The contents of this repository is licensed under the
[Apache License, version 2.0](http://www.apache.org/licenses/LICENSE-2.0).
