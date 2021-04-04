## 0.5.0

- Enabled dart strong mode

**BREAKING CHANGE** This could lead to some type errors as some functions return nullable types now.

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
