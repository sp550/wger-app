# Building this fork (containerized, Apple Silicon)

How to build this repo's Android APK inside the isolated OpenCode container on `sahils-mac`.
Hard-won lessons from 2026-07-31 / 08-02 — READ before rebuilding anything.

## Environment
- Container: `isolated-opencode-server` (Docker Desktop on Apple Silicon Mac)
- Base image: `ghcr.io/cirruslabs/flutter:stable` **amd64** (run via Rosetta) — do NOT use arm64
- opencode server runs inside the container; driven remotely over Tailscale (`100.104.142.125:4096`)
- Only `~/Local Coding` is writable by the agent (mounted at `/workspace`)
- DeepSeek model: `deepseek/deepseek-v4-flash` (auth persisted in `opencode-data` volume)

## Toolchain pins (deliberate fork divergence from upstream)
| Component | This fork | Upstream wger | Why |
|---|---|---|---|
| AGP | 8.9.2 | 8.13.1 | Kotlin 2.2.x can't validate 8.13 → NPE |
| Gradle wrapper | 8.14.3 | 9.2.1 | pairs with AGP 8.9 |
| Kotlin (root) | 2.2.21 | 2.2.21 | fine |

Legacy pub packages carry their own buildscript classpaths (Kotlin 2.2.0 + AGP 8.12.1) which conflict
with newer AGP. In the container's pub-cache these were patched to Kotlin 2.2.21 + AGP 8.9.2:
`camera_android_camerax`, `image_picker_android`, `package_info_plus`, `shared_preferences_android`,
`url_launcher_android`, `video_player_android`. Patches live in the container volume — if the
pub-cache volume is wiped, re-apply them.

## Pitfalls (each one cost hours — do not relive them)
1. **amd64, not arm64.** Google publishes NO linux-arm64 aapt2. An arm64 container fails with
   `rosetta error: failed to open elf at /lib64/ld-linux-x86-64.so.2` when Gradle runs x86_64 aapt2.
   Use the amd64 base image → whole toolchain is x86_64 → Docker Desktop's Rosetta runs it.
   (Docker Desktop VM must have Rosetta enabled: `--rosetta` flag in the VM args.)
2. **Zero-byte `package.xml` in the SDK.** The cirruslabs image ships 0-byte files at
   `build-tools/35.0.0/package.xml`, `platforms/android-34/package.xml`, `platforms/android-35/package.xml`.
   AGP fails with `javax.xml.bind.UnmarshalException / SAXParseException "Premature end of file"`
   on `:flutter_zxing:generateDebugRFile` (and it survives every Gradle cache wipe).
   Fix: delete the empty files; AGP proceeds fine without them.
3. **NDK versions.** `flutter_zxing` pins NDK 27 (image ships a broken `.installer` stub);
   the app itself wants NDK 28. Install both once:
   `yes | /opt/android-sdk-linux/cmdline-tools/latest/bin/sdkmanager "ndk;27.0.12077973" "ndk;28.2.13676358"`
4. **Volume ownership.** A named volume mounted at `/home/coder/<dir>` becomes root-owned if that
   path doesn't exist in the image. Pre-create + chown every mountpoint in the Dockerfile:
   `.local/share/opencode`, `.local/state`, `.cache`, `.pub-cache`, `.gradle`, `.android`.
5. **SDK root-owned.** The image's `/sdks` (Flutter) and `/opt/android-sdk-linux` are root-owned;
   the non-root `coder` user needs them writable:
   `RUN chown -R coder:coder /sdks /opt/android-sdk-linux`
6. **Disk pressure.** NDK 27+28 + Gradle caches + old images can fill the Docker VM disk
   (`docker system df`, prune old images). Watch host Mac disk too (it hit 96%).
7. **opencode headless permission gate.** `rm -rf` / `mv` get auto-rejected in headless mode
   ("The user rejected permission"). Set `permission.bash=allow` in opencode.json AND use
   `python3 -c "import shutil; shutil.rmtree(...)"` for deletions.
8. **opencode bash timeout.** Default 120 000 ms kills long builds. Always pass
   `timeout: 600000` ms on the bash tool call.
9. **Agent reliability.** deepseek-v4-flash agents stop after 3–4 tool calls. Dispatch ONE
   bash command per run; redirect build output to a log file and grep it in the same command.
10. **Port binding.** Publish the container port on the Tailscale IP only
    (`100.104.142.125:4096:4096`), never 0.0.0.0. Kill any process holding the port first.

## Clean build recipe
```bash
python3 -c "import shutil; [shutil.rmtree(p, ignore_errors=True) for p in ['/home/coder/.gradle/caches/modules-2','/workspace/wger-app/build','/workspace/wger-app/android/.gradle']]"
cd /workspace/wger-app && flutter build apk --debug
# APK: build/app/outputs/flutter-apk/app-debug.apk
```

## Container ops
- Start / stop: `docker compose up -d` / `docker compose down` (in `~/Local Coding/isolated-opencode-server`)
- Provider auth: `docker exec -it isolated-opencode-server opencode auth login` (persists in `opencode-data`)
- APK on the Mac: `~/Local Coding/wger-app/build/app/outputs/flutter-apk/`
- Sideload to Pixel 9 Pro: enable Wireless debugging → `adb pair 100.73.35.25:<port> <code>` once →
  `adb connect 100.73.35.25:<port>` → `adb install <apk>`

## CI (2026-08-06): Android builds via GitHub Actions

The container build box is retired. APK builds now run on GitHub Actions (repo `sp550/wger-app`, private).

- Workflow: `.github/workflows/build-apk.yml` — manual dispatch (branch input) or push of `v*` tags.
- Runner: ubuntu-latest, Flutter 3.44.8 (`.github/actions/flutter-common`), JDK 17.
- The pub-cache Kotlin/AGP patch is applied by `tool/ci/patch_pub_cache.sh` (committed — replaces the old container-volume patch).
- Release signing: keystore + passwords injected from GH secrets `WGER_RELEASE_*` (keystore backup + credentials: `/opt/opencode/backups/wger-release-keystore/` on docker-leederville, mode 0600).
- Artifacts: `wger-app-apks` (app-debug.apk + app-release.apk) on the Actions run page.
- Release build failure history: `:app:packageRelease` missing `storeFile` = missing `key.properties` (now supplied by CI from secrets), NOT a RAM/OOM problem.
