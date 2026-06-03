# DemoApp XCFrameworks Example

This example uses the same demo sources as `Examples/DemoApp`, but links against locally generated XCFrameworks instead of the Swift package.

Generate the frameworks before opening or building the project. This requires Xcode and Ruby because the wrapper script delegates to the repository-level Ruby XCFramework build tooling.

```bash
cd Examples/DemoApp-XCFrameworks
./generate-xcframeworks.sh
open DemoApp-XCFrameworks.xcodeproj
```

The project expects the generated artifacts in the repository root `XCFrameworks/` folder, for example `../../XCFrameworks/SnapshottingTests.xcframework` and `../../XCFrameworks/PreviewsSupport.xcframework`.
