-- +goose Up

SET client_encoding = 'UTF-8';

CREATE TABLE IF NOT EXISTS "_gamestatus" (
    "gamestatus" SMALLINT,
    "gamestatus_txt" VARCHAR (50)
);

-- CREATE INDEXES ...

ALTER TABLE
    "_gamestatus"
ADD
    CONSTRAINT "_gamestatus_pkey" PRIMARY KEY ("gamestatus");

CREATE TABLE IF NOT EXISTS "_gametype" (
    "gametype" INTEGER,
    "gametype_txt" VARCHAR (50)
);

COMMENT ON COLUMN "_gametype"."gametype" IS 'Type of Game';

COMMENT ON COLUMN "_gametype"."gametype_txt" IS 'Hourly, Daily, or required (all turns are required)';

-- CREATE INDEXES ...

ALTER TABLE
    "_gametype"
ADD
    CONSTRAINT "_gametype_pkey" PRIMARY KEY ("gametype");

CREATE TABLE IF NOT EXISTS "_holidays" (
    "holiday" DATE,
    "holiday_txt" VARCHAR (50),
    "nationality" VARCHAR (2)
);

COMMENT ON COLUMN "_holidays"."holiday" IS 'Days that the game considers holidays';

COMMENT ON COLUMN "_holidays"."holiday_txt" IS 'Description of Holiday';

COMMENT ON COLUMN "_holidays"."nationality" IS 'Country that the holiday is for';

-- CREATE INDEXES ...

CREATE TABLE IF NOT EXISTS "_playerstatus" (
    "playerstatus" INTEGER,
    "playerstatus_txt" VARCHAR (50)
);

-- CREATE INDEXES ...

ALTER TABLE
    "_playerstatus"
ADD
    CONSTRAINT "_playerstatus_pkey" PRIMARY KEY ("playerstatus");

CREATE TABLE IF NOT EXISTS "_userstatus" (
    "user_status" INTEGER,
    "user_status_txt" VARCHAR (50),
    "user_status_detail" VARCHAR (50)
);

COMMENT ON COLUMN "_userstatus"."user_status_txt" IS 'Current Account Status';

-- CREATE INDEXES ...

CREATE TABLE IF NOT EXISTS "_version" ( "version" VARCHAR (50) );

-- CREATE INDEXES ...

ALTER TABLE
    "_version"
ADD
    CONSTRAINT "_version_pkey" PRIMARY KEY ("version");

CREATE TABLE IF NOT EXISTS "games" (
    "gamename" VARCHAR (31) NOT NULL,
    "gamefile" VARCHAR (8),
    "gamedescrip" VARCHAR (50),
    "hostname" VARCHAR (25),
    "gametype" INTEGER,
    "dailytime" VARCHAR (50),
    "hourlytime" VARCHAR (24),
    "lastturn" INTEGER,
    "nextturn" INTEGER,
    "gamestatus" SMALLINT,
    "delaycount" SMALLINT,
    "asavailable" BOOLEAN NOT NULL,
    "onlyifavailable" BOOLEAN NOT NULL,
    "dayfreq" VARCHAR (7),
    "hourfreq" VARCHAR (24),
    "forcegen" BOOLEAN NOT NULL,
    "forcegenturns" SMALLINT,
    "forcegentimes" SMALLINT,
    "hostmod" BOOLEAN NOT NULL,
    "hostforce" BOOLEAN NOT NULL,
    "noduplicates" BOOLEAN NOT NULL,
    "gamerestore" BOOLEAN NOT NULL,
    "anonplayer" BOOLEAN NOT NULL,
    "gamepause" BOOLEAN NOT NULL,
    "gamedelay" BOOLEAN NOT NULL,
    "numdelay" INTEGER,
    "mindelay" INTEGER,
    "autoinactive" INTEGER,
    "observeholiday" BOOLEAN NOT NULL,
    "newspaper" BOOLEAN NOT NULL,
    "sharedm" BOOLEAN NOT NULL,
    "notes" TEXT,
    "maxplayers" SMALLINT
);

COMMENT ON COLUMN "games"."gamename" IS 'Name of Game (31 max len)';

COMMENT ON COLUMN "games"."gamefile" IS 'File Name of Game ( 8 max len)';

COMMENT ON COLUMN "games"."gamedescrip" IS 'Game Description';

COMMENT ON COLUMN "games"."hostname" IS 'Name of the Current Host max 25';

COMMENT ON COLUMN "games"."gametype" IS 'How turns are generated.';

COMMENT ON COLUMN "games"."dailytime" IS 'At what time are turns normally supposed to be generated, <<<<or interval until next turn (set by GameType)- no not really anymore)>>>  This has gotten confused with TimeFreq .....';

COMMENT ON COLUMN "games"."hourlytime" IS 'What times turns are supposed to be generated when the game is hourly';

COMMENT ON COLUMN "games"."lastturn" IS 'Last time a turn was generated';

COMMENT ON COLUMN "games"."nextturn" IS 'When should the next turn generate';

COMMENT ON COLUMN "games"."gamestatus" IS 'Is the game in progress, over, pending, what?';

COMMENT ON COLUMN "games"."delaycount" IS 'How Many times the game is delayed';

COMMENT ON COLUMN "games"."asavailable" IS 'Generate Turns when required';

COMMENT ON COLUMN "games"."onlyifavailable" IS 'Generate only if all turns are in.';

COMMENT ON COLUMN "games"."dayfreq" IS 'What days are turns supposed to be generated. (0111110) (SMTWTFS)';

COMMENT ON COLUMN "games"."hourfreq" IS 'What hours are turns supposed to be generated. (11111111111111111111111)  Not really i use anywhere yet.';

COMMENT ON COLUMN "games"."forcegen" IS 'Should turns be force generated.';

COMMENT ON COLUMN "games"."forcegenturns" IS 'The number of Years to Force Generate each time a turn is generated';

COMMENT ON COLUMN "games"."forcegentimes" IS 'the Number of Times to Force Generate the turn before force generation stops, and it goes back to once/turn';

COMMENT ON COLUMN "games"."hostmod" IS 'Host can modify Game settings.';

COMMENT ON COLUMN "games"."hostforce" IS 'Host can force generate';

COMMENT ON COLUMN "games"."noduplicates" IS 'No duplicate players';

COMMENT ON COLUMN "games"."gamerestore" IS 'Host can restore game';

COMMENT ON COLUMN "games"."anonplayer" IS 'Allow Anonymous Players.';

COMMENT ON COLUMN "games"."gamepause" IS 'Players can Pause the Game (in addition to the Host)';

COMMENT ON COLUMN "games"."gamedelay" IS 'Players can delay the game for a turn (or more)';

COMMENT ON COLUMN "games"."numdelay" IS 'Number of times a player is originally set to delay the game (and for resets)';

COMMENT ON COLUMN "games"."mindelay" IS 'The minimum number of pauses before the pause count resets (0 means never reset)';

COMMENT ON COLUMN "games"."autoinactive" IS '0 = Not auto inactive, otherwise # of turns until player is auto-flagged as inactive';

COMMENT ON COLUMN "games"."observeholiday" IS 'Game will observe Holidays';

COMMENT ON COLUMN "games"."newspaper" IS 'Generate Galactic Paper';

COMMENT ON COLUMN "games"."sharedm" IS 'Users can see each other''s M files';

COMMENT ON COLUMN "games"."notes" IS 'Game Notes';

COMMENT ON COLUMN "games"."maxplayers" IS 'Maximum number of players';

-- CREATE INDEXES ...

CREATE UNIQUE INDEX "games_gamename_idx" ON "games" ("gamename");

ALTER TABLE
    "games"
ADD
    CONSTRAINT "games_pkey" PRIMARY KEY ("gamefile");

CREATE TABLE IF NOT EXISTS "gameusers" (
    "gamename" VARCHAR (50),
    "gamefile" VARCHAR (50),
    "user_login" VARCHAR (50),
    "racefile" VARCHAR (50),
    "delaysleft" SMALLINT,
    "playerid" INTEGER,
    "playerstatus" INTEGER,
    "joindate" INTEGER,
    "lastsubmitted" INTEGER
);

COMMENT ON COLUMN "gameusers"."racefile" IS 'Race file in use for this game';

COMMENT ON COLUMN "gameusers"."delaysleft" IS 'How many delays the player has left for this game';

COMMENT ON COLUMN "gameusers"."playerid" IS 'Player ID in the game';

COMMENT ON COLUMN "gameusers"."playerstatus" IS 'Player Status in this game';

COMMENT ON COLUMN "gameusers"."joindate" IS 'Date Player Joined Game';

COMMENT ON COLUMN "gameusers"."lastsubmitted" IS 'Last Date player submitted turn';

-- CREATE INDEXES ...

CREATE INDEX "gameusers_gameid_idx" ON "gameusers" ("gamename");

CREATE INDEX "gameusers_playerid_idx" ON "gameusers" ("playerid");

ALTER TABLE
    "gameusers"
ADD
    CONSTRAINT "gameusers_pkey" PRIMARY KEY ("gamefile", "user_login", "playerid");

CREATE INDEX "gameusers_userid_idx" ON "gameusers" ("user_login");

CREATE TABLE IF NOT EXISTS "races" (
    "racefile" VARCHAR (50) NOT NULL,
    "racename" VARCHAR (50) NOT NULL,
    "user_login" VARCHAR (50),
    "racedescrip" VARCHAR (50),
    "user_file" VARCHAR (8),
    "raceid" SERIAL
);

COMMENT ON COLUMN "races"."user_file" IS 'Duplicated here for convenience from user';

COMMENT ON COLUMN "races"."raceid" IS 'Unique Race ID';

-- CREATE INDEXES ...

-- CREATE INDEX "races_raceid_idx" ON "races" ();

CREATE TABLE IF NOT EXISTS "user" (
    "user_id" SERIAL,
    "user_login" VARCHAR (25),
    "user_file" VARCHAR (8),
    "user_first" VARCHAR (50),
    "user_last" VARCHAR (50),
    "user_password" VARCHAR (50),
    "user_bio" VARCHAR (255),
    "comments" VARCHAR (50),
    "creategame" BOOLEAN NOT NULL,
    "user_email" VARCHAR (50) NOT NULL,
    "emailturn" BOOLEAN NOT NULL,
    "emaillist" BOOLEAN NOT NULL,
    "user_status" INTEGER,
    "user_creation" VARCHAR (50),
    "user_modified" VARCHAR (50),
    "user_serial" VARCHAR (255)
);

COMMENT ON COLUMN "user"."user_login" IS 'user Unique ID';

COMMENT ON COLUMN "user"."user_file" IS 'Random String used for File Names (instead of User_Login)';

COMMENT ON COLUMN "user"."user_first" IS 'user First Name';

COMMENT ON COLUMN "user"."user_last" IS 'user Last Name';

COMMENT ON COLUMN "user"."user_password" IS 'user Password';

COMMENT ON COLUMN "user"."comments" IS 'Player''s description of self';

COMMENT ON COLUMN "user"."creategame" IS 'Permission to Create games';

COMMENT ON COLUMN "user"."user_email" IS 'Email address';

COMMENT ON COLUMN "user"."emailturn" IS 'Turns should be emailed';

COMMENT ON COLUMN "user"."emaillist" IS 'Email player when new games come out';

COMMENT ON COLUMN "user"."user_status" IS 'Active/Banned/Pending (hmm add active registered and active unregistered)';

COMMENT ON COLUMN "user"."user_creation" IS 'When the account was created';

COMMENT ON COLUMN "user"."user_modified" IS 'When the account was last modified';

COMMENT ON COLUMN "user"."user_serial" IS 'Stars Serial Number';

-- CREATE INDEXES ...

CREATE UNIQUE INDEX "user_email_idx" ON "user" ("user_email");

ALTER TABLE
    "user"
ADD
    CONSTRAINT "user_pkey" PRIMARY KEY ("user_login");

CREATE INDEX "user_user_id_idx" ON "user" ("user_id");

CREATE INDEX "user_userid_idx" ON "user" ("user_login");

-- CREATE Relationships ...

ALTER TABLE
    "gameusers"
ADD
    CONSTRAINT "gameusers_playerstatus_fk" FOREIGN KEY ("playerstatus") REFERENCES "_playerstatus"("playerstatus") ON UPDATE CASCADE ON DELETE CASCADE DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE
    "gameusers"
ADD
    CONSTRAINT "gameusers_gamefile_fk" FOREIGN KEY ("gamefile") REFERENCES "games"("gamefile") ON UPDATE CASCADE ON DELETE CASCADE DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE
    "games"
ADD
    CONSTRAINT "games_gametype_fk" FOREIGN KEY ("gametype") REFERENCES "_gametype"("gametype") ON UPDATE CASCADE DEFERRABLE INITIALLY IMMEDIATE;

-- ALTER TABLE
--     "MSysNavPaneGroups"
-- ADD
--     CONSTRAINT "msysnavpanegroups_groupcategoryid_fk" FOREIGN KEY ("groupcategoryid") REFERENCES "MSysNavPaneGroupCategories"("id") ON UPDATE CASCADE ON DELETE CASCADE DEFERRABLE INITIALLY IMMEDIATE;

-- ALTER TABLE
--     "MSysNavPaneGroupToObjects"
-- ADD
--     CONSTRAINT "msysnavpanegrouptoobjects_groupid_fk" FOREIGN KEY ("groupid") REFERENCES "MSysNavPaneGroups"("id") ON UPDATE CASCADE ON DELETE CASCADE DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE
    "games"
ADD
    CONSTRAINT "games_hostname_fk" FOREIGN KEY ("hostname") REFERENCES "user"("user_login") ON UPDATE CASCADE DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE
    "gameusers"
ADD
    CONSTRAINT "gameusers_user_login_fk" FOREIGN KEY ("user_login") REFERENCES "user"("user_login") ON UPDATE CASCADE DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE
    "races"
ADD
    CONSTRAINT "races_user_login_fk" FOREIGN KEY ("user_login") REFERENCES "user"("user_login") ON UPDATE CASCADE DEFERRABLE INITIALLY IMMEDIATE;

INSERT INTO "_gamestatus" ("gamestatus", "gamestatus_txt") VALUES
    (0,'Pending Start'),
    (1,'Pending Closed'),
    (2,'In Progress'),
    (3,'Delayed'),
    (4,'Paused'),
    (5,'Need Replacement'),
    (6,'Creation in Progress'),
    (7,'Awaiting Players'),
    (9,'Finished');

INSERT INTO "_gametype" ("gametype", "gametype_txt") VALUES
    (1,'Daily'),
    (2,'Hourly'),
    (3,'Required'),
    (4,'All In');

INSERT INTO "_holidays" ("holiday", "holiday_txt", "nationality") VALUES
    ('2018-12-25 00:00:00','Xmas','US'),
    ('2018-11-22 00:00:00','Tgiving','US'),
    ('2018-07-04 00:00:00','4th July','US');

INSERT INTO "_playerstatus" ("playerstatus", "playerstatus_txt") VALUES
    (1,'Active'),
    (2,'Inactive'),
    (3,'Banned'),
    (4,'Idle');

INSERT INTO "_userstatus" ("user_status", "user_status_txt", "user_status_detail") VALUES
    (1,'Active','Account active and in good standing'),
    (-1,'Locked','Account Locked for multiple failed logins'),
    (-2,'Suspended','Inactivated temporarily for some reason'),
    (-3,'Inactive','Account not accessed for x days'),
    (-4,'Disabled','Account no longer valid'),
    (-5,'New','New Inactive user Account'),
    (2,'Reset','Password Reset'),
    (-6,'Banned','user Has Been Banned'),
    (-7,'Pending','user Account Pending');

INSERT INTO "_version" ("version") VALUES
    ('1.0'),
    ('2.7h'),
    ('2.7i'),
    ('2.7j');

-- +goose Down

DROP TABLE "_gamestatus";

DROP TABLE "_gametype";

DROP TABLE "_holidays";

DROP TABLE "_playerstatus";

DROP TABLE "_userstatus";

DROP TABLE "_version";

DROP TABLE "games";

DROP TABLE "gameusers";

DROP TABLE "races";

DROP TABLE "user";