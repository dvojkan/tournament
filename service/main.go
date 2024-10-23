package main

import (
	"database/sql"
	"fmt"
	"log"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	_ "github.com/go-sql-driver/mysql"
)

var db *sql.DB

const (
	host     = "localhost"
	port     = 3306
	username = "mysql"
	password = "mysql"
	dbname   = "tournament"
)

type Player struct {
	PlayerId  int     `json:"playerId"`
	FirstName string  `json:"firstName"`
	LastName  string  `json:"lastName"`
	Email     string  `json:"email"`
	Balance   float32 `json:"balance"`
	Rank      int     `json:"rank"`
}

type PlayerTournament struct {
	TournamentId int `json:"tournamentId"`
	PlayerId     int `json:"playerId"`
	Rank         int `json:"rank"`
}

// Connect to MySQL database
func connectDB() {

	var err error

	//MySQL connection string
	mySQLlInfo := fmt.Sprintf("%s:%s@tcp(%s:%d)/%s", username, password, host, port, dbname)

	db, err = sql.Open("mysql", mySQLlInfo)

	if err != nil {
		log.Fatalf("Error connecting to the database: %v", err)
	}

	// Check the connection
	/*
		if err = db.Ping(); err != nil {
			log.Fatalf("Error pinging the database: %v", err)
		}
		fmt.Println("Successfully connected to MySQL!")
	*/
}

// Handler function to execute the tournament settlement stored procedure
func settleTournament(c *gin.Context) {
	// Extract tournamentId from URL
	tournamentID := c.Param("id")

	// convert it to integer
	currtournamentId, _ := strconv.Atoi(tournamentID)

	// Execute the stored procedure
	_, err := db.Exec("CALL sp_settleTournament(?)", currtournamentId)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	// If everything went fine, return a success message
	c.JSON(http.StatusOK, gin.H{"message": "Tournament settled."})
}

// Handler function return player ranks by their balance in descending order
func playerRanks(c *gin.Context) {
	rows, err := db.Query("SELECT playerId, firstName, lastName, email, balance, rank() OVER (order by balance desc) AS 'rank' FROM player")

	if err != nil {
		log.Fatal(err)
	}
	defer rows.Close()

	var players []Player

	for rows.Next() {

		var player Player

		if err := rows.Scan(&player.PlayerId, &player.FirstName, &player.LastName, &player.Email, &player.Balance, &player.Rank); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		players = append(players, player)
	}

	// Check for errors after iterating through rows
	if err := rows.Err(); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, players)
}

// Handler function return player ranks by their points in given tournament
func tournamentLeaderboardReport(c *gin.Context) {

	// Extract tournamentId from URL
	tournamentID := c.Param("id")

	// convert it to integer
	currtournamentId, _ := strconv.Atoi(tournamentID)

	// Prepare the SQL statement with placeholders for the parameters
	stmt, err := db.Prepare("select tournamentId, playerId, rank() OVER (order by points desc) as 'rank' FROM player_tournament where tournamentId = ?")

	if err != nil {
		log.Fatal(err)
	}

	defer stmt.Close()

	rows, err := stmt.Query(currtournamentId)

	if err != nil {
		log.Fatal(err)
	}
	defer rows.Close()

	var players []PlayerTournament

	for rows.Next() {

		var player PlayerTournament

		if err := rows.Scan(&player.TournamentId, &player.PlayerId, &player.Rank); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		players = append(players, player)
	}

	// Check for errors after iterating through rows
	if err := rows.Err(); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, players)
}

func main() {
	// Connect to the database
	connectDB()

	defer db.Close()

	// Create a new Gin router
	r := gin.Default()

	// Define routes
	r.PUT("/settleTournament/:id", settleTournament)
	r.GET("/playerRanks", playerRanks)
	r.GET("/tournamentLeaderboardReport/:id", tournamentLeaderboardReport)

	// Start the server
	r.Run(":8080") // The server will run on port 8080
}
