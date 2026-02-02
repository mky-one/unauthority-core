# PROMPT MASTER: PROYEK BLOCKCHAIN UNAUTHORITY (UAT) - THE SOVEREIGN MACHINE (FINAL v9.0)

**Role:** Bertindaklah sebagai Senior Blockchain Architect dan Lead Developer dengan spesialisasi pada Distributed Systems, Game Theory, dan Cryptography.

**Misi:** Membangun blockchain "Unauthority" (UAT) yang 100% Immutable, Permissionless, dan Decentralized. Sistem ini harus tahan sensor, tidak memiliki fungsi "Admin Keys", dan memiliki ekonomi yang berkelanjutan tanpa inflasi supply.

---

## 1. IDENTITAS & SPESIFIKASI (CORE)
* **Nama Proyek:** Unauthority
* **Ticker:** UAT
* **Satuan Terkecil:** 1 UAT = 100.000.000 Void (VOI)
* **Total Supply:** 21.936.236 UAT (Fixed/Hard-coded). Tidak ada minting baru setelah genesis.
* **Struktur Data:** Block-Lattice (DAG) + Global State untuk Smart Contract.
* **Konsensus:** Asynchronous Byzantine Fault Tolerance (aBFT). Finalitas < 3 detik.
* **Kriptografi:** Post-Quantum Secure (CRYSTALS-Dilithium).

## 2. SMART CONTRACT & API (PERMISSIONLESS)
* **Engine:** Unauthority Virtual Machine (UVM) berbasis WASM.
* **Sifat:** Permissionless. Deploy kontrak tanpa whitelist/izin.
* **Bahasa:** Mendukung Rust, C++, AssemblyScript, dan Go.
* **API Access:** Full Node menyediakan REST API & gRPC lengkap untuk eksternal developer.

## 3. DISTRIBUSI OTOMATIS (93% PUBLIC - PURE DECENTRALIZED)
* **Alokasi Publik:** 20.400.700 UAT.
* **Mekanisme:** Proof-of-Burn (PoB).
* **Aset Diterima:** BTC & ETH (Desentralis Only).
* **Aset Ditolak:** USDT, USDC, XRP (Centralized Assets).
* **Rumus Kelangkaan:** Bonding curve yang membuat UAT semakin sulit didapat seiring sisa supply menipis.
* **Oracle:** Decentralized Medianizer Oracle.

## 4. MEKANISME ANTI-WHALE (KEADILAN JARINGAN)
* **Dynamic Fee Scaling:** Biaya gas naik eksponensial (x2, x4) jika satu alamat melakukan spamming transaksi dalam waktu singkat.
* **Validator Voting Cap (Quadratic Voting):**
    * Rumus: $VotingPower = \sqrt{TotalStake}$.
    * Tujuan: Mencegah satu entitas kaya menguasai konsensus (1 Node 1000 UAT < 10 Node 100 UAT).
* **Burn Limit per Block:** Membatasi jumlah UAT yang bisa didapat lewat PoB per blok waktu.

## 5. VALIDATOR REWARDS & EKONOMI (NON-INFLATIONARY)
* **Transaction Fees (Gas) as Reward:** 100% Biaya Gas diberikan kepada Validator yang memfinalisasi blok. Tidak ada koin baru (Fixed Supply).
* **Minimum Staking Requirement:** Untuk menjadi Validator aktif, node wajib mengunci (Stake) minimal 1.000 UAT.
* **Priority Tipping:** User dapat memberikan tip tambahan (Priority Fee) untuk prioritas transaksi.

## 6. KEAMANAN VALIDATOR NODE (INFRASTRUCTURE)
* **Sentry Node Architecture:**
    * *Validator Node (Private):* Terhubung ke Sentry via VPN/P2P terenkripsi. IP tersembunyi.
    * *Sentry Node (Public):* Shield publik menghadapi DDoS.
* **Automated Slashing:** Double Signing (Slash 100% & Ban) dan Extended Downtime (Slash 1%).
* **P2P Encryption:** Noise Protocol Framework untuk seluruh komunikasi antar node.

## 7. ALOKASI DEV & GENESIS (7% DEV)
* **Dev Supply:** 1.535.536 UAT.
* **Distribusi:** 8 Wallet Permanen (3 untuk Node Awal, 5 untuk Treasury).
* **Zero Admin:** Tidak ada kunci admin atau fungsi "Pause" pada jaringan.

## 8. TUGAS DAN OUTPUT YANG DIMINTA
1. **Struktur Proyek:** Susun struktur direktori proyek Rust (Workspace architecture).
2. **Genesis Generator (genesis_generator.rs):** Buat script inisialisasi blok awal. Wajib generate 8 pasang Key Dev (Address & Private Key) dan cetak ke terminal (sekali saja) agar bisa dicatat manual.
3. **Logic Validator Reward:** Tuliskan fungsi Rust tentang bagaimana biaya transaksi (Gas) dihitung dan ditransfer otomatis ke akun Validator.
4. **Konfigurasi Node (validator.toml):** Buat contoh file config yang memisahkan `public_sentry_addr` dan `private_signer_addr`.