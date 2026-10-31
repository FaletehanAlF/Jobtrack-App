-- Tabel notifikasi untuk jobseeker dan recruiter.
--
-- BELUM DIJALANKAN pada database development `jobtrack`. File ini disiapkan
-- untuk ditinjau dan dijalankan manual setelah disetujui.
--
-- Kenapa butuh tabel baru: sistem belum memiliki mekanisme notifikasi sama
-- sekali. Tanpa kolom penyimpanan, notifikasi hanya bisa "dikarang" saat
-- dibaca — dan itu melanggar aturan bahwa notifikasi harus berasal dari
-- kejadian nyata.
--
-- Catatan konsistensi: notifikasi dibuat di dalam transaksi yang sama dengan
-- INSERT job_applications atau UPDATE status-nya, sehingga tidak pernah ada
-- notifikasi untuk perubahan yang gagal tersimpan.

CREATE TABLE notifications (
	id INT AUTO_INCREMENT PRIMARY KEY NOT NULL,

	-- Penerima notifikasi. Diisi dari data pemilik entitas di database
	-- (jobs.recruiter_id atau job_applications.applicant_id), bukan dari
	-- input pengguna. Notifikasi ikut terhapus bila akunnya dihapus.
	recipient_id INT NOT NULL,

	-- Jenis kejadian. Hanya dua kejadian yang saat ini menghasilkan
	-- notifikasi; menambah jenis baru berarti menambah nilai ENUM.
	--   application_received : jobseeker melamar lowongan recruiter
	--   application_rejected : recruiter menolak lamaran
	type ENUM('application_received', 'application_rejected') NOT NULL,

	-- Ringkasan siap tampil. Tidak memuat email, password, atau token.
	message VARCHAR(255) NOT NULL,

	-- Referensi entitas terkait. Nullable bila datanya tidak tersedia
	-- (mis. lowongan terhapus) supaya notifikasi lama tidak ikut hilang.
	job_id INT NULL,
	application_id INT NULL,

	created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	read_at TIMESTAMP NULL DEFAULT NULL,

	-- Daftar notifikasi selalu difilter penerima dan diurutkan terbaru.
	index idx_notifications_recipient (recipient_id, created_at),

	-- Hitungan belum dibaca memakai kolom yang sama; indeks parsial tidak
	-- tersedia di MySQL, jadi (recipient_id, read_at) yang dipakai.
	index idx_notifications_unread (recipient_id, read_at),

	-- Notifikasi tidak boleh ganda untuk kejadian yang sama. Retry atau
	-- pemanggilan berulang pada lamaran/status yang sama gagal di sini,
	-- bukan membuat baris kedua.
	unique key uq_notification_event (recipient_id, type, application_id),

	constraint fk_notification_recipient foreign key (recipient_id)
		references users(id) on delete cascade,

	-- Referensi entitas memakai SET NULL, bukan CASCADE: menghapus lowongan
	-- tidak boleh menghapus riwayat notifikasi penerimanya.
	constraint fk_notification_job foreign key (job_id)
		references jobs(id) on delete set null,

	constraint fk_notification_application foreign key (application_id)
		references job_applications(id) on delete set null
);
