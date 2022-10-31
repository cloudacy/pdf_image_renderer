## 0.7.0

- **BREAKING CHANGE**: AGP updated to 7.3.0
- Fixes all dart analysis issues
- Added flutter_lints: ^2.0.1
- Lowered minimum required Flutter SDK version to 1.17.0.
- Lowered minimum required Dart SDK version to 2.12.0.

## 0.6.0

- **BREAKING CHANGE**: Updated gradle plugin version from 3.5.0 to 4.2.1.
- **BREAKING CHANGE**: Updated compileSDKVersion to 30.
- **BREAKING CHANGE**: Updated APIs of `open`, `close` and `openPage` to not return internal values.

### 0.6.1

- Fix `close` method

### 0.6.2

- Add more details to error messages

## 0.5.0

- Enabled dart strong mode

**BREAKING CHANGE** This could lead to some type errors as some functions return nullable types now.

### 0.5.1

- Fixed bad PDF page states. See [21a0d45aa9a096760dd03763b4a961d9d9b9450c](https://github.com/cloudacy/pdf_image_renderer/commit/21a0d45aa9a096760dd03763b4a961d9d9b9450c)

### 0.5.2

- Update dependencies

## 0.4.0

- Migrate to null sound safety.

### 0.4.1

- Use cropBox on iOS devices, not mediaBox

## 0.3.0

- Allow multi-threading on iOS which improves iOS rendering performance by a factor of 4 or more
- Add parallel execution test in example app

### 0.3.1

- Reduce qoS for iOS rendering to prevent ui lags

### 0.3.2

- Reduce android UI lags

## 0.2.0

- **BREAKING** background color now requires a `Color` object
- Make a lot more options optional and use default values instead.

### 0.2.1

- Fix background color not working on android.

## 0.1.0

- Initial release. Can have some stability issues. Do not use in production!

### 0.1.1

- Improve the description to better describe the package.

#### 0.1.1+1

- Try to make android work

#### 0.1.1+2

- Finally found out what the problem for the android problem was -> see commits

### 0.1.2

- Fixed pdf rotation ignored on iOS devices.

### 0.1.3

- Fixed pdf not rendering correctly on iOS with `scale` property larger than 1

### 0.1.4

- Improve iOS pdf rendering performance.

### 0.1.5

- Improve iOS pdf rendering performance.
