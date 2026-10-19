# AeroResearch GCS 인수인계 (2026-10-13 기준)

새 세션의 Claude에게: **이 파일을 먼저 끝까지 읽고 이어서 작업하세요.** AGENTS.md(QGC 규칙)도 함께 따릅니다.

## 1. 프로젝트 개요

- QGroundControl 5.1 포크 → **AeroResearch GCS** (주식회사 에어로리서치, 대표 최순영)
- 디자인: 검정/주황 테마, **한국어 UI**
- 저장소 `choisun0133/qgroundcontrol` (공개)
  - `aero-gcs` : 작업 브랜치 (모든 기능 커밋은 여기)
  - `publish-aero` : 릴리스 워크플로(`.github/workflows/aero-release.yml`)만 있는 브랜치
  - `diag-video` : 영상 진단용 CI 워크플로(`aero-video-diag.yml`), 결과는 `diag-results-<case>` 브랜치에 push됨
  - `aero-final` / `aero-mac` : 안드로이드·맥 빌드 트리거용 (aero-final에 push하면 Windows·Mac도 돌아가니 필요 없으면 취소). 안드로이드는 `gh workflow run android.yml --ref aero-gcs -f brand=aero|daeyoung`로 돌리는 게 간단 — 릴리즈는 윈도우 빌드와 같은 커밋의 APK만 붙임

## 2. 사용자 작업 규칙 (꼭 지킬 것)

- **항상 한국어로 답변.** 시간은 KST(UTC+9)로 말할 것 (UTC 그대로 말해서 지적받은 적 있음).
- **자동 빌드 금지 (2026-10-14~).** 수정 후 바로 빌드하지 말고, 수정 내용을 사용자에게 설명하고 "빌드할까요?"라고 물어서 승인받은 뒤 빌드. 작업 커밋은 `[skip ci]`를 붙여 push(빌드 안 됨)하고, 승인 후 `[skip ci]` 없는 커밋(파일 변경 포함, 빈 커밋 불가) push로 빌드 시작.
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
   - aero-gcs의 **가장 최근 성공한 push 빌드**의 아티팩트를 받아 이름을 바꾸고 `aerogcs-<버전>` 태그로 릴리스(같은 태그면 지우고 다시 만듦)
   - **주의**: Windows 워크플로는 `paths-ignore`가 있어 **빈 커밋(`--allow-empty`)은 빌드를 시작하지 않음**. 빌드를 시작하려면 파일이 바뀐 커밋(`[skip ci]` 없이)을 push할 것 (예: 이 문서 갱신)
   - 사용자용 아티팩트가 있으면 `...-Developer-Setup.exe` / `...-User-Setup.exe`, 없으면 `...-Setup.exe` 하나
3. **릴리스 노트**: `publish-aero` 브랜치의 `RELEASE_NOTES.md`가 릴리스 설명이 됨 (버전마다 이 파일도 갱신). 이 세션 환경에서는 릴리스 직접 수정(API)이 막혀 있어 워크플로를 다시 돌려 반영
4. **버전 올리기**: `publish-aero` 브랜치의 aero-release.yml 안 버전 문자열(현재 `1.6.21`)을 sed로 바꿔 `[skip ci]` 커밋
5. 링크 형식: `https://github.com/choisun0133/qgroundcontrol/releases/download/aerogcs-<ver>/AeroResearchGCS-<ver>-Windows-x64-Setup.exe`
- 환경 메모: 이 세션 환경에서는 Actions 로그·아티팩트 직접 다운로드, 저장소 Secrets 설정이 프록시로 막혀 있었음 → 상태는 `gh api .../actions/runs/<id>/jobs`, 결과물은 릴리스로 확인

## 4. 버전 이력 (최근)

| 버전 | 내용 |
|---|---|
| 1.6.4 | 진동·EKF 창, 배터리 모양 칩, OS 배율에 맞춘 UI 크기 / FFmpeg 시험판 |
| 1.6.5 | 윈도우 GStreamer 플러그인 **전부 포함**(`QGC_GST_BUNDLE_ALL_PLUGINS`), 영상 안 나올 때 화면에 원인 표시 |
| 1.6.6 | **개발자용/사용자용 분리**, GPS 위성 수, 웨이포인트 마우스오버 위경도·고도, 기체 아래 실시간 위경도(클릭 복사), Ctrl+F 빠른 도구(FC 재부팅, 근접 센서 창, 진동·EKF 창) |
| 1.6.7 | rtsp:// UDP→TCP 폴백, 설치 시 윈도우 방화벽 허용 규칙, 영상 진단 로그 버튼 |
| 1.6.8 | 진단 로그 중 앱 멈춤 수정, Ctrl+F에 진단 로그, 오류 상세 2번째 줄 표시 |
| 1.6.9~1.6.13 | RTSP 영상 문제 해결(6장), 설치 시 바탕화면 바로가기 |
| 1.6.14 | 최소화한 카메라/메시지 창 드래그 이동, 배터리 %·V 동시 표시와 최대/최소 전압 입력, 계기판 모서리 드래그 크기 조절·최소화, 임무 계획 첫 포인트에서 이륙 추가 여부 팝업(비행 중이면 이륙 없음), RC 미연결 표시, 시작 화면 저장된 연결 설정 불일치 버그 수정 |
| 1.6.15 | 키보드 수동 조종(모드2: W/S 상승·하강, A/D 회전, 방향키 이동, Shift ×2, Space 정지, Esc 해제) — 일시 정지 중 도구 막대 "수동 조종" 버튼·상단 버튼·Ctrl+F로 시작, GUIDED 속도 명령 10Hz, 반투명 키 표시(투명도 조절). 영상 진단 버튼은 Ctrl+F에만 |
| 1.6.16 | 일시 정지는 확인/취소 버튼(누르고 있기 없음, 현재 고도 유지), 고도 변경은 팝업에 목표 고도 입력 후 확인/Enter (`GuidedActionConfirm.qml`) |
| 1.6.17 | USB로 연결된 텔레메트리 모뎀(USB 직결로 잡힘)도 RADIO_STATUS가 오면 텔레메트리 칩에 신호 표시 (`AeroLinkStatus.qml`) |
| 1.6.18 | 대영M&S GCS 고객사 판: CMake `QGC_AERO_BRAND=daeyoung` (이름·로고·아이콘·강조색), Windows CI가 aero/daeyoung × dev/user 4개 빌드, 릴리즈 파일 `DaeyoungMS-GCS-…` |
| 1.6.19 | 안드로이드 화면 크기 자동 맞춤 (`ScreenTools.qml`, 약 40×72 글자 크기 기준) + 안드로이드 APK 릴리즈 |
| 1.6.20 | 대영M&S 안드로이드 (패키지 kr.co.aeroresearch.daeyoung, 아이콘 `resources/brand/daeyoung/android/res`) |
| 1.6.21 | 하방 라이다(계기판 지면 거리·음성), 한국어 음성 안내(`src/Utilities/Audio/AeroKoreanSpeech.*`), 목소리 선택·녹음 음성 팩(`AudioOutput`), Ctrl+F 음성 설정. 대영판 윈도우 빌드는 커밋 메시지에 `[daeyoung]`이 있을 때만 |

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
- 브랜드(에어로리서치/대영M&S): `cmake/CustomOptions.cmake`의 `QGC_AERO_BRAND`, 로고는 `resources/brand/<brand>.qrc`(같은 /res 별칭), 강조색 `QGCPalette.cc`의 `AERO_ACCENT`, QML은 `QGroundControl.aeroBrand/aeroWordmarkAspect/aeroWordmarkScale/aeroCopyright`. 대영판은 `QGCLogoWhite.svg`(설정 메뉴 로고)→`DaeyoungMarkWhite.svg`, 설치 헤더→`resources/brand/daeyoung/installheader.bmp`, 안드로이드 아이콘은 `file(COPY_FILE)`로 하나씩 덮어씀(`file(COPY)`는 같은 시각 파일을 건너뛰어 AR 아이콘이 남았음). 대영 로고는 회사소개서 PDF에서 추출한 임시본 — 원본 받으면 `resources/brand/daeyoung/`만 교체
- 계기판(크기·투명도·최소화): `src/FlyView/AeroInstrumentPanel.qml`
- 키보드 수동 조종: `src/FlyView/AeroKeyboardControl.qml`, 도구 막대 버튼 `AeroManualControlAction.qml`, 명령은 `FirmwarePlugin::guidedModeSetBodyVelocity`(APM 구현)
- QML 오류 사전 점검: PySide6(`pip install PySide6-Essentials`)로 스텁 모듈 만들어 컴포넌트를 offscreen 로드해 보면 부팅 테스트 실패(QML 로드 오류)를 빌드 전에 잡을 수 있음 (1.6.15 첫 빌드가 이걸로 실패)
- 남성 성우 녹음 대본(60개 문구·파일 이름): Claude Docs "GCS 음성 안내 녹음 대본". 녹음 받으면 `resources/voice/<clip>.wav`로 넣고 qrc(/voice)에 추가해 번들 가능
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
- 진단 도구: Ctrl+F → 영상 진단 로그(바탕화면 txt, RTSP 요청/응답 전체 포함, 1.6.15부터 영상 화면 버튼은 제거하고 Ctrl+F에만 있음), 오류 상세 2줄 화면 표시, 충돌 보고서(`last_crash.txt`)

## 7. 기타 자료

- 디자인 캔버스(Claude 아티팩트): `https://claude.ai/artifact/6hoGwpy7NBonmMkuiKRjJ4` — 새 계정은 원래 계정에서 **공유**받아야 열림. 최근 보드: `Tools.dc.html`(빠른 도구·근접 센서·위경도·사용자용 메뉴), `Health.dc.html`, `RC.dc.html`
- 설명서 문서(Claude Docs): 원래 계정에서 공유받을 것
- NAS 자동 업로드 스크립트 `aerogcs_nas_sync.sh`(시놀로지, 대상 `/volume1/최순영/QGC/윈도우`)는 사용자에게 전달됨(저장소에는 없음)
- 기체 PreArm `PRX1: No Data`: 근접 센서 설정됐는데 데이터 없음(영상과 별개). 안 쓰면 `PRX1_TYPE=0`
