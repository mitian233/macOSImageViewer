# Testing Guide

## Running Tests

### Unit Tests
```bash
xcodebuild test -scheme ImageViewer -destination 'platform=macOS' -only-testing:ImageViewerTests
```

### UI Tests
```bash
xcodebuild test -scheme ImageViewer -destination 'platform=macOS' -only-testing:ImageViewerUITests
```

### All Tests
```bash
xcodebuild test -scheme ImageViewer -destination 'platform=macOS'
```

## Test Structure

### Unit Tests (ImageViewerTests)
- **ImageViewerStateTests**: 21 tests for zoom, pan, rotate operations
- **MediaFileManagerTests**: 13 tests for file loading and navigation
- **MediaCacheManagerTests**: 9 tests for image caching
- **SlideshowControllerTests**: 10 tests for slideshow timing
- **ContentViewTests**: 5 tests for view structure (ViewInspector)

### UI Tests (ImageViewerUITests)
- **ImageViewerUITests**: App launch verification
- **ImageViewerUITestsLaunchTests**: Launch performance tests

## Code Coverage

Coverage reports are generated automatically when running tests. To view coverage:

1. Run tests with coverage enabled (default in shared scheme)
2. Open DerivedData in Xcode
3. View coverage report in Report Navigator

## CI/CD

GitHub Actions runs all tests on every push and pull request. See `.github/workflows/test.yml` for configuration.

## Writing New Tests

### Unit Tests
- Use Swift Testing (`@Test`, `#expect`) for new tests
- Follow naming convention: `test_<method>_<scenario>_<expectedResult>`
- Mock external dependencies (FileManager, Timer) only

### ViewInspector Tests
- Use `ViewHosting.host()` to render views
- Test view structure, not implementation details
- Use `on(\.didAppear)` for async verification

### UI Tests
- Use XCUITest framework
- Test user interactions, not internal state
- Use accessibility identifiers for element selection
