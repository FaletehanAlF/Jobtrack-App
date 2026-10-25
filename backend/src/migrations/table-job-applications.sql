create table job_applications(
	id INT AUTO_INCREMENT PRIMARY KEY NOT NULL,
	applicant_id INT NOT NULL,
	job_id INT NOT NULL,
	status ENUM('submitted', 'rejected') NOT NULL DEFAULT 'submitted',
	created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	active_slot TINYINT GENERATED ALWAYS AS (
		CASE WHEN status = 'rejected' THEN NULL ELSE 1 END
	) STORED,
	unique key uq_application_active (applicant_id, job_id, active_slot),
	index idx_application_job_id (job_id),
	constraint fk_application_applicant foreign key (applicant_id) references users(id) on delete cascade,
	constraint fk_application_job foreign key (job_id) references jobs(id) on delete cascade
);
