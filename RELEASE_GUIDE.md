# VeoPlay – Play Store release guide (हिन्दी)

> ज़रूरी: ये सब एक बार का काम है। `release.yml` को पहली बार चलाने पर अगर signing वाला error आए, तो पूरा log और `android/app/build.gradle` (या `.kts`) भेज देना।

## 1. Play Developer account
- एक बार का शुल्क लगभग **$25** (Console में अभी की सही रकम देख लेना), और पहचान की जाँच (ID verification) होती है।
- नया **personal** account हो तो production से पहले **12 testers × लगातार 14 दिन** का closed test ज़रूरी है। इसलिए जितना जल्दी हो सके शुरू करो।

## 2. Upload keystore बनाओ (सिर्फ़ एक बार)
कंप्यूटर पर (या फ़ोन में Termux: `pkg install openjdk-17`):
```
keytool -genkeypair -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
- जो password डालो उसे **अलग से सुरक्षित लिख लो**, और `upload-keystore.jks` की कम से कम 2 जगह backup रखो।
- इस फ़ाइल को **कभी GitHub repo में मत डालना**।

## 3. Base64 बनाओ
```
base64 -w0 upload-keystore.jks
```
जो लंबा text आए उसे copy कर लो।

## 4. GitHub Secrets (Settings → Secrets and variables → Actions → New repository secret)
| नाम | क्या डालना है |
|---|---|
| `KEYSTORE_BASE64` | ऊपर वाला लंबा base64 text |
| `KEYSTORE_PASSWORD` | keystore का password |
| `KEY_ALIAS` | `upload` (अगर यही alias रखा) |
| `KEY_PASSWORD` | key का password (अक्सर वही) |

## 5. Signed AAB बनाओ
1. `release.yml` को repo में `.github/workflows/release.yml` नाम से रखो।
2. GitHub → Actions → **Release AAB (Play Store)** → Run workflow।
3. पूरा होने पर नीचे **Artifacts** में `VeoPlay-AAB` को download करो (zip खोलो → `app-release.aab`)।
4. log में **"Signing जाँचो"** step खोलो: `Owner:` में तुम्हारा नाम दिखे। अगर **Android Debug** दिखे तो signing नहीं लगी (मुझे log भेजो)।
5. repo **public** हो तो artifact कोई भी GitHub उपयोगकर्ता देख सकता है। AAB download करके Artifacts से तुरंत हटा दो, या repo private रखो।

## 6. Version कैसे बढ़े
- `release.yml` हर बार बढ़ती `build number` (`github.run_number`) अपने आप लगाता है, तो हर नया upload Play को स्वीकार होगा।
- App का version name `pubspec.yaml` की `version: 1.0.0+1` में `+` से पहले वाला हिस्सा है। बड़ा बदलाव हो तो उसे `1.0.1`, `1.1.0` करो।

## 7. Play Console में (क्रम से)
1. Create app → नाम `VeoPlay – Video & Music Player`, भाषा, App/Free।
2. **Privacy Policy URL:** `privacy_policy.html` को GitHub Pages पर डालकर उसका link (steps `play_store_listing.md` में)।
3. App content: Ads (No), App access, Content rating, Target audience (13+), **Data safety**, और media permission का declaration। सब जवाब `play_store_listing.md` में तैयार हैं।
4. Store listing: वर्णन, icon 512, feature graphic 1024×500, screenshots।
5. **Testing → Closed testing** → नया track → AAB upload → testers (emails या Google Group) जोड़ो → opt-in link सबको भेजो।
6. 12 testers लगातार 14 दिन opted-in रहें। फिर Console में **Apply for production**।
7. Closed test के दौरान: Pre-launch report, **Android vitals** (crash/ANR) देखो, और testers से Settings → "Problem report भेजो" वाला log माँगो।

## 8. Target API
तुम्हारा Flutter बहुत नया है, तो उसका default targetSdk अक्सर Play की माँग पूरी करता है। फिर भी Console अगर "target API level" की चेतावनी दे, तो मुझे `android/app/build.gradle` भेज देना।
