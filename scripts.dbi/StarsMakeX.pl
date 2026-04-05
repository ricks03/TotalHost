#!/usr/bin/perl
# StarsMakeX.pl
# Create a blank .x file for all players. 
#
# Version History
# 260222  Version 1.0
#
#     Copyright (C) 2026 Rick Steeves
# 
#     This file is part of TotalHost, a Stars! hosting utility.
#     TotalHost is free software: you can redistribute it and/or modify
#     it under the terms of the GNU General Public License as published by
#     the Free Software Foundation, either version 3 of the License, or
#     (at your option) any later version.
# 
#     This program is distributed in the hope that it will be useful,
#     but WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#     GNU General Public License for more details.
# 
#     You should have received a copy of the GNU General Public License
#     along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# Creates blank .x (orders) files for all players in a Stars! game.
# A "blank" .x file contains only:
#   Block 8  - rtBOF            (file header,          16 bytes, unencrypted)
#   Block 9  - rtLogHdr         (log header,            17 bytes, encrypted)
#   Block 46 - SaveAndSubmitBlock ( 8 bytes,            encrypted)
#   Block 0  - rtEOF            (end of file,            0 bytes, unencrypted)

use strict;
use warnings;
use File::Basename;
use FindBin;
use lib $FindBin::Bin;
use StarsBlock;

my $filename = $ARGV[0];
unless ($filename) {
  print "\n\nUsage: StarsMakeX.pl <game.hst>\n\n";
  print "Creates a blank .x file for every player in the game.\n";
  print "Example:\n\tStarsMakeX.pl c:\\stars\\mygame.hst\n\n";
  print "Will not replace existing .x files\n";
  print "As always, back up your files before running any tool.\n";
  exit;
}
unless (-e $filename) { print "File $filename does not exist!\n"; exit; }

my ($prefix, $dir, $ext) = fileparse($filename, qr/\.[^.]*/);
$dir =~ s/\\/\//g;

print "Reading HST: $filename\n";
my @hstBytes;
{
  my $fv;
  open(my $fh, '<', $filename) or die "Cannot open $filename: $!\n";
  binmode $fh;
  while (read($fh, $fv, 1)) { push @hstBytes, $fv; }
  close $fh;
}

# Parse block 8 (rtBOF) from the HST
my $FileValues = $hstBytes[1] . $hstBytes[0];
my ($typeId, $size) = parseBlock($FileValues, 0);
die "Expected block 8 first in HST, got block $typeId\n" unless $typeId == 8;

my @headerBlock = @hstBytes[0 .. (2 + $size - 1)];
my ($binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti, $dt)
    = getFileHeaderBlock(\@headerBlock);

print "  Game ID : $lidGame\n";
print "  Turn    : " . ($turn + 2400) . "\n";
print "  Magic   : $Magic\n";

# Count players (one Block 6 per player in the HST)
my $numPlayers = _count_players_in_hst(\@hstBytes);
die "Could not determine player count from HST\n" unless $numPlayers > 0;
print "  Players : $numPlayers\n\n";

# Generate one .x file per player
for my $playerNum (1 .. $numPlayers) {
  my $playerIdx = $playerNum - 1;
  my $xFile     = "${dir}${prefix}.x${playerNum}";

  # Only create an xfile if none exists.
  if (!-f $xFile) {
    print "Writing player $playerNum -> $xFile\n";
    my @outBytes = _make_x_file(\@headerBlock, $playerIdx);

    open(my $ofh, '>:raw', $xFile) or die "Cannot write $xFile: $!\n";
    print $ofh $_ for @outBytes;
    close $ofh;
  }
}

# Clean up the TH .chk file so the display will refresh with game state.
my $chkFile = "${dir}${prefix}.chk";
if (-e $chkFile) {
  unlink $chkFile or warn "Could not remove $chkFile: $!\n";
  print "Removed $chkFile\n";
} else { print "No .chk file $chkFile to remove\n"; }

print "\nDone.\n";

#####################################################3
# _count_players_in_hst - count Block 6 (rtPlr) records, advancing PRNG
sub _count_players_in_hst {
  my ($fileBytes) = @_;
  my @fileBytes   = @{$fileBytes};
  my ($seedA, $seedB);
  my $offset = 0;
  my $count  = 0;

  while ($offset < @fileBytes) {
    last if $offset + 2 > @fileBytes;
    my $fv2 = $fileBytes[$offset + 1] . $fileBytes[$offset];
    my ($tid, $sz) = parseBlock($fv2, $offset);
    my @data;
    @data = @fileBytes[$offset + 2 .. $offset + 2 + $sz - 1] if $sz > 0;

    if ($tid == 8) {
      my @blk = @fileBytes[$offset .. $offset + 2 + $sz - 1];
      my ($bS, $fSW, $Plr, $Trn, $lid2) = getFileHeaderBlock(\@blk);
      ($seedA, $seedB) = initDecryption($bS, $fSW, $Plr, $Trn, $lid2);
    } elsif ($tid == 0) {
      # rtEOF - unencrypted, nothing to do
    } elsif (defined $seedA && $sz > 0) {
      my ($dec, $sA, $sB) = decryptBytes(\@data, $seedA, $seedB);
      ($seedA, $seedB) = ($sA, $sB);
      $count++ if $tid == 6;
    }
    $offset += 2 + $sz;
  }
  return $count;
}

# _make_x_file($headerBlockRef, $playerIdx)
#
# Block layout:
#
#   Block 8  rtBOF            (16 bytes, unencrypted) - RTBOF struct
#   Block 9  rtLogHdr         (17 bytes, encrypted)   - RTLOGHDR struct
#   Block 46 SaveAndSubmitBlock(8 bytes, encrypted)   - all zeros
#   Block 0  rtEOF            ( 0 bytes, unencrypted)
#
# RTBOF (block 8, 16 data bytes):
#   [0.. 3] char rgid[4]       "J3J3"
#   [4.. 7] long lidGame       game ID (must match game.lid)
#   [8.. 9] unsigned short     version (verInc:5, verMinor:7, verMajor:4)
#   [10..11] unsigned short    turn
#   [12..13] short             iPlayer:5, lSaltTime:11  (encryption salt)
#   [14..15] unsigned short    dt:8, fDone:1, fInUse:1, fMulti:1,
#                              fGameOverMan:1, fCrippled:1, wGen:3
#
# RTLOGHDR (block 9, 17 data bytes):
#   [0.. 1] short cbLog        total byte count of all blocks after block 9,
#                              up to (but not including) block 0.
#                              With one 8-byte block 46: cbLog = 2+8 = 10.
#   [2.. 5] long lSerialNumber 0 for blank
#   [6..16] BYTE rgbConfig[11] 0 for blank
#
# Flags word notes:
#   wGen MUST be copied from the HST - Stars! checks rtbof.wGen == game.wGen
#   for dtLog files and rejects with "not in right game" if they differ.
#   fCrippled must also be copied (affects encryption seed derivation).
sub _make_x_file {
  my ($headerBlockRef, $playerIdx) = @_;
  my @hb = @{$headerBlockRef};

  my ($binSeedH, $fSharewareH, $PlayerH, $turnH, $lidGameH, $MagicH)
      = getFileHeaderBlock($headerBlockRef);

  my $version   = ord($hb[10]) | (ord($hb[11]) << 8);

  # Flags word from HST block 8 (RTBOF offset 14 = headerBlock index 16)
  my $hst_flags = ord($hb[16]) | (ord($hb[17]) << 8);
  my $wGen      = ($hst_flags >> 13) & 0x7;
  my $fCrippled = ($hst_flags >> 12) & 0x1;

  # Build flags word for the .x file:
  #   dt=1 (dtLog), fDone=1 (submitted), wGen and fCrippled copied from HST
  my $flags = 0x01             # dt = 1 (dtLog)
            | (1    << 8)      # fDone = 1
            | ($fCrippled << 12)
            | ($wGen      << 13);

  # iPlayer:5 in bits 4:0, lSaltTime:11 in bits 15:5
  my $salt        = int(rand(2047)) & 0x7FF;
  my $iPlayerWord = (($salt & 0x7FF) << 5) | ($playerIdx & 0x1F);

  my $magic4 = substr($MagicH . "\x00\x00\x00\x00", 0, 4);

  # --- Block 8 (rtBOF, 16 data bytes) --------------------------------------
  my @block8;
  push @block8, &write16(_make_block_header(8, 16));
  push @block8, split(//, $magic4);
  push @block8, &write32($lidGameH);
  push @block8, &write16($version);
  push @block8, &write16($turnH);
  push @block8, &write16($iPlayerWord);
  push @block8, &write16($flags);
  die "block8 length error: " . scalar(@block8) . "\n" unless @block8 == 18;

  # Initialise encryption seeds from our own block 8
  my ($bS, $fSW, $Plr, $Trn, $lid2) = getFileHeaderBlock(\@block8);
  my ($seedX, $seedY) = initDecryption($bS, $fSW, $Plr, $Trn, $lid2);

  # --- Block 9 (rtLogHdr, 17 data bytes) -----------------------------------
  # struct _rtloghdr { short cbLog; long lSerialNumber; BYTE rgbConfig[11]; }
  # cbLog = total bytes between end of block 9 and start of block 0.
  #   = block46 header(2) + block46 data(8) = 10
  my $cbLog = 10;
  my @data9 = (
    $cbLog & 0xFF, ($cbLog >> 8) & 0xFF,  # short cbLog (LE)
    0, 0, 0, 0,                            # long lSerialNumber = 0
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,      # BYTE rgbConfig[11] = 0
  );
  my @fakeBlk9 = (&write16(_make_block_header(9, 17)), map { chr($_) } @data9);
  my ($enc9ref, $sX2, $sY2) = encryptBlock(\@fakeBlk9, \@data9, 0, $seedX, $seedY);
  ($seedX, $seedY) = ($sX2, $sY2);

  # --- Block 46 (SaveAndSubmitBlock, 8 data bytes, all zeros) --------------
  # Always 8 bytes in a .x file. cbLog above accounts for these 10 bytes (2+8).
  my @data46    = (0) x 8;
  my @fakeBlk46 = (&write16(_make_block_header(46, 8)), map { chr($_) } @data46);
  my ($enc46ref2) = encryptBlock(\@fakeBlk46, \@data46, 0, $seedX, $seedY);

  # --- Block 0 (rtEOF, 0 data bytes) ---------------------------------------
  my @block0 = &write16(_make_block_header(0, 0));

  return (@block8, @{$enc9ref}, @{$enc46ref2}, @block0);

}

sub _make_block_header {
  my ($typeId, $size) = @_;
  return ($typeId << 10) | ($size & 0x3FF);
}

sub write16 {
  my ($v) = @_;
  return chr($v & 0xFF), chr(($v >> 8) & 0xFF);
}

sub write32 {
  my ($v) = @_;
  return chr( $v        & 0xFF), chr(($v >>  8) & 0xFF),
         chr(($v >> 16) & 0xFF), chr(($v >> 24) & 0xFF);
}
