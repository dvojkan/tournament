-- Apply this script over database created in step 1


-- clear the database and set it up for new deployment
DROP TABLE IF EXISTS player_tournament;

DROP TABLE IF EXISTS tournament;

DROP TABLE IF EXISTS player;

CREATE TABLE player (
    playerId int not null,
    firstName varchar(255) not null,
    lastName varchar(255) not null,
    email varchar(255) not null,
    balance decimal(10,2) not null default 0,
    CONSTRAINT pk_player PRIMARY KEY (playerId)
);

-- this table could have been differently modeled, but it would additionaly complicate database model.
DROP TABLE IF EXISTS prize_distribution;

create table prize_distribution 
(
    prizeDistributionId int not null,
    ranked int not null,
    percent decimal(3,2) not null,
    CONSTRAINT pk_prizeDistributionId PRIMARY KEY (prizeDistributionId, ranked)
);

-- default prize distribution is 1
insert into prize_distribution(prizeDistributionId, ranked, percent) values (1,1,0.5);
insert into prize_distribution(prizeDistributionId, ranked, percent) values (1,2,0.3);
insert into prize_distribution(prizeDistributionId, ranked, percent) values (1,3,0.2);

-- some other models of prize distribution just for testing purposes
insert into prize_distribution(prizeDistributionId, ranked, percent) values (2,1,0.5);
insert into prize_distribution(prizeDistributionId, ranked, percent) values (2,2,0.2);
insert into prize_distribution(prizeDistributionId, ranked, percent) values (2,3,0.0);
insert into prize_distribution(prizeDistributionId, ranked, percent) values (2,4,0.1);
insert into prize_distribution(prizeDistributionId, ranked, percent) values (2,5,0.1);


CREATE TABLE tournament (
    tournamentId int,
    name varchar(255),
    prizePool decimal(10,2),
    prizeDistributionId int not null default 1,
    startDate datetime,
    endDate datetime,
    state varchar(50), -- "not_started", "ongoing", "finished", "settlement_started", "settlement_successful", "settlement_unsuccessful", "cancelled".
    CONSTRAINT pk_tournament PRIMARY KEY (tournamentId)
);

ALTER TABLE tournament ADD CONSTRAINT fk_tournament_prize_distribution_prizeDistributionId FOREIGN KEY (prizeDistributionId) REFERENCES prize_distribution(prizeDistributionId);

-- this table represents the points which player earned on some tournament (current or finished tournament)

-- DROP on the beginning of the script
CREATE TABLE player_tournament (
    playerId int not null,
    tournamentId int not null,
    points int not null default 0,
    CONSTRAINT pk_playerTournament PRIMARY KEY (playerid, tournamentId)
);

ALTER TABLE player_tournament ADD CONSTRAINT fk_pt_player_playerId FOREIGN KEY (playerId) REFERENCES player(playerId);
ALTER TABLE player_tournament ADD CONSTRAINT fk_pt_tournament_tournamentId FOREIGN KEY (tournamentId) REFERENCES tournament(tournamentId);

-- here to add indexes on FK columns to support joins
DROP TABLE IF EXISTS tournament_settlement;

CREATE TABLE tournament_settlement
(
    tournamentId int not null,
    playerId int not null,
    ranked int not null,
    prize decimal(10,2) not null default 0,
    CONSTRAINT pk_tournamentSettlement PRIMARY KEY (tournamentId,playerId)
);

ALTER TABLE tournament_settlement ADD CONSTRAINT fk_ts_player_playerId FOREIGN KEY (playerId) REFERENCES player(playerId);
ALTER TABLE tournament_settlement ADD CONSTRAINT fk_ts_tournament_tournamentId FOREIGN KEY (tournamentId) REFERENCES tournament(tournamentId);

-- create stored procedure for tournament settlement

DELIMITER //

CREATE PROCEDURE sp_settleTournament (in vtournamentId int)
sp_st:BEGIN
    declare ttournamentCount int; -- used to check if tournament with given tournamentId exist
    declare tstate varchar(50); -- tournament state local variable
    declare tprizePool decimal(10,2); -- tournament prize pool
    declare tmaxrank int; -- maximum rank for this tournament
    declare counter int default 1; -- counter used for cycling through ranks
    declare noOfPlayersInRank int; -- number of players in some rank
    declare tTotalPrizePoolForRank decimal(10,2); -- total prize pool for counter rank
    declare tinfo varchar(250); -- used for strings cration

    declare EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            rollback;
            resignal;
            -- update tournament set state = 'settlement_unsuccessful' where tournamentId = vtournamentId;
        END;
    

    -- in this sp we would need to do following work
    -- 0. To check if given input parameters are valid and if given tournamentId exists
    -- 1. to check if tournamentId is finished, but to prevent another sp_settleTournament to run!!
    -- 2. if the tournament is finished then to put tournament into state 'settlement_started'
    -- 3. move all data from player_tournament to tournament_settlement for this tournamentId (transform points to rank!)
    -- 4. calculate prize distribution in temporary table
    -- 5. update tournament_settlement with calculated prizes from previous step
    -- 6. update player balances with new money they got
    -- 7. only when tournament is successfully settled then change state to settlement_successful

    -- 0. To check if given input parameters are valid and if given tournamentId exists
        select count(*) into ttournamentCount from tournament where tournamentId = vtournamentId;

        if ttournamentCount = 0 then
			set tinfo = concat('TournamentId ', vtournamentId, ' not found!');
            select tinfo;
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = tinfo;
            LEAVE sp_st;
        end if;

    START TRANSACTION;        

    -- 1. to check if tournamentId is finished, but to prevent another sp_settleTournament to run!!
        select state into tstate from tournament where tournamentId = vtournamentId for update;

    -- 2. if the tournament is finished then to put tournament into state 'settlement_started'
        if (tstate = 'finished') then -- we can only settle finished tournament
            update tournament set state = 'settlement_started' where tournamentId = vtournamentId;
        else -- tournament is not in 'finished' state thus just exit procedure with appropriate information
            set tinfo = 'Only finished tournaments can be settled!';
			select tinfo;
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = tinfo;
            LEAVE sp_st;
        end if;
    
    -- 3. move all data from player_tournament to tournament_settlement for this tournamentId (transform points to rank!)
        insert into tournament_settlement (tournamentId, playerId, ranked, prize) select tournamentId, playerId, rank() OVER (order by points desc), 0 FROM player_tournament 
        where tournamentId = vtournamentId;
    
    -- 4. calculate prize distribution in temporary table
        drop temporary table if exists tmpPrizeDistribution;

        create temporary table tmpPrizeDistribution (
            tournamentId int not null,
            ranked int not null,
            prizeInitial decimal (10,2) not null,
            numberOfPlayers int,
            prizeCalculated decimal (10,2),
            CONSTRAINT pk_tmpPrizeDistribution PRIMARY KEY(tournamentId, ranked)
            );
        
        insert into tmpPrizeDistribution (tournamentId, ranked, prizeInitial, numberOfPlayers, prizeCalculated)
        select t.tournamentId, pd.ranked, t.prizePool * pd.percent, 0, 0
        from tournament t inner join prize_distribution pd on t.prizeDistributionId = pd.prizeDistributionId
        where t.tournamentId = vtournamentId;

        update tmpPrizeDistribution set numberOfPlayers = (select count(*) from tournament_settlement where tournament_settlement.tournamentId = tmpPrizeDistribution.tournamentId and tournament_settlement.ranked = tmpPrizeDistribution.ranked group by tournamentId, ranked)
        where tournamentId = vtournamentId;

        -- select * from tmpPrizeDistribution;

        select max(ranked) into tmaxrank from tmpPrizeDistribution where tournamentId = vtournamentId;

        while counter <= tmaxrank do

            select coalesce(numberOfPlayers,0) into noOfPlayersInRank from tmpPrizeDistribution where ranked = counter and tournamentId = vtournamentId;

            -- calculate total prize pool for counter rank
            select sum(prizeInitial) into tTotalPrizePoolForRank from tmpPrizeDistribution where ranked >= counter and ranked < (counter + noOfPlayersInRank);

            update tmpPrizeDistribution set prizeCalculated = tTotalPrizePoolForRank/noOfPlayersInRank where ranked = counter and tournamentId = vtournamentId;
            if (noOfPlayersInRank > 0) then
				set counter = counter + noOfPlayersInRank;
			else
				set counter = counter + 1;
			end if;
        
        end while;

        -- select * from tmpPrizeDistribution;

    -- 5. update tournament_settlement with calculated prizes from previous step

        update tournament_settlement ts 
        inner join tmpPrizeDistribution pd on ts.tournamentId = pd.tournamentId and ts.ranked = pd.ranked
        set ts.prize = coalesce(pd.prizeCalculated,0)
        where ts.tournamentId = vtournamentId;
        
    -- 6. update player balances with new money they have got
        update player p
        inner join tournament_settlement ts on p.playerId = ts.playerId
        set p.balance = p.balance + ts.prize
        where ts.tournamentId = vtournamentId;

    -- 7. only when tournament is successfully settled then change state to settlement_successful
        update tournament set state = 'settlement_successful' where tournamentId = vtournamentId;
        
        set tinfo = concat('TournamentId ', vtournamentId, ' settled sucessfully.');
        select tinfo;
	
    COMMIT;

    
END //

DELIMITER ;

