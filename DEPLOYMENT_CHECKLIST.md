# Hanabi Download Manager X - Deployment Checklist

## Pre-Deployment Checks

### Code Quality
- [ ] All code compiled without errors
- [ ] No critical warnings in Flutter analyzer
- [ ] All tests passing (if applicable)
- [ ] Code reviewed and approved

### Version Management
- [ ] Version number updated in `pubspec.yaml`
- [ ] Version number updated in README files
- [ ] CHANGELOG updated with new features/fixes
- [ ] Git tags created for release

### Build Process
- [ ] Flutter dependencies updated (`flutter pub get`)
- [ ] Python dependencies verified
- [ ] Assets properly included
- [ ] Icons and logos in correct formats

### Windows Build
- [ ] Run `quick_build.bat` successfully
- [ ] Verify `soda_bridge_server.exe` compiled
- [ ] Verify Flutter app compiled
- [ ] Test executable in clean environment
- [ ] Check file size and dependencies

### Testing
- [ ] Download functionality tested
- [ ] Browser extension tested (Chrome/Edge)
- [ ] System tray functionality verified
- [ ] Settings persistence verified
- [ ] Multi-download tested
- [ ] Resume/pause functionality tested
- [ ] Network error handling tested

### Documentation
- [ ] README.md updated
- [ ] README_CN.md updated
- [ ] Browser extension README updated
- [ ] API documentation current
- [ ] User guide available

### Release Package
- [ ] Executable file included
- [ ] Required DLLs included
- [ ] Assets folder included
- [ ] License file included
- [ ] README files included
- [ ] Browser extension folder included

### Distribution
- [ ] GitHub release created
- [ ] Release notes written
- [ ] Download links tested
- [ ] Website updated (x.zzbuaoye.top)
- [ ] Announcement prepared

### Post-Deployment
- [ ] Monitor crash reports
- [ ] Check user feedback
- [ ] Monitor online statistics
- [ ] Prepare hotfix if needed

## Build Commands

### Quick Build (Windows)
```bash
quick_build.bat
```

### Manual Build
```bash
# Flutter build
flutter build windows --release

# Python build (if separate)
cd python
python -m nuitka --standalone --onefile soda_bridge_server.py
```

### Browser Extension
```bash
# No build needed - load unpacked extension
# Test in Chrome/Edge before release
```

## Release Checklist

### GitHub Release
- [ ] Create new release tag (e.g., v1.2.8)
- [ ] Upload Windows executable
- [ ] Upload browser extension zip
- [ ] Write release notes
- [ ] Mark as latest release

### Website Update
- [ ] Update download links
- [ ] Update version number
- [ ] Update screenshots if UI changed
- [ ] Test download links

### Statistics Server
- [ ] Verify server is running
- [ ] Check online statistics working
- [ ] Monitor for errors
- [ ] Backup data if needed

## Rollback Plan

If critical issues found:
1. Mark release as pre-release
2. Prepare hotfix
3. Test thoroughly
4. Release hotfix version
5. Update all documentation

## Support Preparation

- [ ] Monitor GitHub issues
- [ ] Prepare FAQ for common issues
- [ ] Set up support channels
- [ ] Document known issues

---

**Last Updated:** 2026-01-30
**Current Version:** 1.2.8
