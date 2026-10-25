create table job_applications(
	id INT AUTO_INCREMENT PRIMARY KEY NOT NULL,
	applicant_id INT NOT NULL,
	job_id INT NOT NULL,

	-- Versi pertama hanya membuat lamaran dengan status awal 'submitted'.
	-- Nilai 'rejected' sudah didefinisikan sekarang karena produk sepakat
	-- lamaran boleh diajukan ulang setelah lamaran sebelumnya ditolak.
	-- Endpoint yang mengubah status (workflow recruiter) belum dibuat pada
	-- tahap ini, jadi 'rejected' masih tidak akan terisi oleh API apa pun.
	status ENUM('submitted', 'rejected') NOT NULL DEFAULT 'submitted',
	created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

	-- Kolom hasil turunan (generated column): bernilai 1 untuk lamaran aktif
	-- dan NULL untuk sisanya. MySQL mengisinya dari kolom status sendiri setiap
	-- kali baris ditulis, jadi tidak mungkin tidak sinkron dengan status.
	active_slot TINYINT GENERATED ALWAYS AS (
		CASE WHEN status = 'rejected' THEN NULL ELSE 1 END
	) STORED,

	-- Garansi anti-duplikat sampai tingkat database, termasuk saat dua request
	-- melamar bersamaan (baris kedua ditolak MySQL dengan ER_DUP_ENTRY):
	--   - maksimal SATU lamaran aktif untuk pasangan (applicant_id, job_id).
	--   - baris dengan active_slot NULL boleh lebih dari satu, sehingga riwayat
	--     lamaran yang sudah ditolak tetap tersimpan dan lamaran ulang selalu
	--     bisa dibuat tanpa menghapus/merusak baris lama.
	--
	-- Tidak memakai partial unique index karena MySQL tidak mendukungnya.
	-- Butuh MySQL yang mendukung index pada generated column (MySQL 8.x aman;
	-- didukung sejak 5.7.8). Verifikasi versi server lewat SELECT VERSION()
	-- dan pastikan versinya memenuhi syarat sebelum migration ini dijalankan.
	unique key uq_application_active (applicant_id, job_id, active_slot),

	index idx_application_job_id (job_id),

	-- Lamaran ikut terhapus bila akun pelamarnya dihapus,
	-- mengikuti pola FK di tabel jobs.
	constraint fk_application_applicant foreign key (applicant_id) references users(id) on delete cascade,
	-- Lamaran ikut terhapus bila lowongannya dihapus, supaya setiap lamaran
	-- selalu punya lowongan pemiliknya yang masih ada (JOIN daftar lamaran
	-- tidak pernah kehilangan data lowongannya).
	constraint fk_application_job foreign key (job_id) references jobs(id) on delete cascade
);
