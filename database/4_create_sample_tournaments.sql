-- Apply this script over database created in step 1

insert into tournament(tournamentId, name, prizePool, startdate, enddate, state) values (1, 'Test1',1000, utc_date, utc_date, 'not_started');

insert into tournament(tournamentId, name, prizePool, prizeDistributionId, startdate, enddate, state) values (2, 'Test2',1000, 2, utc_date, utc_date, 'not_started');
