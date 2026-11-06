#!/bin/bash
# ==============================================================================
# Script biên dịch tự động Tweak VideoStarRecorder thành file .o và .dylib
# Chạy trên macOS, Linux (Theos) hoặc trực tiếp trên iPhone qua Terminal / SSH
# ==============================================================================

set -e

echo "[*] Kiểm tra môi trường Theos..."
if [ -z "$THEOS" ]; then
    export THEOS=~/theos
fi

if [ ! -d "$THEOS" ]; then
    echo "[!] Không tìm thấy thư mục THEOS tại $THEOS. Vui lòng cài đặt Theos trước."
    exit 1
fi

echo "[*] Dọn dẹp bản build cũ..."
make clean

echo "[*] Đang biên dịch các file .m và .xm thành các file object .o..."
make

echo "[*] Kiểm tra các file .o đã được sinh ra:"
find .theos/obj -name "*.o" || true

echo "[*] Đóng gói hoàn chỉnh thành file .dylib và .deb..."
make package FINALPACKAGE=1

echo "[+] BIÊN DỊCH THÀNH CÔNG!"
echo "[+] File .dylib nằm tại: .theos/obj/debug/VideoStarRecorder.dylib"
echo "[+] File .deb nằm tại thư mục: packages/"
