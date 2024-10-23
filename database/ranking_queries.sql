-- Ranking query for players according to their balance in player table
select playerId, firstName, lastName, email, balance, rank() OVER (order by balance desc) as 'rank' FROM player;

-- Ranking query for players in some tournament according to their current points in ongoint tournament
select tournamentId, playerId, rank() OVER (order by points desc) as 'rank' FROM player_tournament where tournamentId = 1;


