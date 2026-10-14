# AeroResearch GCS 인수인계 (2026-10-13 기준)

새 세션의 Claude에게: **이 파일을 먼저 끝까지 읽고 이어서 작업하세요.** AGENTS.md(QGC 규칙)도 함께 따릅니다.

## 1. 프로젝트 개요

- QGroundControl 5.1 포크 → **AeroResearch GCS** (주식회사 에어로리서치, 대표 최순영)
- 디자인: 검정/주황 테마, **한국어 UI**
- 저장소 `choisun0133/qgroundcontrol` (공개)
  - `aero-gcs` : 작업 브랜치 (모든 기능 커밋은 여기)
  - `publish-aero` : 릴리스 워크플로(`.github/workflows/aero-release.yml`)만 있는 브랜치
  - `diag-video` : 영상 진단용 CI 워크플로(`aero-video-diag.yml`), 결과는 `diag-results-<case>` 브랜치에 push됨
  - `aero-final` / `aero-mac` : 안드로이드·맥 빌드 트리거용

## 2. 사용자 작업 규칙 (꼭 지킬 것)

- **항상 한국어로 답변.** 시간은 KST(UTC+9)로 말할 것 (UTC 그대로 말해서 지적받은 적 있음).
- **자동 빌드 금지 (2026-10-14~).** 수정 후 바로 빌드하지 말고, 수정 내용을 사용자에게 설명하고 "빌드할까요?"라고 물어서 승인받은 뒤 빌드. 작업 커밋은 `[skip ci]`를 붙여 push(빌드 안 됨)하고, 승인 후 `git commit --allow-empty -m "ci: build <버전>"` push로 빌드 시작.
- **빌드는 윈도우만.** 사용자가 "**최종버전**"이라고 하면 그때 안드로이드(·맥)도 빌드.
- **빌드가 끝나면 다운로드 링크를 바로 줄 것.**
- 짧고 빠른 답을 선호. 오래 기다리는 도구 호출을 거절한 적 있음.
- 커밋은 Conventional Commits, 트레일러:
  `Co-Authored-By: Claude ... <noreply@anthropic.com>` (세션에서 안내되는 형식 사용)

## 3. 빌드·릴리스 절차

1. `aero-gcs`에 push → GitHub Actions **Windows** 워크플로가 자동 실행 (amd64만, 약 20분)
   - 매트릭스 `edition: [dev, user]` → 아티팩트 `QGroundControl-installer-AMD64`(개발자용), `QGroundControl-installer-AMD64-User`(사용자용)
   - 같은 브랜치에 새 push가 오면 이전 빌드는 **자동 취소**됨
   - workflow_dispatch 입력 `video_player=FFmpeg` 로 FFmpeg(Qt Multimedia) 시험판 빌드 가능
2. 빌드 성공 후 릴리스:
   ```
   gh workflow run aero-release.yml -R choisun0133/qgroundcontrol --ref publish-aero -f variant=normal   # 또는 -f variant=FFmpeg
   ```
   - aero-gcs **최신 커밋**의 아티팩트를 받아 이름을 바꾸고 `aerogcs-<버전>` 태그로 릴리스(같은 태그면 지우고 다시 만듦)
   - **주의**: aero-gcs 최신 커밋이 `[skip ci]` 문서 커밋이면 그 커밋엔 빌드가 없어 릴리스가 아무것도 못 찾음 → 다음 코드 변경을 push해서 빌드한 뒤 릴리스할 것
   - 사용자용 아티팩트가 있으면 `...-Developer-Setup.exe` / `...-User-Setup.exe`, 없으면 `...-Setup.exe` 하나
3. **버전 올리기**: `publish-aero` 브랜치의 aero-release.yml 안 버전 문자열(현재 `1.6.8`)을 sed로 바꿔 `[skip ci]` 커밋
4. 링크 형식: `https://github.com/choisun0133/qgroundcontrol/releases/download/aerogcs-<ver>/AeroResearchGCS-<ver>-Windows-x64-Setup.exe`
- 환경 메모: 이 세션 환경에서는 Actions 로그·아티팩트 직접 다운로드, 저장소 Secrets 설정이 프록시로 막혀 있었음 → 상태는 `gh api .../actions/runs/<id>/jobs`, 결과물은 릴리스로 확인

## 4. 버전 이력 (최근)

| 버전 | 내용 |
|---|---|
| 1.6.4 | 진동·EKF 창, 배터리 모양 칩, OS 배율에 맞춘 UI 크기 / FFmpeg 시험판 |
| 1.6.5 | 윈도우 GStreamer 플러그인 **전부 포함**(`QGC_GST_BUNDLE_ALL_PLUGINS`), 영상 안 나올 때 화면에 원인 표시 |
| 1.6.6 | **개발자용/사용자용 분리**, GPS 위성 수, 웨이포인트 마우스오버 위경도·고도, 기체 아래 실시간 위경도(클릭 복사), Ctrl+F 빠른 도구(FC 재부팅, 근접 센서 창, 진동·EKF 창) |
| 1.6.7 | rtsp:// UDP→TCP 폴백, 설치 시 윈도우 방화벽 허용 규칙, 영상 진단 로그 버튼 |
| 1.6.8 | 진단 로그 중 앱 멈춤 수정, Ctrl+F에 진단 로그, 오류 상세 2번째 줄 표시 (현재 최신, 개발자용만 릴리스됨) |

## 5. 기능별 주요 파일

- 개발자/사용자용: CMake `QGC_AERO_USER_EDITION` → QML `QGroundControl.aeroUserEdition`
  - 사용자용은 메뉴 "기체 설정" 제거, `mainWindow.showVehicleConfig*` 무동작, 메시지의 param:// 링크·툴바 상태창 파라미터 편집 숨김, MAVLink 콘솔 제거
  - `src/Toolbar/SelectViewDropdown.qml`, `src/MainWindow/MainWindow.qml`, `src/Toolbar/MainStatusIndicator.qml`, `src/API/QGCCorePlugin.cc`
- 상태 칩(텔레메트리/RC/LTE/GPS/배터리, 진동·EKF): `src/Toolbar/AeroLinkStatus.qml`, `AeroStatusGroup.qml`, `AeroStatusAlert.qml`
- 진동·EKF 창: `src/FlyView/AeroHealthPanel.qml`, EKF 팩트 `src/Vehicle/FactGroups/VehicleEKFStatusFactGroup.*`
- 근접 센서 창: `src/FlyView/AeroProximityPanel.qml` (`vehicle.distanceSensors`)
- Ctrl+F 빠른 도구: `src/Toolbar/AeroQuickTools.qml` + `MainWindow.qml`의 `Shortcut`
- 웨이포인트 마우스오버: `src/FlightMap/MapItems/PlanMapItems.qml` / 기체 위경도 칩: `src/FlyView/FlyViewMap.qml`
- 다른 GCS 미션 변경 감지·다운로드: `src/MissionManager/MissionManager.*`, `src/Toolbar/AeroMissionSyncNotice.qml`
- 임무 계획 첫 항목 이륙 고정: `src/PlanView/PlanView.qml`
- 계기판(크기·투명도): `src/FlyView/AeroInstrumentPanel.qml`
- 크래시 보고서: `src/Utilities/Platform/Platform.cc` (`%LOCALAPPDATA%\AeroResearch\last_crash.txt`)
- 영상 크래시 루프 방지: `src/VideoManager/VideoManager.cc` (`AeroResearch/videoStartPending`)
- 한국어 번역: `translations/qgc_source_ko_KR.ts`
- 설정 파일 위치(윈도우, 브랜치 빌드=daily): `%APPDATA%\AeroResearch\QGroundControl Daily.ini`

## 6. RTSP 영상 문제 — 해결됨 (1.6.12, 2026-10-14 사용자 확인)

원인이 세 가지였고 모두 고침:
1. **SETUP URL**: 중계 서버 SDP의 상대 control(`trackID=v`)을 rtspsrc가 RFC 3986대로 풀어 경로·`?DeviceKey=`가 빠짐 → `GstSourceFactory.cc`의 `rtspBeforeSend`에서 VLC처럼 원래 URL 뒤에 붙임
2. **전송 방식**: 이 서버는 UDP로 데이터가 안 옴(VLC도 10초 뒤 TCP로 전환) → `?`가 있는 rtsp:// 주소는 TCP 기본, TCP에서는 drop-on-latency 끄고 지연 최소 300ms
3. **데스크톱 충돌**: GIO libproxy(`giolibproxy`→`pxbackend`)가 데스크톱의 프록시 설정에서 크래시 → 윈도우에서 `GIO_USE_PROXY_RESOLVER=dummy` (`GStreamerEnvironment.cc`)
- 윈도우 기본값: D3D11 디코더 + CPU 프레임 경로 + 저지연 모드 (`VideoSettings.cc`)
- 진단 도구: Ctrl+F → 영상 진단 로그(바탕화면 txt, RTSP 요청/응답 전체 포함), 오류 상세 2줄 화면 표시, 충돌 보고서(`last_crash.txt`)

## 7. 기타 자료

- 디자인 캔버스(Claude 아티팩트): `https://claude.ai/artifact/6hoGwpy7NBonmMkuiKRjJ4` — 새 계정은 원래 계정에서 **공유**받아야 열림. 최근 보드: `Tools.dc.html`(빠른 도구·근접 센서·위경도·사용자용 메뉴), `Health.dc.html`, `RC.dc.html`
- 설명서 문서(Claude Docs): 원래 계정에서 공유받을 것
- NAS 자동 업로드 스크립트 `aerogcs_nas_sync.sh`(시놀로지, 대상 `/volume1/최순영/QGC/윈도우`)는 사용자에게 전달됨(저장소에는 없음)
- 기체 PreArm `PRX1: No Data`: 근접 센서 설정됐는데 데이터 없음(영상과 별개). 안 쓰면 `PRX1_TYPE=0`
