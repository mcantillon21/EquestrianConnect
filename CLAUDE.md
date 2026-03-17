# EquestrianConnect — Agent Rules

## Git / GitHub

**After every set of code changes, commit and push to GitHub.**

- Remote: `origin` → `https://github.com/sunasaid/equestrianconnect` (or the actual repo URL once confirmed)
- Branch: `main`
- Always run `python3 generate_project.py` before committing so `project.pbxproj` is up to date
- Stage all changed Swift files plus `project.pbxproj`; never commit `.DS_Store`, `DerivedData`, or `*.xcuserstate`
- Write a concise commit message describing what changed (e.g. "fix dashboard navigation, add horse photos")
- Push immediately after committing: `git push origin main`

### First-time setup (if no remote yet)
```bash
git init
git remote add origin https://github.com/sunasaid/equestrianconnect.git
git add -A
git commit -m "initial commit"
git push -u origin main
```

## Project

- iOS 17+, SwiftUI, `@Observable` macro
- Run `python3 generate_project.py` whenever Swift files are added or removed
- Build target: `com.equestrianconnect.app`
- Simulator device for screenshots: iPhone 17
- All network calls must run off the main thread; only `@Observable` property mutations use `await MainActor.run { }`
