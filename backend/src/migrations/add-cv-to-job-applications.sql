ALTER TABLE job_applications
  ADD COLUMN cv_public_id VARCHAR(255) NULL AFTER updated_at,
  ADD COLUMN cv_resource_type VARCHAR(20) NOT NULL DEFAULT 'raw' AFTER cv_public_id,
  ADD COLUMN cv_delivery_type VARCHAR(20) NOT NULL DEFAULT 'authenticated' AFTER cv_resource_type;
