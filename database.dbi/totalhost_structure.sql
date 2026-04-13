-- phpMyAdmin SQL Dump
-- version 5.2.1deb3
-- https://www.phpmyadmin.net/
--
-- Host: localhost:3306
-- Generation Time: Apr 13, 2026 at 03:00 AM
-- Server version: 10.11.14-MariaDB-0ubuntu0.24.04.1
-- PHP Version: 8.3.6

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `totalhost`
--

-- --------------------------------------------------------

--
-- Table structure for table `Games`
--

CREATE TABLE `Games` (
  `GameName` varchar(31) NOT NULL,
  `GameFile` varchar(8) NOT NULL,
  `GameDescrip` varchar(50) DEFAULT NULL,
  `HostName` varchar(25) DEFAULT NULL,
  `GameType` int(11) DEFAULT 0,
  `DailyTime` varchar(50) DEFAULT NULL,
  `HourlyTime` varchar(24) DEFAULT NULL,
  `LastTurn` int(11) DEFAULT 0,
  `NextTurn` int(11) DEFAULT 0,
  `GameStatus` tinyint(3) UNSIGNED DEFAULT 0,
  `DelayCount` tinyint(3) UNSIGNED DEFAULT 0,
  `AsAvailable` tinyint(1) DEFAULT NULL,
  `OnlyIfAvailable` tinyint(1) DEFAULT NULL,
  `DayFreq` varchar(7) DEFAULT NULL,
  `HourFreq` varchar(24) DEFAULT NULL,
  `ForceGen` tinyint(1) DEFAULT NULL,
  `ForceGenTurns` tinyint(3) UNSIGNED DEFAULT 0,
  `ForceGenTimes` tinyint(3) UNSIGNED DEFAULT 0,
  `HostMod` tinyint(1) DEFAULT NULL,
  `HostForce` tinyint(1) DEFAULT NULL,
  `NoDuplicates` tinyint(1) DEFAULT NULL,
  `GameRestore` tinyint(1) DEFAULT NULL,
  `AnonPlayer` tinyint(1) DEFAULT NULL,
  `GamePause` tinyint(1) DEFAULT NULL,
  `GameDelay` tinyint(1) DEFAULT NULL,
  `NumDelay` int(11) DEFAULT 0,
  `MinDelay` int(11) DEFAULT 0,
  `AutoInactive` int(11) DEFAULT 0,
  `ObserveHoliday` tinyint(1) DEFAULT NULL,
  `NewsPaper` tinyint(1) DEFAULT NULL,
  `SharedM` tinyint(1) DEFAULT NULL,
  `Notes` longtext DEFAULT NULL,
  `MaxPlayers` tinyint(3) UNSIGNED DEFAULT 16,
  `HostAccess` tinyint(1) DEFAULT NULL,
  `PublicMessages` tinyint(1) DEFAULT 0,
  `Teams` tinyint(1) NOT NULL DEFAULT 0,
  `Exploit` tinyint(4) NOT NULL DEFAULT 0 COMMENT 'fix file',
  `Sanitize` tinyint(4) NOT NULL DEFAULT 0 COMMENT 'clean file'
) ENGINE=Aria DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `GameUsers`
--

CREATE TABLE `GameUsers` (
  `GameName` varchar(50) DEFAULT NULL,
  `GameFile` varchar(50) NOT NULL,
  `User_Login` varchar(50) NOT NULL,
  `RaceFile` varchar(50) DEFAULT NULL,
  `RaceID` int(11) DEFAULT NULL,
  `DelaysLeft` tinyint(3) UNSIGNED DEFAULT 0,
  `PlayerID` int(11) NOT NULL DEFAULT 0,
  `PlayerStatus` int(11) DEFAULT 0,
  `JoinDate` int(11) DEFAULT 0,
  `LastSubmitted` int(11) DEFAULT 0,
  `Team` tinyint(1) NOT NULL DEFAULT 0
) ENGINE=Aria DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `Races`
--

CREATE TABLE `Races` (
  `RaceID` int(11) NOT NULL,
  `RaceFile` varchar(50) NOT NULL,
  `RaceName` varchar(50) NOT NULL,
  `User_Login` varchar(50) DEFAULT NULL,
  `RaceDescrip` varchar(50) DEFAULT NULL,
  `User_File` varchar(8) DEFAULT NULL
) ENGINE=Aria DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `User`
--

CREATE TABLE `User` (
  `User_ID` int(11) NOT NULL,
  `User_Login` varchar(25) NOT NULL,
  `User_File` varchar(8) DEFAULT NULL,
  `User_First` varchar(50) DEFAULT NULL,
  `User_Last` varchar(50) DEFAULT NULL,
  `User_Password` varchar(50) DEFAULT NULL,
  `User_Bio` varchar(255) DEFAULT NULL,
  `Comments` varchar(50) DEFAULT NULL,
  `CreateGame` tinyint(1) DEFAULT NULL,
  `User_Email` varchar(50) NOT NULL,
  `EmailTurn` tinyint(1) DEFAULT NULL,
  `EmailList` tinyint(1) DEFAULT NULL,
  `User_Status` int(11) DEFAULT 0,
  `User_Creation` varchar(50) DEFAULT NULL,
  `User_Modified` varchar(50) DEFAULT NULL,
  `User_Serial` varchar(255) DEFAULT NULL,
  `User_Timezone` varchar(50) NOT NULL DEFAULT 'America/New_York'
) ENGINE=Aria DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `_GameStatus`
--

CREATE TABLE `_GameStatus` (
  `GameStatus` tinyint(3) UNSIGNED NOT NULL DEFAULT 0,
  `GameStatus_TXT` varchar(50) DEFAULT NULL
) ENGINE=Aria DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `_GameType`
--

CREATE TABLE `_GameType` (
  `GameType` int(11) NOT NULL DEFAULT 0,
  `GameType_txt` varchar(50) DEFAULT NULL
) ENGINE=Aria DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `_Holidays`
--

CREATE TABLE `_Holidays` (
  `Holiday` datetime DEFAULT NULL,
  `Holiday_txt` varchar(50) DEFAULT NULL,
  `Nationality` varchar(2) DEFAULT NULL
) ENGINE=Aria DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `_PlayerStatus`
--

CREATE TABLE `_PlayerStatus` (
  `PlayerStatus` int(11) NOT NULL DEFAULT 0,
  `PlayerStatus_txt` varchar(50) DEFAULT NULL
) ENGINE=Aria DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `_UserStatus`
--

CREATE TABLE `_UserStatus` (
  `User_Status` int(11) DEFAULT 0,
  `User_Status_txt` varchar(50) DEFAULT NULL,
  `User_Status_Detail` varchar(50) DEFAULT NULL
) ENGINE=Aria DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `_Version`
--

CREATE TABLE `_Version` (
  `Version` varchar(50) NOT NULL
) ENGINE=Aria DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;

--
-- Indexes for dumped tables
--

--
-- Indexes for table `Games`
--
ALTER TABLE `Games`
  ADD PRIMARY KEY (`GameFile`),
  ADD UNIQUE KEY `GameName` (`GameName`);

--
-- Indexes for table `GameUsers`
--
ALTER TABLE `GameUsers`
  ADD PRIMARY KEY (`GameFile`,`User_Login`,`PlayerID`),
  ADD KEY `GameName` (`GameName`),
  ADD KEY `PlayerID` (`PlayerID`),
  ADD KEY `RaceID` (`RaceID`),
  ADD KEY `User_Login` (`User_Login`);

--
-- Indexes for table `Races`
--
ALTER TABLE `Races`
  ADD UNIQUE KEY `RaceID` (`RaceID`);

--
-- Indexes for table `User`
--
ALTER TABLE `User`
  ADD PRIMARY KEY (`User_Login`),
  ADD UNIQUE KEY `User_Email` (`User_Email`),
  ADD KEY `User_ID` (`User_ID`),
  ADD KEY `User_Login` (`User_Login`);

--
-- Indexes for table `_GameStatus`
--
ALTER TABLE `_GameStatus`
  ADD PRIMARY KEY (`GameStatus`);

--
-- Indexes for table `_GameType`
--
ALTER TABLE `_GameType`
  ADD PRIMARY KEY (`GameType`);

--
-- Indexes for table `_PlayerStatus`
--
ALTER TABLE `_PlayerStatus`
  ADD PRIMARY KEY (`PlayerStatus`);

--
-- Indexes for table `_Version`
--
ALTER TABLE `_Version`
  ADD PRIMARY KEY (`Version`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `Races`
--
ALTER TABLE `Races`
  MODIFY `RaceID` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `User`
--
ALTER TABLE `User`
  MODIFY `User_ID` int(11) NOT NULL AUTO_INCREMENT;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
