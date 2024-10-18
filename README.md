# TotalHost
Stars! TotalHost Web-based Turn Management

[Stars!](https://en.wikipedia.org/wiki/Stars!) is a classic, turn-based, space-based 4X game, written for Windows and originally designed to play hotseat or PBEM.

TotalHost (TH), much like AutoHost, is a web-based interface for Stars! game and turn-management. TH builds off the concept of AutoHost, 
but adds a number of features such as: 
- Web-based game creation
- More options for host, player and game management & turn generation
- A player-delay system, permitting regulation of player-requested delays, much like timeouts in sports
- Configurable player inactivation (and setting to Housekeeping AI)
- The ability to download the game history (to better recreate the .h file, view in retrospect, and/or recover from system failure)
- Storage and viewing of race files
- The ability to reset a dropped player's Stars! password
- Detecting some of the common Stars! code bugs, and warning (or even correcting) for them
- Cleaning/Removing information about other players stored in the turn files 
- Creating a serial number for every user profile

There are also standalone utilities (generally named stars*.pl) for resetting a password, viewing race, fleet and ship design information, extracting player messages in .X|.M files, creating movies from completed games, graphing resources, and the ability to clean some of the shared data from individual player .m files, fixing known Stars! bugs, and changing AI status. These are/were developed generally as precursors to adding functionality to TotalHost.

I began this project 20+ years ago as stop-and-start work, and I'm not a programmer. The code therefore has different coding styles and methodologies. The Stars! community has historically been very closed-source,  primarily trying to protect the encryption model and prevent hacking the game. This in turn has stifled development of tools and utilities. Towards that end, I'm open-sourcing TotalHost, warts and all.

The overall implementation is in Perl (except some Java for the movie-generating code).

The original implementation was/is on a Windows VM running Apache, and ODBC calls to an Access database. I've since separated the "scripts" code base between an ODBC implementation (scripts.odbc) for Windows 16-bit, and a separate DBI implementation (scripts.dbi) for Linux with MariaDB and wine for the Stars!.exe). 
