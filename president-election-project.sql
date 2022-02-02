# Part 1
SELECT * FROM testdb.penna;
# 1.1
	#precinct -> geo, locality, state
	#ID -> Timestamp, state, precinct, locality, geo, Biden, Trump, totalvotes, filestamp
	#ID, Timestamp -> precinct, Trump, Biden, totalvotes, filestamp
# 1.2
DROP TABLE testdb.location;
DROP TABLE testdb.votes;
CREATE TABLE testdb.location(
	precinct varchar(255) NOT NULL, 
    state varchar(2) NOT NULL, 
    locality varchar(255) NOT NULL, 
    geo varchar(255) NOT NULL,
    PRIMARY KEY(precinct)
);
CREATE TABLE testdb.votes (
	ID int NOT NULL,
    Timestamp varchar(255) NOT NULL, 
    precinct varchar(255) NOT NULL,
    totalvotes int NOT NULL,
    Biden int NOT NULL,
    Trump int NOT NULL,
    filestamp varchar(255) NOT NULL, 
    FOREIGN KEY(precinct) REFERENCES testdb.location(precinct)
);
INSERT INTO testdb.location(precinct, state, locality, geo)
	SELECT DISTINCT(precinct), state, locality, geo FROM testdb.penna;
INSERT INTO testdb.votes(ID, Timestamp, precinct, totalvotes, Biden, Trump, filestamp)
	SELECT ID, Timestamp, precinct, totalvotes, Biden, Trump, filestamp FROM testdb.penna;

# Part 2
DROP PROCEDURE testdb.RankALL;

DELIMITER $$
CREATE PROCEDURE testdb.Winner(IN precinct_name VARCHAR(255))
BEGIN
	DECLARE max_timestamp VARCHAR(255);
    SELECT MAX(Timestamp) INTO max_timestamp FROM testdb.votes;
	SELECT IF(Biden<Trump, ("Trump", Trump, 100*(Trump/totalvotes)), 
    ("Biden", Biden, 100*(Biden/totalvotes))) FROM testdb.votes 
		WHERE Timestamp = max_timestamp AND precinct = precinct_name;
END $$

CREATE PROCEDURE testdb.RankALL(IN precinct_name VARCHAR(255))
BEGIN
	DECLARE max_timestamp VARCHAR(255);
    SELECT MAX(Timestamp) INTO max_timestamp FROM testdb.votes;
	SELECT * FROM (SELECT *, rank() OVER (partition by Timestamp order by totalvotes DESC) AS 'rank' 
	FROM (SELECT * FROM testdb.votes WHERE Timestamp = max_timestamp) t1 
    )t2 WHERE t2.precinct = precinct_name;
END $$

CREATE PROCEDURE testdb.RankCounty(IN precinct_name VARCHAR(255))
BEGIN
    DECLARE max_timestamp VARCHAR(255);
    DECLARE county VARCHAR(255);
    SELECT MAX(Timestamp) INTO max_timestamp FROM testdb.votes;
    SELECT locality INTO county FROM testdb.location WHERE precinct = precinct_name;
    
    SELECT * FROM (SELECT *, rank() OVER (partition by Timestamp order by totalvotes DESC) AS 'rank' 
	FROM (SELECT v1.*, l1.locality FROM testdb.votes v1 JOIN testdb.location l1 ON l1.precinct = v1.precinct
	WHERE Timestamp = max_timestamp AND locality = county) t1 
    )t2 WHERE t2.precinct = precinct_name;
END $$

CREATE PROCEDURE testdb.PlotPrecinct(IN precinct_name VARCHAR(255))
BEGIN
	SELECT Timestamp, totalvotes, Trump, Biden FROM testdb.votes WHERE precinct = precinct_name ORDER BY Timestamp;
END $$

CREATE PROCEDURE testdb.EarliestPrecinct(IN vote_count INT)
BEGIN
SELECT precinct FROM (SELECT *, dense_rank() OVER (partition by Timestamp order by totalvotes DESC) AS 'dense_rank' 
	FROM testdb.votes WHERE totalvotes >= vote_count) t1 WHERE t1.dense_rank = 1 LIMIT 1;
END $$

# part 2.2
CREATE PROCEDURE testdb.PrecinctsWon(IN candidate VARCHAR(6))
BEGIN
	DECLARE max_timestamp VARCHAR(255);
	SELECT MAX(Timestamp) INTO max_timestamp FROM testdb.votes;
	IF candidate = "Trump" THEN 
		SELECT precinct, Trump - Biden AS Difference, Trump 
		FROM testdb.votes WHERE Trump > Biden AND Timestamp = max_timestamp ORDER BY Difference DESC;
	END IF;
	IF candidate = "Biden" THEN
		SELECT precinct, Biden - Trump AS Difference, Biden 
		FROM testdb.votes WHERE Biden > Trump AND Timestamp = max_timestamp ORDER BY Difference DESC;
	END IF;
END $$
CREATE PROCEDURE testdb.PrecinctsWonCount(IN candidate VARCHAR(6))
BEGIN
	DECLARE max_timestamp VARCHAR(255);
	SELECT MAX(Timestamp) INTO max_timestamp FROM testdb.votes;
	IF candidate = "Trump" THEN 
		SELECT COUNT(*)
		FROM testdb.votes WHERE Trump > Biden AND Timestamp = max_timestamp;
	END IF;
	IF candidate = "Biden" THEN
		SELECT COUNT(*)
		FROM testdb.votes WHERE Biden > Trump AND Timestamp = max_timestamp;
	END IF;
END$$
CREATE PROCEDURE testdb.PrecinctsFullLead(IN candidate VARCHAR(255))
BEGIN
	# maybe store into a table only when the number of occurrence of the precincts equal to
	# the distinct number of Timestamp
	IF candidate LIKE "Trump" THEN
		SELECT DISTINCT(t1.precinct) FROM (SELECT * FROM testdb.votes ORDER BY precinct, Timestamp) t1, 
		(SELECT * FROM testdb.votes ORDER BY precinct, Timestamp) t2
		WHERE t1.precinct = t2.precinct AND t1.Timestamp < t2.Timestamp AND t2.Trump > t2.Biden;
	END IF;
    IF candidate LIKE "Biden" THEN
		SELECT DISTINCT(t1.precinct) FROM (SELECT * FROM testdb.votes ORDER BY precinct, Timestamp) t1, 
		(SELECT * FROM testdb.votes ORDER BY precinct, Timestamp) t2
		WHERE t1.precinct = t2.precinct AND t1.Timestamp < t2.Timestamp AND t2.Trump < t2.Biden;
	END IF;
END $$
CREATE PROCEDURE testdb.PlotCandidate(IN candidate VARCHAR(255))
BEGIN
	IF candidate LIKE "Biden" THEN
		SELECT Timestamp, SUM(Biden) FROM testdb.votes GROUP BY Timestamp;
	END IF;
    IF candidate LIKE "Trump" THEN
		SELECT Timestamp, SUM(Trump) FROM testdb.votes GROUP BY Timestamp;
	END IF;
END $$
CREATE PROCEDURE testdb.PrecinctsWonCategory(IN precinct_type VARCHAR(255))
BEGIN
	DECLARE max_timestamp VARCHAR(255);
	SELECT MAX(Timestamp) INTO max_timestamp FROM testdb.votes;
	IF precinct_type LIKE "Townships" THEN
		SELECT IF(SUM(Biden) > SUM(Trump), "Biden", "Trump") AS "Winner", 
        IF(SUM(Biden)>SUM(Trump), SUM(Biden)-SUM(Trump), SUM(Trump)-SUM(Biden)) AS "Difference",
        SUM(Biden) AS "Total Biden Vote", SUM(Trump) AS "Total Trump Vote"
			FROM testdb.penna 
        WHERE precinct LIKE "%Township%" AND Timestamp = max_timestamp;
    END IF;
    IF precinct_type LIKE "Wards" THEN
		SELECT IF(SUM(Biden) > SUM(Trump), "Biden", "Trump") AS "Winner", 
        IF(SUM(Biden)>SUM(Trump), SUM(Biden)-SUM(Trump), SUM(Trump)-SUM(Biden)) AS "Difference",
        SUM(Biden) AS "Total Biden Vote", SUM(Trump) AS "Total Trump Vote"
        FROM testdb.penna 
        WHERE precinct LIKE "%Ward%" AND Timestamp = max_timestamp;
    END IF;
    IF precinct_type LIKE "Borough" THEN
		SELECT IF(SUM(Biden) > SUM(Trump), "Biden", "Trump") AS "Winner", 
        IF(SUM(Biden)>SUM(Trump), SUM(Biden)-SUM(Trump), SUM(Trump)-SUM(Biden)) AS "Difference",
        SUM(Biden) AS "Total Biden Vote", SUM(Trump) AS "Total Trump Vote"
        FROM testdb.penna 
        WHERE precinct LIKE "%Borough%" AND Timestamp = max_timestamp;
    END IF;
END $$

#part 2.3
#done
CREATE PROCEDURE testdb.TotalVotes(IN timestamp VARCHAR(255), IN category VARCHAR(6))
BEGIN
	IF category = "Trump" THEN
		SELECT precinct, Trump FROM testdb.votes WHERE Timestamp = timestamp ORDER BY Trump DESC;
    END IF;
    IF category = "Biden" THEN
		SELECT precinct, Biden FROM testdb.votes WHERE Timestamp = timestamp ORDER BY Biden DESC;
    END IF;
    IF category = "ALL" THEN
		SELECT precinct, totalvotes FROM testdb.votes WHERE Timestamp = timestamp ORDER BY totalvotes DESC;
	END IF;
END $$
#done
CREATE PROCEDURE testdb.GainDelta(IN timestamp VARCHAR(255))
BEGIN
	create table if not exists testdb.Times as (select 
	distinct Timestamp, 
	sum(totalvotes) as totalv from 
	testdb.Penna group by Timestamp );
	SELECT * FROM testdb.Times;
    
	SELECT
    t1.Timestamp, t1.totalv, t1.totalv - IFNULL(t2.totalv, 0) AS 'Gain', 
    IFNULL(TIMESTAMPDIFF(SECOND, t2.Timestamp, t1.Timestamp), 0) AS 'Delta',
    (t1.totalv - IFNULL(t2.totalv, 0))/(IFNULL(TIMESTAMPDIFF(MINUTE, t2.Timestamp, t1.Timestamp), 0)) AS 'Ratio'
    FROM testdb.Times t1
    LEFT JOIN testdb.Times t2
        ON t2.Timestamp = (
            SELECT MAX(Timestamp)
            FROM testdb.Times t3
            WHERE t3.Timestamp < t1.Timestamp
        ) WHERE t1.Timestamp = timestamp;
END $$
#done
CREATE PROCEDURE testdb.RankTimestamp()
BEGIN
	create table if not exists testdb.Times as (select 
	distinct Timestamp, 
	sum(totalvotes) as totalv from 
	testdb.Penna group by Timestamp );
	SELECT * FROM testdb.Times;
    
	SELECT
    t1.Timestamp, t1.totalv, t1.totalv - IFNULL(t2.totalv, 0) AS 'Gain', 
    IFNULL(TIMESTAMPDIFF(SECOND, t2.Timestamp, t1.Timestamp), 0) AS 'Delta',
    (t1.totalv - IFNULL(t2.totalv, 0))/(IFNULL(TIMESTAMPDIFF(MINUTE, t2.Timestamp, t1.Timestamp), 0)) AS 'Ratio'
    FROM testdb.Times t1
    LEFT JOIN testdb.Times t2
        ON t2.Timestamp = (
            SELECT MAX(Timestamp)
            FROM testdb.Times t3
            WHERE t3.Timestamp < t1.Timestamp
        )
	ORDER BY ratio DESC;
END $$
#done
CREATE PROCEDURE testdb.VotesPerDay(IN day VARCHAR(3))
BEGIN
	DECLARE substri VARCHAR(10);
	SELECT CONCAT("-", day, " ") INTO substri;
	SELECT SUM(Biden), SUM(Trump), SUM(totalvotes)
	FROM(SELECT Timestamp, Biden, Trump, totalvotes
		FROM (SELECT * FROM testdb.votes)t2 WHERE (POSITION(substri IN Timestamp) = 8))t1;
END $$
DROP PROCEDURE testdb.INSERT_TABLE;
CREATE PROCEDURE testdb.INSERT_TABLE(IN ID INT, IN Timestamp VARCHAR(255), IN state VARCHAR(2), IN locality VARCHAR(255),
	IN precinct VARCHAR(255), IN geo VARCHAR(255), IN totalvotes INT, IN Biden INT, IN Trump INT, IN filestamp VARCHAR(255),
	IN tab_name VARCHAR(40))
ins_tab_proc: BEGIN
	# if constraint is insert, try inserting into the table, and check if it affected any,
    # if so, insert success, else insertion fail
    IF tab_name LIKE "location" THEN
        SET @param = CONCAT("VALUES ('", precinct,"','", state,"','", locality, "','",geo,"')");
		SET @t1 = CONCAT("INSERT INTO testdb.", "location  ", @param);
		PREPARE insert_location FROM @t1;
		EXECUTE insert_location;
		DEALLOCATE PREPARE insert_location;
		SELECT "Insertion completed";
    END IF;
	IF tab_name LIKE "votes" THEN
		IF Timestamp < "2020-11-03 00:00:00" OR Timestamp >= "2020-11-12 00:00:00" THEN
			SELECT 'Insertion rejected due to violation of date constraint';
			LEAVE ins_tab_proc;
		END IF;
		IF totalvotes < Biden+Trump THEN
			SELECT 'Insertion rejected due to violation of sum of votes constraint';
            LEAVE ins_tab_proc;
		END IF;
		IF Biden < 0 OR Trump < 0 THEN
			SELECT 'Insertion rejected due to invalid values';
            LEAVE ins_tab_proc;
		END IF;
        # if the input precinct is not in location, then foreign key fails
        SET @precinct_not_in = ((SELECT COUNT(precinct) FROM testdb.location WHERE testdb.location.precinct = precinct) = 0);
		IF @precinct_not_in = TRUE THEN
			SELECT 'Insertion rejected due to foreign key constraint';
            LEAVE ins_tab_proc;
        END IF;
        # at this point, no way it can fail
		SET @param = CONCAT("VALUES (", ID,",'", Timestamp,"','", precinct, "',",totalvotes,",", Biden,",", Trump,",'", filestamp, "')");
		SET @t1 = CONCAT("INSERT INTO testdb.", "votes ", @param);
		PREPARE insert_votes FROM @t1;
		EXECUTE insert_votes;
		DEALLOCATE PREPARE insert_votes;
		SELECT "Insertion completed";
	END IF;
END $$
CREATE PROCEDURE testdb.DELETE_TABLE(IN ID INT, IN Timestamp VARCHAR(255), IN state VARCHAR(2), IN locality VARCHAR(255),
	IN precinct VARCHAR(255), IN geo VARCHAR(255), IN totalvotes INT, IN Biden INT, IN Trump INT, IN filestamp VARCHAR(255),
	IN tab_name VARCHAR(40))
del_tab_proc: BEGIN
	IF tab_name LIKE "location" THEN
		SET @precinct_in = ((SELECT COUNT(v1.precinct) 
			FROM testdb.votes v1 WHERE v1.precinct = precinct) = 1);
		IF @precinct_in = True THEN
			# if precinct is in votes, then we can't delete it
            SELECT 'Deletion rejected due to primary key constraint';
            LEAVE del_tab_proc;
        END IF;
        SET @param = CONCAT("WHERE precinct = '", precinct, "'");
		SET @t1 = CONCAT("DELETE FROM testdb.", "location  ", @param);
		PREPARE del_location FROM @t1;
		EXECUTE del_location;
		DEALLOCATE PREPARE del_location;
		SELECT "Delete completed in location";
    END IF;
	IF tab_name LIKE "votes" THEN
        # at this point, no way it can fail
		SET @param = CONCAT("WHERE precinct = '", precinct, "'");
		SET @t1 = CONCAT("DELETE FROM testdb.", "votes  ", @param);
		PREPARE del_location FROM @t1;
		EXECUTE del_location;
		DEALLOCATE PREPARE del_location;
		SELECT "Delete completed in votes";
	END IF;
END $$
DROP PROCEDURE testdb.UPDATE_TABLE;
CREATE PROCEDURE testdb.UPDATE_TABLE(IN ID INT, IN Timestamp VARCHAR(255), IN state VARCHAR(2), IN locality VARCHAR(255),
	IN precinct VARCHAR(255), IN geo VARCHAR(255), IN totalvotes INT, IN Biden INT, IN Trump INT, IN filestamp VARCHAR(255),
	IN new_ID INT, IN new_Timestamp VARCHAR(255), IN new_state VARCHAR(2), IN new_locality VARCHAR(255),
	IN new_precinct VARCHAR(255), IN new_geo VARCHAR(255), IN new_totalvotes INT, 
    IN new_Biden INT, IN new_Trump INT, IN new_filestamp VARCHAR(255), IN tab_name VARCHAR(40))
upd_tab_proc: BEGIN
	# if we want to update vote, check biden,trump and totalvote
    # and check timestamp, and that the precinct exists in location
    # if we want to update location, the cascade option in the table itself will
    # update all occurrence thats happening in the votes table
    SET @in_location =  IF((SELECT COUNT(*) FROM testdb.location l1 
						WHERE l1.precinct = new_precinct) = 0, FALSE, TRUE);
    IF tab_name LIKE "location" THEN
		# votes table will update the precinct that was changed here
		UPDATE testdb.location l1 SET l1.precinct = new_precinct, l1.state = new_state, 
			l1.locality = new_locality, l1.geo = new_geo WHERE l1.precinct = precinct;
		SELECT 'Update completed in location';
		LEAVE upd_tab_proc;
    END IF;
    IF tab_name LIKE "votes" THEN
		IF new_Timestamp < "2020-11-03 00:00:00" OR new_Timestamp >= "2020-11-12 00:00:00" THEN
			SELECT 'Update rejected due to violation of date constraint';
			LEAVE upd_tab_proc;
		END IF;
		IF new_totalvotes < new_Biden+new_Trump THEN
			SELECT 'Update rejected due to violation of sum of votes constraint';
            LEAVE upd_tab_proc;
		END IF;
		IF new_Biden < 0 OR new_Trump < 0 THEN
			SELECT 'Update rejected due to invalid values';
            LEAVE upd_tab_proc;
		END IF;
        IF @in_location = FALSE THEN
			SELECT 'Update rejected due to foreign constraint';
            LEAVE upd_tab_proc;
        END IF;
        SET @set_string = CONCAT('SET ID = "', new_ID, '", Timestamp = "', new_Timestamp, '", precinct = "', new_precinct,
		'", totalvotes = ', new_totalvotes, ', Biden = ', new_Biden, ', Trump = ', new_Trump,
        '", filestamp = "', new_filestamp, '"');
        SET @where_string = CONCAT(' WHERE precinct = "', precinct, '"');
		SET @t1 = CONCAT("UPDATE testdb.votes ", @set_string, @where_string);
		PREPARE update_votes FROM @t1;
		EXECUTE update_votes;
		DEALLOCATE PREPARE update_votes;
		SELECT "Update completed in votes";
        # at this point, freely update
    END IF;
END $$
SELECT * from testdb.votes;
CREATE PROCEDURE testdb.MoveVotes(IN in_precinct VARCHAR(255), IN Timest VARCHAR(255), IN CoreCandidate VARCHAR(255), IN number_of_moved_votes INT)
mv: BEGIN
	DECLARE trump_at_timestamp INT;
    DECLARE biden_at_timestamp INT;
    IF (in_precinct NOT IN (SELECT DISTINCT(precinct) from testdb.location)) THEN
		SELECT "The precinct is not in the table";
        LEAVE mv;
    END IF;
    IF Timest NOT IN (SELECT DISTINCT(Timestamp) FROM testdb.votes) THEN
		SELECT "Unknown Timestamp";
        LEAVE mv;
    END IF;
    IF CoreCandidate NOT LIKE "Biden" AND CoreCandidate NOT LIKE "Trump" THEN
		SELECT "Wrong Candidate";
        LEAVE mv;
    END IF;
    SELECT Trump INTO trump_at_timestamp FROM testdb.votes WHERE Timestamp = Timest AND precinct = in_precinct;
	SELECT Biden INTO biden_at_timestamp FROM testdb.votes WHERE Timestamp = Timest AND precinct = in_precinct;
    IF number_of_moved_votes > IF(CoreCandidate LIKE "Biden", biden_at_timestamp, trump_at_timestamp) THEN
        SELECT "Not enough votes";
        LEAVE mv;
	END IF;
    # at this point, we have a valid precinct, a valid time stamp, a valid candidate, and a valid number of votes
    # assume every timestamp after this has at least same number of votes as currently
    # Get all timestamp at and after Timest at in_precinct
    IF CoreCandidate LIKE "Biden" THEN
		UPDATE testdb.votes SET Trump = Trump + number_of_moved_votes WHERE testdb.votes.precinct = in_precinct AND testdb.votes.Timestamp >= Timest;
		UPDATE testdb.votes SET Biden = Biden - number_of_moved_votes WHERE testdb.votes.precinct = in_precinct AND testdb.votes.Timestamp >= Timest;
    END IF;
    IF CoreCandidate LIKE "Trump" THEN
		UPDATE testdb.votes SET Trump = Trump - number_of_moved_votes WHERE testdb.votes.precinct = in_precinct AND testdb.votes.Timestamp >= Timest;
		UPDATE testdb.votes SET Biden = Biden + number_of_moved_votes WHERE testdb.votes.precinct = in_precinct AND testdb.votes.Timestamp >= Timest;
    END IF;
END $$

DELIMITER ;

# part 3
# 3.a
SELECT IF(COUNT(DISTINCT(CASE WHEN (Biden+Trump <= totalvotes) THEN "True" ELSE "False" END)) = 1, True, False) FROM testdb.votes;
# 3.b
SELECT IF(COUNT(DISTINCT(CASE WHEN (Timestamp >= "2020-11-12 00:00:00" OR Timestamp < "2020-11-03 00:00:00") THEN "True" ELSE "False" END)) = 1, TRUE, FALSE) FROM testdb.votes;
# 3.c
CREATE TABLE testdb.after_fifth SELECT * FROM testdb.votes 
	WHERE Timestamp > 
		(SELECT DISTINCT(Timestamp) FROM testdb.votes WHERE Timestamp > "2020-11-05 00:00:00" ORDER BY Timestamp ASC LIMIT 1) 
			ORDER BY precinct;

CREATE TABLE testdb.value_at_fifth SELECT * FROM testdb.votes 
	WHERE Timestamp = (SELECT DISTINCT(Timestamp) 
    FROM testdb.votes WHERE Timestamp > "2020-11-05 00:00:00" ORDER BY Timestamp ASC LIMIT 1);
CREATE TABLE testdb.final_table (SELECT * FROM testdb.after_fifth
UNION
SELECT * FROM testdb.value_at_fifth ORDER BY precinct, Timestamp);
SELECT (CASE WHEN COUNT(Valid) = SUM(Valid) THEN TRUE ELSE FALSE END)
FROM (
SELECT IF(at_fifth.totalvotes <= after_fifth.totalvotes, "True", "False") "Valid"
	FROM testdb.final_table at_fifth, testdb.final_table after_fifth
    WHERE at_fifth.Timestamp = 
    (SELECT DISTINCT(Timestamp) FROM testdb.votes 
		WHERE Timestamp > "2020-11-05 00:00:00" ORDER BY Timestamp ASC LIMIT 1) 
	AND
    after_fifth.Timestamp != (SELECT DISTINCT(Timestamp) FROM testdb.votes 
		WHERE Timestamp > "2020-11-05 00:00:00" ORDER BY Timestamp ASC LIMIT 1) 
	AND 
	at_fifth.precinct = after_fifth.precinct) t1;


# Part 4

# 4.1
DROP TABLE testdb.Inserted_Tuples_location;
CREATE TABLE testdb.Inserted_Tuples_location(
	precinct varchar(255) NOT NULL, 
    state varchar(2), 
    locality varchar(255), 
    geo varchar(255)
);
DROP TABLE testdb.Updated_Tuples_location;
CREATE TABLE testdb.Updated_Tuples_location(
	precinct varchar(255) NOT NULL, 
    state varchar(2), 
    locality varchar(255), 
    geo varchar(255)
);
DROP TABLE testdb.Deleted_Tuples_location;
CREATE TABLE testdb.Deleted_Tuples_location(
	precinct varchar(255) NOT NULL, 
    state varchar(2), 
    locality varchar(255), 
    geo varchar(255)
);
DROP TABLE testdb.Inserted_Tuples_votes;
CREATE TABLE testdb.Inserted_Tuples_votes (
	ID int NOT NULL,
    Timestamp varchar(255), 
    precinct varchar(255),
    totalvotes int,
    Biden int,
    Trump int,
    filestamp varchar(255)
);
DROP TABLE testdb.Updated_Tuples_votes;
CREATE TABLE testdb.Updated_Tuples_votes (
	ID int NOT NULL,
    Timestamp varchar(255), 
    precinct varchar(255),
    totalvotes int,
    Biden int,
    Trump int,
    filestamp varchar(255)
);
DROP TABLE testdb.Deleted_Tuples_votes;
CREATE TABLE testdb.Deleted_Tuples_votes (
	ID int NOT NULL,
    Timestamp varchar(255), 
    precinct varchar(255),
    totalvotes int,
    Biden int,
    Trump int,
    filestamp varchar(255)
);
DELIMITER $$
#DROP TRIGGER testdb.delete_trigger_location;
CREATE TRIGGER testdb.delete_trigger_location
	BEFORE DELETE ON testdb.location
    FOR EACH ROW
    BEGIN
		INSERT INTO Deleted_Tuples_location(precinct, state, locality, geo)
        VALUES (OLD.precinct, OLD.state, OLD.locality, OLD.geo);
    END $$
#DROP TRIGGER testdb.insert_trigger_location;
CREATE TRIGGER testdb.insert_trigger_location
	AFTER INSERT ON testdb.location
    FOR EACH ROW
    BEGIN
		INSERT INTO Inserted_Tuples_location(precinct, state, locality, geo)
        VALUES (NEW.precinct,NEW.state, NEW.locality, NEW.geo);
    END $$
#DROP TRIGGER testdb.update_trigger_location;
CREATE TRIGGER testdb.update_trigger_location
	BEFORE UPDATE ON testdb.location
    FOR EACH ROW
    BEGIN
		INSERT INTO Updated_Tuples_location(precinct, state, locality, geo)
        VALUES (OLD.precinct, OLD.state, OLD.locality, OLD.geo);
    END $$
#DROP TRIGGER testdb.delete_trigger_votes;
CREATE TRIGGER testdb.delete_trigger_votes
	BEFORE DELETE ON testdb.votes
    FOR EACH ROW
    BEGIN
		INSERT INTO Deleted_Tuples_votes(ID, Timestamp, Precinct, totalvotes, Biden, Trump, filestamp)
        VALUES (OLD.ID, OLD.Timestamp, OLD.Precinct, OLD.totalvotes, OLD.Biden, OLD.Trump, OLD.filestamp);
    END $$
#DROP TRIGGER testdb.insert_trigger_votes;
CREATE TRIGGER testdb.insert_trigger_votes
	AFTER INSERT ON testdb.votes
    FOR EACH ROW
    BEGIN
		INSERT INTO Inserted_Tuples_votes(ID, Timestamp, Precinct, totalvotes, Biden, Trump, filestamp)
        VALUES (NEW.ID, NEW.Timestamp, NEW.Precinct, NEW.totalvotes, NEW.Biden, NEW.Trump, NEW.filestamp);
    END $$
#DROP TRIGGER testdb.update_trigger_votes;
CREATE TRIGGER testdb.update_trigger_votes
	BEFORE UPDATE ON testdb.votes
    FOR EACH ROW
    BEGIN
		INSERT INTO Updated_Tuples_votes(ID, Timestamp, Precinct, totalvotes, Biden, Trump, filestamp)
        VALUES (OLD.ID, OLD.Timestamp, OLD.Precinct, OLD.totalvotes, OLD.Biden, OLD.Trump, OLD.filestamp);
    END $$
DELIMITER ;
DROP TRIGGER testdb.delete_trigger_votes;

# TESTING

SET SQL_SAFE_UPDATES = 0;

#IN Precinct VARCHAR(255), IN Timest VARCHAR(255), IN CoreCandidate VARCHAR(255), IN number_of_moved_votes INT

CALL testdb.INSERT_TABLE(0, '2020-11-05 00:00:00', 'ny', 'elmhurst', 'testing_precinct', 
						'testing_geo',100, 50, 50, 'no_filestamp', 'votes');
CALL testdb.INSERT_TABLE(0, '2020-11-05 00:00:00', 'ny', 'elmhurst', 'testing_precinct', 
						'testing_geo',100, 50, 50, 'no_filestamp', 'location');
SELECT * FROM testdb.votes;
SELECT * FROM testdb.location;
SELECT * FROM testdb.Inserted_Tuples_votes;
SELECT * FROM testdb.Inserted_Tuples_location;

CALL testdb.DELETE_TABLE(0, '2020-11-05 00:00:00', 'ny', 'elmhurst', 'testing_precinct', 
						'testing_geo', 100, 50, 50, 'no_filestamp', 'location');
CALL testdb.DELETE_TABLE(0, '2020-11-05 00:00:00', 'ny', 'elmhurst', 'testing_precinct', 
						'testing_geo', 100, 50, 50, 'no_filestamp', 'votes');
SELECT * FROM testdb.votes;
SELECT * FROM testdb.location;
SELECT * FROM testdb.Deleted_Tuples_votes;
SELECT * FROM testdb.Deleted_Tuples_location;


CALL testdb.UPDATE_TABLE(0, '2020-11-05 00:00:00', 'ny', 'elmhurst', 'testing_precinct', 
						'testing_geo', 100, 50, 50, 'no_filestamp',
						1, '2020-11-05 00:00:00', 'nj', 'new_elmhurst', 
                        'new_testing_precinct', 'new_testing_geo', 100, 60, 40, 'new_filestamp', 'votes');
                        
CALL testdb.UPDATE_TABLE(0, '2020-11-05 00:00:00', 'ny', 'elmhurst', 'testing_precinct', 
						'testing_geo', 100, 50, 50, 'no_filestamp',
						0, '2020-11-05 00:00:00', 'ny', 'elmhurst', 
                        'new_testing_precinct', 'new_testing_geo', 100, 50, 50, 'no_filestamp', 'location');
                        
SELECT * FROM testdb.votes;
SELECT * FROM testdb.location;
SELECT * FROM testdb.Updated_Tuples_votes;
SELECT * FROM testdb.Updated_Tuples_location;

SET FOREIGN_KEY_CHECKS=0; -- to disable them