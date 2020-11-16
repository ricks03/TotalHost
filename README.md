# TotalHost
Stars! TotalHost Web-based Turn Management

Stars! (https://en.wikipedia.org/wiki/Stars!) is a classic, turn-based, space-based 4X game, written for Windows, and originally designed to play hostseat or PBEM. 

TotalHost (TH), much like AutoHost, is a web-based interface for Stars! game and turn-management. TH builds off the concept of AutoHost, 
but adds a number of features such as: 
- Web-based game creation
- More options for host, player and game management & turn generation
- A player-pause system, permitting regulation of player pauses, much like timeouts in sports
- Configurable player inactivation (and setting to Housekeeping AI)
- The ability to download the game history (to better recreate the .H file, view in retrospect, and/or recover from system failure)
- Storage and viewing of race files
- The ability to reset a dropped player's Stars! password
- Detecting some of the common Stars! code bugs, and warning (or even correcting) for them.
- Cleaning/Removing information about other players stored in the turn files. 


There are also standalone utilities (generally named stars*.pl) for resetting a password, viewing race and ship design information, extracting player messages in .X|.M files, creating movies from completed games, graphing resources, and the ability to clean some of the shared data from individual player .M files, fixing known Stars! bugs, and changing AI status. These are/were developed generally as precursors to adding functionality to TotalHost.

For simplicity, the entire implementation is on a Windows VM running Apache, and ODBC calls to an Access database. 
The entire implementation is in Perl (except some Java for the movie-generating code).

I began this project 20+ years ago as stop-and-start work, and I'm not a programmer. The code therefore has different coding styles and methodologies. The Stars! community has historically been very closed-source,  primarily due to trying to protect the encryption model and prevent hacking the game. This in turn has stifled development of tools and utilities.  Towards that end, I'm open-sourcing TotalHost, warts and all.

TBD:
While the core code already exists as standalone modules, I'd like to integrate movie and graph creation into the web interface.

If I ever get really motivated, I'll separate the code base into the web front end running on a Linux box with MariaDB, 
and a backend running Windows (to run the Stars! exe).
