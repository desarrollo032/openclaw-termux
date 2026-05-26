# Task Management

- [ ] Refactor `MainActivity.kt` into specialized handlers
	- [ ] Create `BaseHandler.kt`
	- [ ] Create `SystemHandler.kt`
	- [ ] Create `HardwareHandler.kt`
	- [ ] Create `ProcessHandler.kt`
	- [ ] Update `MainActivity.kt` to use handlers
- [ ] Unify Terminal Logic in Flutter
	- [ ] Create `TerminalViewModule` widget
	- [ ] Refactor `TerminalScreen`
	- [ ] Refactor `OnboardingScreen`
	- [ ] Refactor `PackageInstallScreen`
- [ ] Optimize Native PTY (C++)
	- [ ] Research and implement `select`/`epoll` in `openclaw_pty.cpp`
- [ ] Improve Bootstrap Process
	- [ ] Implement SHA256 verification in `BootstrapManager.kt`
- [ ] UX Improvements
	- [ ] Implement Material You support
	- [ ] Adaptive layouts for Dashboard
