create table users(
	id int auto_increment primary key not null,
	username VARCHAR(50) NOT NULL,
	email VARCHAR(255) NOT NULL UNIQUE,
	password_hash VARCHAR(255) NOT NULL,
	role ENUM('jobseeker', 'recruiter') NOT NULL DEFAULT 'jobseeker',
	created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

select * from users;