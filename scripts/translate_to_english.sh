#!/bin/bash
# Bulk translation script for Indonesian to English in UAT codebase

# Main translation file
FILE="crates/uat-node/src/main.rs"

sed -i '' '
# Error messages
s/Saldo tidak cukup/Insufficient balance/g
s/Alamat tidak ditemukan/Address not found/g
s/tidak valid/invalid/g
s/tidak memenuhi/does not meet/g
s/tidak cukup untuk mengirim/insufficient to send/g
s/tidak didukung/not supported/g
s/tidak dikenal/not recognized/g
s/tidak menemukan/could not find/g

# Success/failure messages
s/gagal/failed/g
s/berhasil/successful/g
s/dikirim/sent/g
s/diterima/received/g
s/dimulai/started/g
s/sudah terdaftar/already registered/g
s/sudah digunakan/already used/g

# Actions
s/Cek /Check /g
s/Kirim /Send /g
s/Masukkan /Insert /g
s/Ambil /Get /g
s/Tambahkan /Add /g

# States
s/sedang dalam proses/currently in process/g
s/dalam antrian/in queue/g
s/sudah pernah/already/g

# Other common words
s/saldo/balance/g
s/alamat/address/g
s/akun/account/g
s/blok/block/g
s/koin/coin/g
s/jumlah/amount/g
s/power awal/initial power/g

# Comments
s/Proteksi/Protection/g
s/Limitasi/Limitation/g
s/Sinkronisasi/Synchronization/g
s/Verifikasi/Verification/g
s/Mohon tunggu/Please wait/g
s/Catatan:/Note:/g
s/Biar kelihatan/To show/g
s/untuk debugging/for debugging/g

# Phrases
s/Maksimal/Maximum/g
s/Pastikan/Ensure/g
s/Begitu ada/Once there is/g
s/kita kirim ulang/we resend/g
s/Jika /If /g
s/atau /or /g
s/dengan /with /g
s/dari /from /g
s/ke /to /g
s/di /in /g
s/untuk /for /g
' "$FILE"

echo "✅ Translated $FILE"

# Core lib
FILE="crates/uat-core/src/lib.rs"
sed -i '' '
s/tidak memenuhi kriteria/does not meet criteria/g
s/Verifikasi kunci publik gagal/Public key verification failed/g
s/Urutan blok tidak valid/Invalid block sequence/g
s/Diharapkan/Expected/g
s/dapat/got/g
s/Saldo tidak cukup untuk mengirim/Insufficient balance to send/g
s/Tambahkan saldo ke akun peminta/Add balance to requesting account/g
s/Penerima mendapatkan penambahan saldo/Receiver gets balance addition/g
' "$FILE"

echo "✅ Translated $FILE"

# Oracle
FILE="crates/uat-node/src/oracle.rs"
sed -i '' '
s/Catatan: Ini draf sederhana/Note: This is a simple draft/g
s/di produksi butuh/in production needs/g
s/pengecekan address tujuan/destination address check/g
s/Memverifikasi/Verify/g
' "$FILE"

echo "✅ Translated $FILE"

# Build script
FILE="crates/uat-node/build.rs"
sed -i '' '
s/tidak deprecated/not deprecated/g
' "$FILE"

echo "✅ Translated $FILE"

# Crypto lib
FILE="crates/uat-crypto/src/lib.rs"
sed -i '' '
s/Memverifikasi tanda tangan/Verify signature/g
' "$FILE"

echo "✅ Translated $FILE"

echo ""
echo "🎉 All translations complete!"
