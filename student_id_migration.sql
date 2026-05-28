-- SQL Code to add student_id to users table with format constraints and uniqueness

-- 1. Add student_id column to users table
ALTER TABLE users ADD COLUMN student_id VARCHAR(12);

-- 2. Add format constraint enforcing ##-####-### using a regular expression
ALTER TABLE users ADD CONSTRAINT check_student_id_format 
CHECK (student_id ~ '^[0-9]{2}-[0-9]{4}-[0-9]{3}$');

-- 3. Add UNIQUE constraint to prevent duplicate student IDs
ALTER TABLE users ADD CONSTRAINT unique_student_id UNIQUE (student_id);
