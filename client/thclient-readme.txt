THClient - TotalHost turn client
================================

THClient runs on your computer and handles your TotalHost turns for you:

  - downloads each new turn (.m file) as soon as TotalHost generates it
  - uploads your turn (.x file) within a few seconds of saving it in Stars!
  - prints a one-line status for each game: year, whether your turn is in,
    which players (by number and race) the game is still waiting on, and
    when the next turn generates
  - keeps a backup of every previous turn
  - optionally opens Stars! on the new turn, and writes the planet/fleet/map
    dump files that analysis tools use

You need a TotalHost account that is playing in the game, and either:
  - Windows: thclient.exe and thclient.conf.example.
    Nothing else to install.
  - Any system with Perl: thclient.pl and thclient.conf.example (see
    section 9). Section 10 shows how to build your own .exe from thclient.pl.


1. Put the files somewhere
--------------------------

Make a folder, for example C:\THClient, and save thclient.exe and
thclient.conf.example into it.


2. Create thclient.conf
-----------------------

Make a copy of thclient.conf.example in the same folder and name it
thclient.conf. THClient reads thclient.conf from the folder it runs from.
(Windows hides file extensions by default; if the copy ends up called
thclient.conf.txt or the original shows as just "thclient.conf", turn on
View > File name extensions in File Explorer.) Keeping your settings in
thclient.conf means a newer thclient.conf.example never overwrites them.

Open thclient.conf in a text editor (Notepad is fine) and fill in:

  User_Login   your TotalHost login name
  Password     your TotalHost password

Keep the quote marks around each value: Password => 'mypassword',
If your password contains a ' or \ put a \ in front of it:
it's => 'it\'s'. Keep thclient.conf private, since it holds your password.

Then add one line to Games for each game you play:

  Games => [
    { GameFile => 'f9606109', Player => 3, Dir => 'C:/Stars/f9606109' },
    { GameFile => 'a1b2c3d4', Player => 1, Dir => 'C:/Stars/a1b2c3d4' },
  ],

  GameFile  the game's short ID. It is the GameFile= value in the address
            of the game's page on TotalHost, and the name of the game's
            files (f9606109.xy, f9606109.m3, ...).
  Player    your player number in that game: the number on your turn file
            (f9606109.m3 is player 3).
  Dir       the folder that holds the game's files. THClient creates it
            if needed. Use forward slashes: 'C:/Stars/f9606109'.

  Optional, per game:
  StarsPassword => 'racepw'   your race password, if your race has one.
                              Only needed for StarsExe features (section 5).
  Upload => 0                 download turns for this player but never
                              upload them.

If you play more than one race in the same game, add one line per race,
with the same GameFile and Dir and different Player numbers.

Other settings (the defaults are fine):

  Server         https://totalhost.starsautohost.org
  PollMinutes    how often to ask TotalHost for new turns (default 10)
  UploadSeconds  how often to look for a newly saved .x file (default 15;
                 this only looks at your disk, not the server)
  LogFile        also append all messages to this file, e.g. 'C:/THClient/thclient.log'
  Proxy          only if you need a web proxy, e.g. 'http://proxyhost:8080'


3. Run it
---------

Double-click thclient.exe, or in a command prompt:

    cd C:\THClient
    thclient.exe

You should see something like:

    2026-10-28 20:48:56 THClient started for yourlogin on https://totalhost.starsautohost.org: 1 game(s)
    2026-10-28 20:48:57 f9606109: server is at 2418, local .m3 is missing
    2026-10-28 20:48:59 Downloaded f9606109.m3
    2026-10-28 20:48:59 f9606109 (test Zeta) 2418 Active: your turn (3 The joats) is NOT in; waiting on 1 The Humanoids, 3 The joats; next gen 2026-11-01 18:00:00 EDT

The first start takes a few seconds longer than later ones while Windows
unpacks the program. The window stays open while THClient runs. If it
can't start (for example thclient.conf is missing or has a typo), it shows
the error and waits for you to press Enter before the window closes.

Leave it running. Play your turn in Stars! from the Dir folder as usual and
save it; THClient uploads the .x file within about 15 seconds and reports
what TotalHost says about it. If you change your mind and save again, the
new .x is uploaded again. Close the window or press Ctrl+C to stop it.


4. Command-line options
-----------------------

    thclient.exe --once
        Check everything once and exit (for Task Scheduler, section 6).
    thclient.exe --play f9606109
        Open the current turn for that game in Stars! and exit.
        Use f9606109.m2 to pick a player if you have more than one.
    thclient.exe --config C:\other\my.conf
        Use a different config file.

(With Perl, use perl thclient.pl in place of thclient.exe.)


5. Optional: Stars! integration
-------------------------------

Set StarsExe in thclient.conf to where stars.exe is, e.g.
    StarsExe => 'C:/Stars/stars.exe',
and add StarsPassword to the game if your race has a password. Then:

  PlayOnNewTurn => 1   opens Stars! automatically when a new turn arrives
  DumpFiles     => 1   after each new turn, has Stars! write the planet
                       (.p3), fleet (.f3) and map (.map) dump files that
                       analysis tools read
  --play GameFile      opens a game's turn in Stars! (section 4)


6. Run it automatically (Windows)
---------------------------------

Start at log-in (recommended):
  1. Press Win+R, type shell:startup and press Enter. This opens your
     Startup folder.
  2. Right-click in it, choose New > Shortcut, and browse to
     C:\THClient\thclient.exe.
  3. Right-click the new shortcut > Properties. Set "Start in" to
     C:\THClient, and Run to Minimized so the window waits on the taskbar.
  THClient then starts in its own window each time you log in. Click it on
  the taskbar to see its messages; close the window to stop it.

Run every 10 minutes instead, from Task Scheduler:
  1. Set LogFile in thclient.conf, since each run's window closes when
     it finishes.
  2. Open Task Scheduler and choose Create Basic Task.
  3. Trigger: Daily. Then in the task's Properties > Triggers > Edit, tick
     "Repeat task every 10 minutes" for a duration of "Indefinitely".
  4. Action: Start a program.
       Program:   C:\THClient\thclient.exe
       Arguments: --once
       Start in:  C:\THClient
  Uploads then happen at the next 10-minute run rather than within seconds,
  and a console window briefly appears each time it runs.


7. Files THClient creates in each game folder
---------------------------------------------

  GameFile.xy, GameFile.mN    downloaded from TotalHost
  backup/GameFile.mN.YEAR     your previous turns, one per year
  backup/GameFile.pN.YEAR,
  backup/GameFile.fN.YEAR     previous dump files (if DumpFiles is on)
  .thclient.GameFile.xN       marks which version of your .x was last
                              uploaded. Delete it to force a re-upload.
  GameFile.mN.tmp             only while a download is in progress


8. Troubleshooting
------------------

"Cannot load ...thclient.conf"
    There's no thclient.conf in the same folder as the program (copy
    thclient.conf.example, section 2), or it has a typo (usually a missing
    quote mark or comma). The message says which line.

"Login failed for ..."
    User_Login or Password is wrong. Check you can log in on the website
    with the same details. After a failed login THClient waits until the
    next PollMinutes check before trying again.

"Game not found"
    The GameFile value is wrong. Copy it from the GameFile= part of the
    game page's address.

"Download of ... failed: User ... Unauthorized."
    Your account isn't a player in that game, or the Player number is
    wrong.

"Uploaded GameFile.xN: Wrong User!"
    The Player number in thclient.conf doesn't match the race in the .x
    file, or the file belongs to another account.

"Uploaded GameFile.xN: Wrong Year! (...)"
    The .x file is from an earlier turn. Open the newest .m file in Stars!,
    play it and save again.

"Cannot replace ...: Permission denied"
    Stars! had the turn file open. THClient tries again at the next check.

"StarsExe is not set or not found"
    Set StarsExe (section 5), using forward slashes.

Windows SmartScreen or antivirus warns about thclient.exe
    The program isn't signed. Choose "More info" > "Run anyway" if you got
    it from TotalHost.

Nothing happens after saving a turn
    Make sure Stars! is saving into the same folder as Dir, and that the
    game's entry doesn't have Upload => 0.


9. Using the Perl script instead of the .exe
--------------------------------------------

On Linux, macOS, or Windows with Perl installed, you can run thclient.pl
directly. It does exactly the same as thclient.exe.

  Windows: Strawberry Perl (https://strawberryperl.com/) has everything
           needed. Use perl thclient.pl wherever this file says thclient.exe.
  Debian/Ubuntu: sudo apt install libwww-perl liblwp-protocol-https-perl

Every 10 minutes from cron (crontab -e):
    */10 * * * * cd $HOME/thclient && perl thclient.pl --once >> thclient.log 2>&1


10. Building thclient.exe yourself
----------------------------------

The thclient.exe from TotalHost is built from thclient.pl. If you'd rather
build your own (to check what you're running, or after changing
thclient.pl), you can make it with PAR::Packer, which
comes with Strawberry Perl. The .exe bundles Perl, the modules and the
OpenSSL libraries, so it then runs on Windows machines without Perl. Build
it on 64-bit Windows with Strawberry Perl installed (the paths below assume
C:\Strawberry; adjust if yours is elsewhere).

In a command prompt in the folder holding thclient.pl:

    set SB=C:\Strawberry\c\bin
    pp -o thclient.exe -M LWP::Protocol::https -M IO::Socket::SSL -M Net::SSLeay -M Mozilla::CA -l %SB%\libssl-3-x64__.dll -l %SB%\libcrypto-3-x64__.dll -l %SB%\zlib1__.dll thclient.pl

  -M ...             modules pp can't find on its own, because LWP loads
                     the HTTPS support at run time
  -l ...dll          the OpenSSL libraries Net::SSLeay needs, and the zlib
                     library OpenSSL needs. Without them every request fails
                     with "Can't load ...SSLeay.xs.dll". The DLL names change
                     with OpenSSL versions; list what's in %SB% if these
                     aren't found.

Test it on a copy of thclient.conf with a real account, from a command
prompt where Perl isn't on the PATH, for example:

    set PATH=C:\Windows\system32;C:\Windows
    thclient.exe --once

It should log in and download as usual. Rebuild the .exe whenever you
change thclient.pl. If you pass it on to anyone else, give them
thclient.conf.example, not your own thclient.conf.
