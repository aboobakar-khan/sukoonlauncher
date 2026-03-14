# Sukoon Launcher - Changelog

## [1.0.5] - 2026-02-21

### ✨ Added
- Complete theme color integration across Productivity Hub
- Theme-aware offline content indicator in Settings
- Premium glass-morphism design for widget cards
- Gradient text effects for card titles
- Enhanced empty state designs with themed containers
- Smart color variant generation using HSL color space

### 🎨 Improved
- Productivity Hub now fully respects user's theme color choice
- Widget cards have elevated design with dual shadow system
- Better visual hierarchy through opacity-based color scales
- Enhanced action buttons (edit/delete) with themed containers
- Smoother color transitions and animations
- More consistent visual language across all screens

### 🔧 Fixed
- Hardcoded sage green color in Productivity Hub replaced with theme colors
- Hardcoded status colors in offline content indicator
- Inconsistent border colors on widget cards
- Flat card design lacking visual depth

### 🏗️ Technical
- Implemented HSL color transformations for darker variants
- Added 15% luminance reduction algorithm for contrast
- Optimized color computations with minimal performance impact
- Maintained backward compatibility (zero breaking changes)
- Zero compilation errors or warnings

### 📦 Build Info
- Version: 1.0.5+19
- AAB Size: 56 MB
- Build Date: February 21, 2026
- Min SDK: Android 6.0+

---

## [1.0.4] - Previous Release
- Memory leak fixes
- Security improvements (print → debugPrint)
- Code cleanup and optimization
- Repository cleanup (removed dev artifacts)

---

## Version Format
- **Major.Minor.Patch+BuildNumber**
- Example: 1.0.5+19
  - 1 = Major version
  - 0 = Minor version  
  - 5 = Patch version
  - 19 = Build number
