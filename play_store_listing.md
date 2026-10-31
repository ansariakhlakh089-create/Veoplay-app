# VeoPlay – Play Store Listing (DRAFT)

> यह draft है। सारे features अपने फ़ोन पर test करने के बाद ही final करना, और जो चीज़ चलती न हो उसे वर्णन से हटा देना।
> जहाँ [ ] लिखा है वहाँ अपनी जानकारी भरना।

## 1. बुनियादी जानकारी
| चीज़ | मान |
|---|---|
| App name (30 अक्षर तक) | VeoPlay – Video & Music Player |
| Category | Video Players & Editors |
| Contact email | [YOUR-EMAIL@example.com] |
| Privacy Policy URL | `https://<github-username>.github.io/<repo-name>/privacy.html` (नीचे GitHub Pages के steps देखो) |
| Ads | No ads (अभी app में ads नहीं हैं) |

## 2. Short description (80 अक्षर तक)
- English (76): `Video & music player with gestures, subtitles, equalizer, PiP and bookmarks.`
- हिन्दी (68): `जेस्चर, सबटाइटल, इक्वलाइज़र, PiP वाला तेज़ वीडियो और म्यूज़िक प्लेयर`

## 3. Full description (English)
VeoPlay is a fast, simple video and music player for your phone.

VIDEO
• Plays almost every format, including MKV
• Swipe for brightness, volume and seeking; double-tap to skip ±10 seconds; hold for 2x speed
• Subtitles (.srt) with colour, background, size and position; fix wrong Hindi characters by choosing the encoding
• Audio track selection and audio delay
• Equalizer, video filters (brightness, contrast, saturation, gamma)
• Pinch to zoom, aspect ratio (16:9, 4:3, 21:9 and more)
• Picture-in-Picture, rotation lock, auto-rotate with your phone
• Bookmarks, A-B repeat, sleep timer, playback speed
• Resume where you left off
• Play two videos side by side (Dual mode)
• Play a video link (network stream)

MUSIC
• Songs, albums, artists, playlists and favorites
• Equalizer and sleep timer
• Notification and lock-screen controls with Favorite and Repeat/Shuffle buttons

PRIVATE
• No account, no ads, no tracking. Your files stay on your phone.

## 4. पूरा वर्णन (हिन्दी)
VeoPlay आपके फ़ोन के लिए तेज़ और आसान वीडियो व म्यूज़िक प्लेयर है।

वीडियो
• लगभग हर format चलता है (MKV भी)
• swipe से brightness, volume और seek; double-tap से ±10 सेकंड; दबाकर रखने पर 2x speed
• सबटाइटल (.srt): रंग, background, साइज़ और position बदलें; हिन्दी अक्षर गड़बड़ दिखें तो encoding चुनें
• Audio track चुनना और audio delay
• Equalizer और video filters (brightness, contrast, saturation, gamma)
• Pinch से zoom, aspect ratio (16:9, 4:3, 21:9 आदि)
• Picture-in-Picture, rotation lock, फ़ोन घुमाने पर अपने-आप rotate
• Bookmarks, A-B repeat, sleep timer, playback speed
• जहाँ छोड़ा था वहीं से चालू
• दो वीडियो साथ-साथ (Dual mode)
• वीडियो link (network stream) चलाना

म्यूज़िक
• गाने, albums, artists, playlists और favorites
• Equalizer और sleep timer
• Notification और lock-screen में Favorite और Repeat/Shuffle बटन

प्राइवेट
• कोई account नहीं, कोई ads नहीं, कोई tracking नहीं। आपकी फ़ाइलें फ़ोन में ही रहती हैं।

## 5. Play Console के जवाब (cheat-sheet)

### Data safety
| सवाल | जवाब |
|---|---|
| Does your app collect or share any required user data types? | No |
| Is all data encrypted in transit? | लागू नहीं (हम कुछ भेजते ही नहीं) |
| Can users request data deletion? | App के अंदर Settings → Clear All Data, या uninstall |
| नोट | Network link चलाने पर वीडियो वाला server आपका IP देख सकता है। यह तुम्हारा server नहीं है और ऐप इसे इकट्ठा नहीं करता। फिर भी form भरते वक़्त Console के सवाल ध्यान से पढ़ो। |

### App content
- Target audience: 13+ (बच्चों के लिए नहीं बना)
- Content rating questionnaire: कोई हिंसा, जुआ, user-generated content नहीं, तो सामान्यतः Everyone
- Ads declaration: No ads
- App access: सारे features बिना login के उपलब्ध

### Permissions declaration (Photo/Video और Audio)
Play Console में media permissions के बारे में जो सवाल आए, उसका मुख्य जवाब:
> "VeoPlay is a video and music player. Reading the videos and songs stored on the device (READ_MEDIA_VIDEO / READ_MEDIA_AUDIO) is the core functionality of the app: it lists and plays the user's media files. Files are not uploaded or shared."

### Foreground service (media playback)
> "Used only to keep music playback running with the screen off, with the standard media notification and controls."

## 6. Screenshots (कम से कम 2, बेहतर 6–8)
1. Home: वीडियो की list
2. प्लेयर (landscape), controls के साथ
3. Equalizer या Video Filters की screen
4. Subtitle settings
5. Dual video
6. Music player screen
7. Notification / lock-screen controls
8. Dark और Light theme (अगर चाहो)

तकनीकी: PNG/JPG, हर तरफ़ 320–3840 px। Feature graphic: 1024×500। Icon: 512×512।

## 7. Privacy Policy को मुफ़्त online लाना (GitHub Pages)
1. repo में फोल्डर `docs` बनाओ और `privacy_policy.html` को वहाँ `privacy.html` नाम से रखो।
2. फ़ाइल में [YOUR-EMAIL@example.com] की जगह अपना असली email डालो (दो जगह)।
3. GitHub → repo की Settings → Pages → Branch: `main`, Folder: `/docs` → Save।
4. 1–2 मिनट बाद link बनेगा: `https://<github-username>.github.io/<repo-name>/privacy.html`
5. उस link को browser में खोलकर देखो, और वही link Play Console में डालो।

## 8. Closed testing (नया personal account हो तो)
- 12 testers × लगातार 14 दिन, तब ही production के लिए apply कर सकते हो।
- testers को closed test का opt-in link भेजो (WhatsApp से), और सब उसी link से install करें।
