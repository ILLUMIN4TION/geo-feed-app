# 📍 Geo-Feed (geofeed)


> **사진, 그 사진이 찍힌 위치(포토스팟), 카메라 촬영 설정(EXIF)까지 함께 공유하는 지오-피드 서비스**

![Flutter](https://img.shields.io/badge/Flutter-3.35.3-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.9-0175C5?logo=dart&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-Firestore%20%7C%20Auth%20%7C%20Storage-FFCA28?logo=firebase&logoColor=black)
![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android&logoColor=white)

---


## ✍️ 작성자

- **남재현** (1인 개발) — [ILLUMIN4TION](https://github.com/ILLUMIN4TION)


---

## 📌 프로젝트 소개 (Description)

**한 줄 요약**: 사진 한 장에 담긴 *위치(GPS)* 와 *카메라 설정(EXIF)* 을 자동으로 추출해, "어디서, 어떻게 찍었는지"까지 함께 공유하는 사진 공유 서비스입니다.

**왜 만들었는가**
- 일반 사진 공유 서비스는 사진과 캡션만 남기지만, 사진의 진짜 가치는 **찍힌 장소(포토스팟)** 와 **촬영 조건**에 있습니다.
- Geo-Feed는 업로드 시 EXIF를 자동으로 파싱하여 GPS 좌표를 **포토스팟**으로, 조리개/셔터/ISO/초점거리 등은 **촬영 정보**로 변환합니다.
- 그래서 다른 사용자는 지도에서 포토스팟을 발견하고, 상세 화면에서 촬영 정보를 확인한 뒤, 자신의 카메라로 같은 설정으로 촬영할 수 있습니다.

---

## 📸 시연 화면 (Screenshots)

| 지도 (클러스터) | 피드 | 게시글 상세 |
|:---:|:---:|:---:|
| <img width="1080" height="2400" alt="Screenshot_1790785979" src="https://github.com/user-attachments/assets/9b6b0494-79f3-427b-8564-5b4990d29478" /> | <img width="1080" height="2400" alt="Screenshot_1790786078" src="https://github.com/user-attachments/assets/7853a790-52e0-4661-9fe9-48796093d579" /> | <img width="1080" height="2400" alt="Screenshot_1790786109" src="https://github.com/user-attachments/assets/56b1d18c-5314-47c9-8b48-47749a59b5bd" /> |

<br>

| 업로드 확인 | 태그 검색 |
|:---:|:---:|
| <img width="1080" height="2400" alt="Screenshot_1790786178" src="https://github.com/user-attachments/assets/ffbddc01-d4b5-42f5-bb6f-d944014cf1fa" /> | <img width="1080" height="2400" alt="Screenshot_1790786218" src="https://github.com/user-attachments/assets/f149f2bf-8922-4249-909c-a703089dcc16" /> |

---



## ✨ 주요 기능 (Key Features)

### 🗺 지도 · 포토스팟
- **클러스터 지도**: 위치 정보가 있는 모든 게시글을 클러스터 마커로 표시 (`google_maps_cluster_manager_2`)
- **클러스터 갤러리**: 클러스터 탭 시 그 지역의 게시글을 3열 그리드 BottomSheet로 표시
- **마커 탭**: 게시글 미리보기 후 상세 화면으로 이동
- **역지오코딩**: 좌표 → 한글 주소로 변환해 표시 (`geocoding`, ko_KR 로케일)

### 📸 업로드 파이프라인
1. **사진 선택** — 갤러리 / 카메라 (앱 종료 시에도 `retrieveLostData()`로 촬영분 복구)
2. **권한 요청** — 위치 · 미디어 위치 · 카메라
3. **EXIF 파싱** — `exif` 패키지로 Make / Model / Aperture / ShutterSpeed / ISO / FocalLength 추출
4. **포토스팟 추출** — EXIF의 GPS 태그를 `GeoPoint`로 변환 (없으면 지도에서 직접 지정)
5. **압축** — WebP 변환, 원본(1080p, q80) + 썸네일(300px, q50) 이중 생성
6. **위치 확인/수정** — 지도에서 마커 위치 확인 후 수정 가능 (**위치 없이는 업로드 불가**)
7. **업로드** — Firebase Storage(`uploads/{uid}/...`) + Firestore(`posts`)에 저장

### 📋 피드
- **무한 스크롤** — 커서 페이지네이션(10개 단위, `startAfterDocument`)
- **좋아요** — Optimistic Update + 실패 시 Rollback
- **Shimmer** 로딩 스켈레톤, `CachedNetworkImage` 캐싱 (썸네일/원본 URL 자동 전환)

### 📷 게시글 상세 · 카메라 레시피
- 상세 화면: 원본 이미지, 위치 미니 지도, EXIF 칩, 좋아요, 캡션 수정, 삭제(Storage 파일까지 함께 삭제)
- **카메라 레시피**: 해당 게시글의 EXIF 설정(줌, 노출 보정, 포커스, 플래시, 그리드, 히스토그램)으로 인앱 카메라를 열어 같은 장면을 재촬영

### 👤 소셜 · 프로필
- **인증**: 이메일/비밀번호 + Google 로그인 (Google 첫 로그인 시 Firestore 사용자 문서 자동 생성)
- **팔로우/언팔로우**, 팔로워·팔로잉 목록
- **프로필 편집**: 닉네임, 프로필 이미지(Storage 업로드)
- **태그 검색**: `#태그` 기반 게시글 검색
- **좋아요한 게시물** 목록

---




## 🛠 기술 스택 (Tech Stack)

| 구분 | 패키지 / 도구 | 버전 | 용도 |
|:---|:---|:---|:---|
| 언어 / 프레임워크 | **Flutter** (Dart) | SDK 3.35.3 / Dart `^3.9.2` | 크로스 플랫폼 UI |
| 백엔드 (BaaS) | **Firebase** | - | Auth · Firestore · Storage |
|  | `firebase_core` | `^3.1.1` | Firebase 초기화 |
|  | `firebase_auth` | `^5.1.1` | 이메일/비밀번호 · Google 로그인 |
|  | `cloud_firestore` | `^5.0.1` | 게시글 / 사용자 DB (NoSQL) |
|  | `firebase_storage` | `^12.1.0` | 이미지 원본 · 썸네일 · 프로필 저장 |
| 상태 관리 | `provider` | `^6.1.2` | ChangeNotifier 기반 상태 관리 |
| 미디어 / EXIF | `image_picker` | `^1.1.2` | 갤러리에서 사진 선택 |
|  | `camera` | `^0.10.5+9` | 인앱 카메라 (카메라 레시피) |
|  | `exif` | `^3.1.3` | EXIF 메타데이터 파싱 (촬영 정보 + GPS) |
|  | `flutter_image_compress` | `^2.3.0` | WebP 압축 (원본 + 썸네일) |
|  | `image` | `^4.0.0` | 히스토그램 계산 |
| 지도 / 클러스터 | `google_maps_flutter` | `2.6.0` | 지도 렌더링, 마커, 위치 선택기 |
|  | `google_maps_cluster_manager_2` | `^3.2.0` | 포토스팟 마커 클러스터링 |
|  | `geocoding` | `^3.0.0` | 좌표 → 한글 주소 (역지오코딩) |
| 인증 / 소셜 | `google_sign_in` | `^6.2.1` | Google 계정 로그인 |
| 권한 | `permission_handler` | `^11.3.1` | 위치 · 카메라 · 미디어 권한 처리 |
| 이미지 로딩 | `cached_network_image` | `^3.3.1` | 네트워크 이미지 캐싱 |
|  | `shimmer` | `^3.0.0` | 로딩 스켈레톤 UI |
| 기타 | `path_provider`, `cupertino_icons` | `^2.1.3`, `^1.0.8` | 임시 파일 저장 · 아이콘 |

---

## ✅ 사전 요구 사항 (Prerequisites)

| 항목 | 버전 / 내용 |
|:---|:---|
| **Flutter SDK** | 3.35.3 (Dart 3.9.2) — `flutter --version` |
| **JDK** | 11 (프로젝트 `build.gradle.kts` 기준) |
| **Android Studio** | 최신 안정판 (Android SDK는 Flutter가 자동 관리) |
| **Firebase** | Firebase 계정 + 자체 Firebase 프로젝트 (Authentication, Firestore, Storage 활성화) |
| **Firebase CLI** | Node.js 18 이상 + `npm install -g firebase-tools` (`flutterfire configure` 사용) |
| **Google Cloud** | Google Cloud 프로젝트 + **Maps SDK for Android** API 키 |

> 💡 확인된 실행 플랫폼은 **Android**입니다. ios/macos/linux/windows 디렉터리가 포함되어 있어 Flutter 표준 절차로 추가 빌드 가능합니다.

---

## 🚀 설치 및 실행 방법 (Installation & Getting Started)

### 1) 저장소 Clone

```bash
git clone https://github.com/ILLUMIN4TION/geo-feed-app.git
cd geofeed
```

### 2) 의존성 설치

```bash
flutter pub get
```

### 3) Firebase 프로젝트 연결 (본인 프로젝트)

```bash
# Firebase CLI 설치 및 로그인
npm install -g firebase-tools
firebase login

# Flutter 프로젝트에 Firebase 연동 (플랫폼 선택: android)
flutterfire configure
```

- `flutterfire configure`가 **`lib/firebase_options.dart`** 와 **`firebase.json`** 을 본인 프로젝트 기준으로 생성(재작성)합니다.
- 이후 **Firebase Console → 프로젝트 설정 → 앱 → `google-services.json` 다운로드**하여 아래 경로에 배치하세요. (`.gitignore`로 제외되어 있어 직접 추가해야 합니다)

```
android/app/google-services.json
```

### 4) Google Maps API 키 설정

`android/app/src/main/AndroidManifest.xml`에서 키 값을 본인 키로 교체합니다.

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_GOOGLE_MAPS_API_KEY" />
```

### 5) 실행

```bash
# 디버그 실행 (Android 에뮬레이터/기기 연결 필요)
flutter run

# 릴리즈 빌드 (APK)
flutter build apk --release
```

> 📌 첫 실행 후 지도/특정 화면에서 **"Firestore index" 생성 링크**가 콘솔에 출력되면, 해당 링크(또는 [인덱스 생성 방법](#- firestore-복합-인덱스))으로 복합 인덱스를 만들어 주세요.

---

## 🔑 환경 변수 (Environment Variables)

본 프로젝트는 `.env` 파일을 사용하지 않습니다. 설정 값은 아래 파일들에 직접 넣습니다.

| # | 항목 | 위치 | 설명 |
|:---|:---|:---|:---|
| 1 | **`google-services.json`** | `android/app/` | Firebase 프로젝트 인증 파일 (Console에서 다운로드, git 제외) |
| 2 | **`firebase_options.dart`** | `lib/` | `flutterfire configure`가 생성하는 각 플랫폼 Firebase 설정 |
| 3 | **Google Maps API 키** | `android/app/src/main/AndroidManifest.xml` | `com.google.android.geo.API_KEY` meta-data (Maps SDK for Android 키) |
| 4 | **iOS Maps 키** (iOS 빌드 시) | `ios/Runner/Info.plist` | `GOOGLE_MAPSApiKey` + `GIDClientID`(Google Sign-In) |

**iOS Info.plist 템플릿 (iOS 빌드 시만 필요)**

```xml
<key>GOOGLE_MAPSApiKey</key>
<string>YOUR_GOOGLE_MAPS_API_KEY</string>
<key>GIDClientID</key>
<string>YOUR_IOS_CLIENT_ID.apps.googleusercontent.com</string>
```

### 🔥 Firestore 복합 인덱스

다음 쿼리는 **복합 인덱스**가 필요합니다. (Console의 자동 생성 링크로 만들면 됩니다)

| 컬렉션 | 필드 | 사용처 |
|:---|:---|:---|
| `posts` | `location ASC` + `timestamp DESC` | 지도에 위치 있는 게시글 전체 조회 |
| `posts` | `userId ASC` + `timestamp DESC` | 프로필의 게시글 조회 |
| `posts` | `likes ASC` + `timestamp DESC` | 좋아요한 게시물 목록 |

### 🔒 Security Rules 참고

개발 편의상 인증된 사용자의 읽기/쓰기를 허용하는 간단한 규칙으로 동작합니다. 운영 배포 시 Firestore/Storage Security Rules를 반드시 검토해 주세요.

---


### 🏗 아키텍처

**상태 관리 (Provider)**
- `StreamProvider<User?>` — Firebase Auth 상태 스트림 → `AuthWrapper`가 로그인/미로그인 화면 분기
- `MyAuthProvider` — 로그인/회원가입/Google 로그인/팔로우/프로필
- `UploadProvider` — 이미지 선택 → EXIF 파싱 → 압축 → Storage/Firestore 업로드 파이프라인
- `PostProvider` — 피드(페이지네이션) / 지도 데이터, 좋아요·수정·삭제

**데이터 모델 (Firestore)**

```
posts/{postId}
├── userId        : String
├── imageUrl      : String  (원본, Storage URL)
├── thumbnailUrl  : String  (썸네일, Storage URL)
├── caption       : String
├── location      : GeoPoint (포토스팟)
├── timestamp     : Timestamp
├── exifData      : Map     (Make, Model, Aperture, ShutterSpeed, ISO, FocalLength)
├── likes         : [uid...]
└── tags          : [String...]

users/{uid}
├── username, email, profileImageUrl, createdAt
└── followers, following  : [uid...]

Storage
├── uploads/{uid}/{ts}_original.webp
├── uploads/{uid}/{ts}_thumb.webp
└── user_profiles/{uid}.jpg
```

**프로젝트 구조**

```
lib/
├── main.dart                  # Firebase 초기화, Provider 등록, AuthWrapper
├── firebase_options.dart      # (flutterfire configure 생성)
├── models/                    # Post, UploadData, PostClusterItem
├── providers/                 # MyAuthProvider, UploadProvider, PostProvider
├── screens/                   # home, map, feed, upload, detail, camera_recipe,
│   └── auth/                  #   profile, search, liked_posts, login, register ...
├── widgets/                   # post_card, cluster sheet, location_text, ...
└── utils/                     # theme, view_state, map_cluster_service
```

---



