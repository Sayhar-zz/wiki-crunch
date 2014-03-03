CREATE TABLE fr_test.banners (
	test_id NVARCHAR(255), 
	test_name NVARCHAR(255), 
	banner VARCHAR(255), 
	unixtime integer unsigned, 
	country varchar(8), 
	language varchar(24), 
	campaign VARCHAR(255), 
	imps mediumint(11) unsigned);

CREATE TABLE fr_test.clicks ( 
	contribution_id int(10) unsigned, 
	test_id NVARCHAR(255), 
	test_name NVARCHAR(255), 
	banner VARCHAR(255), 
	unixtime integer unsigned,
	timestamp timestamp, 
	country varchar(8),
	language VARCHAR(24), 
	campaign VARCHAR(255), 
	amount decimal(20,2), 
	paymenttype varchar(128), 
	amountsource decimal(20,2), 
	currency varchar(3), 
	landing varchar(255));

CREATE TABLE fr_test.landings (
	test_id NVARCHAR(255),
	test_name NVARCHAR(255),
	banner VARCHAR(255),
	landing VARCHAR(255),
	unixtime integer unsigned,
	country varchar(8), 
	language VARCHAR(24), 
	campaign VARCHAR(255));



CREATE TABLE fr_test.error 
( 
	test_id NVARCHAR(255),
	var VARCHAR(255),
	multiple TINYINT unsigned,
	country varchar(8),
	language VARCHAR(24),
	error VARCHAR(255)
);


CREATE TABLE fr_test.meta 
( test_id NVARCHAR(255),
	var VARCHAR(255),
	multiple TINYINT unsigned,
	country varchar(8),
	language VARCHAR(24),
	winner VARCHAR(255),
	loser VARCHAR(255),
	bestguess FLOAT,
	p FLOAT,
	lowerbound FLOAT,
	upperbound FLOAT,
	totalimpressions INTEGER unsigned,
	totaldonations INTEGER unsigned,
	time integer unsigned,
	type VARCHAR(255),
	testname VARCHAR(255),
	dollarimprovement FLOAT,
	dollarlower FLOAT, 
	dollarupper FLOAT,
	dollarimprovementpct FLOAT,
	dollarlowerpct FLOAT, 
	dollarupperpct FLOAT,
	campaign VARCHAR(255)
);


CREATE TABLE fr_test.polishCUM 
( 
	minute REAL,
	Control_imps mediumint(11) unsigned,
	Variable_imps mediumint(11) unsigned,
	Control_donations mediumint(11) unsigned,
	Variable_donations mediumint(11) unsigned,
	implower FLOAT,
	impmean FLOAT,
	impupper FLOAT,
	power FLOAT,
	n INTEGER unsigned,
	p FLOAT,
	test_name NVARCHAR(255),
	test_id NVARCHAR(255),
	var VARCHAR(255),
	lang VARCHAR(24),
	country varchar(8)
);
CREATE TABLE fr_test.screenshots 
( test_id NVARCHAR(255),
	value NVARCHAR(255),
	campaign VARCHAR(255),
	screenshot VARCHAR(255),
	extra_screenshot_1 VARCHAR(255),
	extra_screenshot_2 VARCHAR(255),
	testname NVARCHAR(255)
);
