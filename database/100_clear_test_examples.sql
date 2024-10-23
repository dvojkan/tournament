delete from player_tournament where tournamentid in (1,2);
delete from tournament_settlement where tournamentid in (1,2);

update tournament set state = 'finished' where tournamentid in (1,2);
