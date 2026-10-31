#!/bin/bash
# VeoPlay: Play Store ke liye upload keystore banane ki script
# Chalane ka tarika:  bash make_keystore.sh

cd ~ || exit 1

if ! command -v keytool >/dev/null 2>&1; then
  echo "keytool nahi mila. Java install hona chahiye (Termux me: pkg install openjdk-17)"
  exit 1
fi

read -r -s -p "Naya password likho (kam se kam 8 akshar, sirf letters aur numbers): " PW
echo
read -r -s -p "Wahi password dobara likho: " PW2
echo

if [ "$PW" != "$PW2" ]; then
  echo "Dono password alag hain. Dobara chalao."
  exit 1
fi
if [ "${#PW}" -lt 8 ]; then
  echo "Password kam se kam 8 akshar ka rakho."
  exit 1
fi
case "$PW" in
  *[!A-Za-z0-9]*) echo "Sirf letters aur numbers use karo (koi space ya symbol nahi)."; exit 1 ;;
esac

if [ -f upload-keystore.jks ]; then
  echo "upload-keystore.jks pehle se bani hui hai. Purani ko mat mitao. Pehle usko kisi aur naam se rakh lo."
  exit 1
fi

keytool -genkeypair -v \
  -keystore upload-keystore.jks \
  -storetype PKCS12 \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload \
  -storepass "$PW" -keypass "$PW" \
  -dname "CN=Akhlakh Ansari, OU=VeoPlay, O=VeoPlay, C=IN" || { echo "Keystore nahi bani."; exit 1; }

base64 -w0 upload-keystore.jks > keystore_base64.txt

echo
echo "========== ho gaya =========="
echo "Files ~ (home) folder me bani hain:"
echo "  upload-keystore.jks   <- ise 2 jagah backup rakho, repo me MAT dalo"
echo "  keystore_base64.txt   <- iska poora text GitHub Secret KEYSTORE_BASE64 me jayega"
echo
echo "GitHub Secrets me ye 4 daalne hain:"
echo "  KEYSTORE_BASE64   = keystore_base64.txt ka poora text"
echo "  KEYSTORE_PASSWORD = jo password abhi likha"
echo "  KEY_ALIAS         = upload"
echo "  KEY_PASSWORD      = wahi password (KEYSTORE_PASSWORD jaisa)"
