```python
import os

replacements = {
    "चुने गए": "Selected",
    "कोई वीडियो नहीं मिला": "No videos found",
    "Settings खोलें": "Open Settings",
    "नीचे खींचकर दोबारा खोजें": "Pull down to rescan",
    "गाने लोड हो रहे हैं...": "Loading songs...",
    "कोई गाना नहीं मिला": "No songs found",
    "अभी कोई Playlist नहीं है, ऊपर + दबाकर बनाओ": "No Playlist yet, tap + to create",
    "नया पहले": "Newest First",
    "पुराना पहले": "Oldest First",
    "नाम (A-Z)": "Name (A-Z)",
    "साइज़ (बड़ा पहले)": "Size (Largest First)",
    "Favorite पहले ❤️": "Favorites First ❤️",
    "नया गाना पहले": "Newest First",
    "पुराना गाना पहले": "Oldest First",
    "नाम (A से Z)": "Name (A to Z)",
    "Video छुपा दी गई": "Video hidden",
    "Folder छुपा दिया गया": "Folder hidden",
    "गाना छुपा दिया गया": "Song hidden",
    "PIN सेट हो गया": "PIN set successfully",
    "गलत PIN!": "Wrong PIN!",
    "वीडियो डिलीट करें?": "Delete video?",
    "ये वीडियो डिवाइस से हमेशा के लिए हट जाएगी।": "This video will be permanently deleted from your device.",
    "गाना डिलीट करें?": "Delete song?",
    "ये गाना डिवाइस से हमेशा के लिए हट जाएगा।": "This song will be permanently deleted from your device.",
    "नाम बदलें": "Rename",
    "अपना नाम लिखें": "Enter your name",
    "नया नाम डालें": "Enter new name",
    "वीडियो नहीं खुल पाया": "Could not open video",
    "वापस जाएँ": "Go Back",
    "मिनट बाकी": "minutes left",
    "Sleep Timer हटाओ": "Remove Sleep Timer",
    "Sleep timer हटाया": "Sleep timer removed",
    "Screenshot नहीं बन पाया": "Could not take screenshot",
    "Gallery की permission दो": "Gallery permission required",
    "Screenshot Gallery में सेव हो गया": "Screenshot saved to Gallery",
    "Screenshot में दिक्कत आई": "Error taking screenshot",
    "Subtitle फाइल खाली है या पढ़ी नहीं जा सकी": "Subtitle file is empty or unreadable",
    "Subtitle लोड नहीं हो पाया": "Could not load subtitle",
    "पहले कोई गाना चलाओ": "Play a song first",
    "अभी लिस्ट से गाना नहीं चल रहा": "Not playing from a list currently",
    "अगला चलेगा": "will play next",
    "फ़ाइल नहीं मिली": "File not found",
    "Share नहीं हो पाया": "Failed to share",
    "सारा डेटा हटाएँ?": "Clear all data?",
    "सारी settings, favorites, playlists और recent history हट जाएगी। गाने/वीडियो फोन में रहेंगे।": "All settings, favorites, playlists, and history will be deleted. Songs/videos will remain on your phone.",
    "✅ सारा डेटा हटा दिया": "✅ All data cleared",
    "Problem Report भेजें": "Send Problem Report",
    "अगर ऐप में कोई दिक्कत आई हो तो लॉग फ़ाइल शेयर करें": "Share log file if you faced any issues",
    "✅ कोई error log नहीं मिला, ऐप ठीक काम कर रहा है": "✅ No error log found, app is working fine",
    "वीडियो चलाते समय ब्राइटनेस": "Brightness while playing video",
    "वीडियो खत्म होते ही अगला चलाएं": "Play next video automatically",
    "जहाँ छोड़ा था वहीं से चलाएं": "Resume from where you left",
    "स्क्रीन पर दाएँ-बाएँ swipe करके आगे-पीछे": "Swipe left/right to seek",
    "बाएँ आधे पर brightness, दाएँ आधे पर volume": "Left side for brightness, right for volume",
    "बाएँ/दाएँ double-tap से ±10 सेकंड, बीच में pause": "Double-tap left/right for ±10s, center to pause",
    "दबाकर रखने पर 2x speed": "Hold to play at 2x speed",
    "नए वीडियो पर लागू होगी": "Applies to new videos",
    "नए गाने पर लागू होगी": "Applies to new songs",
    "वीडियो और गाने फिर से scan करें": "Scan videos and songs again",
    "वीडियो और गाने दोबारा scan हो रहे हैं...": "Rescanning videos and songs...",
    "थंबनेल की cache हटाएं": "Clear thumbnail cache",
    "Favorites, playlists, settings हटाएं": "Clear favorites, playlists, settings",
    "छुपाए गए वीडियो और गाने": "Hidden videos and songs",
    "हमारी privacy policy पढ़ें": "Read our privacy policy",
    "वीडियो या गाने नहीं दिख रहे?": "Videos or songs not showing?",
    'फ़ोन की Settings → Apps → VeoPlay → Permissions में Photos/Videos और Music की permission दें। फिर Home पर नीचे खींचें, या Settings में "Rescan Media" दबाएँ।': 'Grant Photos/Videos and Music permissions in Phone Settings → Apps → VeoPlay → Permissions. Then pull down on Home, or tap "Rescan Media" in Settings.',
    "वीडियो चलाते समय क्या-क्या कर सकते हैं?": "What can I do while playing a video?",
    "डबल-टैप से ±10 सेकंड, लंबा दबाने पर 2x speed, ऊपर-नीचे swipe से brightness और volume, और बाएँ-दाएँ खींचकर seek।": "Double-tap for ±10s, long press for 2x speed, swipe up/down for brightness and volume, and swipe left/right to seek.",
    "वीडियो वहीं से कैसे शुरू करें जहाँ छोड़ी थी?": "How to resume a video where I left off?",
    "यह अपने-आप होता है। Settings में Resume चालू रखें।": "It happens automatically. Keep Resume enabled in Settings.",
    "गाना अपने-आप कैसे बंद करें?": "How to stop music automatically?",
    "Music player में घड़ी वाले आइकन से Sleep Timer लगाएँ।": "Use the clock icon in the Music player to set a Sleep Timer.",
    "Feedback या समस्या बताने के लिए संपर्क करें:": "Contact for Feedback or issues:",
    "कॉपी हो गया": "Copied",
    "कोई history नहीं है": "No history",
    "Play Store पर rate करें": "Rate on Play Store",
    "वीडियो का नाम खोजें...": "Search video name...",
    "वीडियो या फोल्डर का नाम लिखें": "Enter video or folder name",
    "कुछ नहीं मिला": "Nothing found",
    "इस Playlist में कोई वीडियो नहीं है": "No videos in this Playlist",
    "Dual Video का screenshot सेव हो गया": "Dual Video screenshot saved",
    "Dual के लिए लिस्ट में कम से कम 2 वीडियो चाहिए": "Need at least 2 videos in list for Dual mode",
    "इस device पर PiP support नहीं है": "PiP not supported on this device",
    "इस वीडियो में audio track की जानकारी नहीं मिली": "No audio track info found",
    "इस वीडियो में सिर्फ़ एक audio track है": "Only one audio track available",
    "Audio track बदल गया": "Audio track changed",
    "Audio track नहीं बदल पाया": "Failed to change audio track",
    "फ़ाइल से लोड करो (.srt / .vtt)": "Load from file (.srt / .vtt)",
    "😴 Sleep timer: video रुक गया": "😴 Sleep timer: video paused",
    "ऑडियो मोड में नहीं चल पाया": "Failed to play in audio mode",
    "ऑडियो मोड में चल रहा है": "Playing in audio mode",
    "📸 Screenshot बन रहा है...": "📸 Generating screenshot..."
}

print("Files update ho rahi hain... thoda intezaar karein.")
for root, dirs, files in os.walk("lib"):
    for file in files:
        if file.endswith(".dart"):
            path = os.path.join(root, file)
            with open(path, "r", encoding="utf-8") as f:
                content = f.read()

            changed = False
            for hi, en in replacements.items():
                if hi in content:
                    content = content.replace(hi, en)
                    changed = True

            if changed:
                with open(path, "w", encoding="utf-8") as f:
                    f.write(content)
                print(f"Updated: {path}")

print("✅ Saari files update ho gayi hain! Ab aap GitHub par push kar sakte hain.")
```
