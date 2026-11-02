create table jobs(
	id INT AUTO_INCREMENT PRIMARY KEY NOT NULL,
	recruiter_id INT NOT NULL,
	title VARCHAR(150) NOT NULL,
	description TEXT NOT NULL,
	company VARCHAR(100) NOT NULL,
	location VARCHAR(100) NOT NULL,
	created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

	index idx_recruiter_id (recruiter_id),

	constraint fk_jobs_recruiter foreign key (recruiter_id) references users(id) on delete cascade
);
