# tournament
Install deliverables in following order
1. MySQL Server. I have worked with 8.0.40
2. MySQL Workbench.

3. Open a session in MySQL Workbench as mysql user. All scripts should be executed under that user.
4. Create database in MySQL Server by executing script tournament\database\1_create_database.sql. 
   That script will create desired detabase default name is tournament. Double click in MySQL WorkBench to make this database default for other scripts!
5. From the same location, execute scripts over database created in previous step
	2_create_database_items.sql
	3_create_sample_players.sql
	4_create_sample_tournaments.sql
	
6. These steps setup all neccesary items. Following steps are used to create some examples over which we are going to run settlement
   These are "example" steps. They setup some state in player tournament which needs to be settled.

7. With script 100_clear_test_examples.sql we are clearing the database from examples and then new example can be run.

8. Application is written in Go. It should be cloned on some machine from github. Once it is cloned, it can be opened with Visual Studio Code with File -> Open Folder and then find folder tournament

9. Before running application, check database settings in main.go file in the part:
const (
	host     = "localhost"
	port     = 3306
	username = "mysql"
	password = "*****"
	dbname   = "tournament"
)

These parameters should be set to point to desired MySQL Server and Database shown in previous steps.

10. Application can be built and run with go run .  That command should be run in Visual Studio Code Terminal. It will start tournament service.

11. Application can be tested by utlizing some sql scripts (example) and then running settlement or other exposed APIs. Their description is given in additional document.

