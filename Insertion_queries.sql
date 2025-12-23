SET FOREIGN_KEY_CHECKS = 0;


SHOW VARIABLES LIKE 'local_infile';
SET GLOBAL local_infile = 1;



LOAD DATA LOCAL INFILE 'specialties.csv'
INTO TABLE specialties
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(specialty_id, specialty_name, specialty_code);
