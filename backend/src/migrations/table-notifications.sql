
CREATE TABLE notifications (
	id INT AUTO_INCREMENT PRIMARY KEY NOT NULL,
	recipient_id INT NOT NULL,
	type ENUM('application_received', 'application_rejected') NOT NULL,
	message VARCHAR(255) NOT NULL,
	job_id INT NULL,
	application_id INT NULL,

	created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	read_at TIMESTAMP NULL DEFAULT NULL,

	index idx_notifications_recipient (recipient_id, created_at),
	index idx_notifications_unread (recipient_id, read_at),

	unique key uq_notification_event (recipient_id, type, application_id),

	constraint fk_notification_recipient foreign key (recipient_id)
	references users(id) on delete cascade,
	constraint fk_notification_job foreign key (job_id)
		references jobs(id) on delete set null,

	constraint fk_notification_application foreign key (application_id)
		references job_applications(id) on delete set null
);
