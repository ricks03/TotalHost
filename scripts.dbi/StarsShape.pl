#!/usr/bin/perl
# StarsShape.pl - Rearrange Stars! planet coordinates into galaxy patterns
#
# Reads a coordinate CSV (from StarsMoveXY.pl mode 1) and rearranges the
# newX,newY columns to match the requested pattern.
# Output CSV is compatible with StarsMoveXY.pl mode 2.
#
# Usage: StarsShape.pl <filename> <pattern>
#   filename - CSV from StarsMoveXY.pl (PlanetID,Name,X,Y,newX,newY)
#   pattern  - see below

use strict;
use warnings;
use Math::Trig;
use List::Util qw(shuffle);
use GD;
use POSIX qw(floor);

my %UNIVERSE_SIZES = (
  'Tiny'   => 400,
  'Small'  => 800,
  'Medium' => 1200,
  'Large'  => 1600,
  'Huge'   => 2000,
);

my $MIN_PLANET_SEPARATION = 12;  # Minimum distance between any two planets (dGalMinDist)
my $BRIGHTNESS_THRESH   = 128;   # Pixels darker than this are foreground (image mode)

# Package-level state for Poisson disk sampling (used by image helper subs)
my %_poisson_grid;
my $_poisson_cell_size;

if (@ARGV == 0) { print_usage(); exit 0; }

if (@ARGV < 2 || @ARGV > 3) {
  print "Error: Incorrect number of arguments\n\n";
  print_usage();
  exit 1;
}

my ($filename, $pattern, $size_arg) = @ARGV;

unless (-f $filename) { die "Error: File '$filename' not found\n"; }

my @planets = read_csv($filename);

# Determine universe size
my $universe_size;
if ($size_arg) {
  my $size_name = ucfirst(lc($size_arg));
  die "Error: Unknown universe size '$size_arg'. Valid: " . join(', ', sort keys %UNIVERSE_SIZES) . "\n"
    unless exists $UNIVERSE_SIZES{$size_name};
  $universe_size = $UNIVERSE_SIZES{$size_name};
  print "Universe size: $size_name ($universe_size)\n";
} else {
  $universe_size = detect_universe_size(\@planets);
  print "Detected universe size: $universe_size\n";
}

my $max_separation = $universe_size;

print "\tThis can take a moment ... I'm reorganizing the universe!\n";

# Apply pattern transformation
my @new_coords = apply_pattern(\@planets, $pattern, $universe_size);

# Validate maximum separation
my $isolated_dist = check_max_separation(\@new_coords, $max_separation);
if ($isolated_dist > 0) {
  die sprintf("\nError: Found isolated planet with nearest neighbor at distance %.1f\n" .
    "Maximum allowed distance to nearest neighbor is %d\n" .
    "This pattern creates isolated planets too far from others.\n" .
    "Consider using a different pattern.\n",
    $isolated_dist, $max_separation);
}
print "Separation constraints: min=$MIN_PLANET_SEPARATION, max=$max_separation (all planets validated)\n";

# Sort new coordinates by X value
@new_coords = sort { $a->{x} <=> $b->{x} } @new_coords;

# Assign sorted coordinates to planets in ID order
for my $i (0 .. $#planets) {
  $planets[$i]{newX} = $new_coords[$i]{x};
  $planets[$i]{newY} = $new_coords[$i]{y};
}

write_csv($filename, \@planets);

print "Coordinates updated successfully!\n";

#################################################################3
sub print_usage {
  print "Usage: StarsShape.pl <filename> <pattern> [universe_size]\n\n";
  print "  filename    - CSV from StarsMoveXY.pl (PlanetID,Name,X,Y,newX,newY)\n";
  print "  universe_size - Tiny/Small/Medium/Large/Huge (default: auto-detect)\n\n";
  print "Available patterns:\n";
  print "  spiral-N     - N-arm spiral galaxy (e.g., spiral-2, spiral-3, etc.)\n";
  print "  rings-N    - N concentric rings (e.g., rings-3, rings-5, etc.)\n";
  print "  cluster-N    - N evenly-sized clusters (e.g., cluster-3, cluster-6, etc.)\n";
  print "  barspiral    - Bar spiral galaxy\n";
  print "  elliptical-N   - Elliptical galaxy, N=mean radius % (e.g., elliptical-30)\n";
  print "  grid       - Grid-based sectors\n";
  print "  image:<file>   - Shape from image file (dark on light background)\n";
  print "           Supports PNG, JPEG, GIF, BMP\n";
  print "\nExamples:\n";
  print "  StarsShape.pl coords.csv spiral-3\n";
  print "  StarsShape.pl coords.csv image:myshape.png\n";
  print "  StarsShape.pl coords.csv image:myshape.png Large\n";
}

sub read_csv {
  my ($file) = @_;
  open my $fh, '<', $file or die "Cannot open $file: $!\n";

  my $header = <$fh>;  # Skip header
  my @planets;

  while (my $line = <$fh>) {
    chomp $line;
    my ($id, $name, $x, $y, $newX, $newY) = split /,/, $line;
    push @planets, {
      id   => $id,
      name => $name,
      x  => $x,
      y  => $y,
      newX => $newX,
      newY => $newY,
    };
  }
  close $fh;
  return @planets;
}

sub write_csv {
  my ($file, $planets) = @_;
  open my $fh, '>', $file or die "Cannot write to $file: $!\n";

  print $fh "PlanetID,Name,X,Y,newX,newY\n";

  for my $p (@$planets) {
    printf $fh "%d,%s,%d,%d,%d,%d\n",
      $p->{id}, $p->{name}, $p->{x}, $p->{y},
      int($p->{newX} + 0.5), int($p->{newY} + 0.5);
    }
  close $fh;
}

sub detect_universe_size {
  my ($planets) = @_;

  my ($minX, $maxX, $minY, $maxY) = (999999, 0, 999999, 0);

  for my $p (@$planets) {
    $minX = $p->{x} if $p->{x} < $minX;
    $maxX = $p->{x} if $p->{x} > $maxX;
    $minY = $p->{y} if $p->{y} < $minY;
    $maxY = $p->{y} if $p->{y} > $maxY;
  }

  my $rangeX = ($maxX - 1000) - ($minX - 1000);
  my $rangeY = ($maxY - 1000) - ($minY - 1000);
  my $max_range = $rangeX > $rangeY ? $rangeX : $rangeY;

  for my $size (sort { $UNIVERSE_SIZES{$a} <=> $UNIVERSE_SIZES{$b} } keys %UNIVERSE_SIZES) {
    if ($max_range <= $UNIVERSE_SIZES{$size}) {
      return $UNIVERSE_SIZES{$size};
    }
  }
  return $UNIVERSE_SIZES{'Huge'};
}

sub apply_pattern {
  my ($planets, $pattern, $universe_size) = @_;

  my $num_planets = scalar @$planets;

  if ($pattern =~ /^spiral-(\d+)$/) { return create_spiral($num_planets, $1, $universe_size);    
  } elsif ($pattern =~ /^rings-(\d+)$/) { return create_rings($num_planets, $1, $universe_size);    
  } elsif ($pattern =~ /^cluster-(\d+)$/) { return create_clusters($num_planets, $1, $universe_size);    
  } elsif ($pattern =~ /^elliptical-(\d+)$/) { return create_elliptical($num_planets, $universe_size, $1);    
  } elsif ($pattern eq 'barspiral') { return create_barspiral($num_planets, $universe_size);   
  } elsif ($pattern eq 'grid') { return create_grid($num_planets, $universe_size);    
  } elsif ($pattern =~ /^image:(.+)$/) {
    my $image_file = $1;
    die "Error: Cannot read image file '$image_file'\n" unless -r $image_file;
    return create_from_image($num_planets, $image_file, $universe_size);
  } else { die "Error: Unknown pattern '$pattern'\n"; }
}

sub create_from_image {
  my ($num_planets, $image_file, $universe_size) = @_;

  # Load image
  my $img;
  if  ($image_file =~ /\.png$/i)   { $img = GD::Image->newFromPng($image_file, 1);  }
  elsif ($image_file =~ /\.jpe?g$/i) { $img = GD::Image->newFromJpeg($image_file, 1); }
  elsif ($image_file =~ /\.gif$/i)   { $img = GD::Image->newFromGif($image_file);    }
  elsif ($image_file =~ /\.bmp$/i)   { $img = GD::Image->newFromBmp($image_file);    }
  else  { die "Error: Unsupported image format. Use PNG, JPEG, GIF, or BMP.\n"; }
  die "Error: Failed to load image '$image_file'\n" unless $img;

  my ($img_w, $img_h) = $img->getBounds();
  print "Image: ${img_w}x${img_h} pixels\n";

  # Collect foreground pixels (darker than threshold)
  my @foreground;
  for my $py (0 .. $img_h - 1) {
    for my $px (0 .. $img_w - 1) {
      my $index = $img->getPixel($px, $py);
      my ($r, $g, $b) = $img->rgb($index);
      push @foreground, [$px, $py] if ($r + $g + $b) / 3 < $BRIGHTNESS_THRESH;
    }
  }

  my $fg_count = scalar @foreground;
  print "Foreground pixels: $fg_count\n";
  die "Error: No foreground pixels found (looking for dark pixels below brightness $BRIGHTNESS_THRESH).\n"
    unless $fg_count > 0;

  # Scale image to universe coordinate space, preserving aspect ratio
  my $margin = $MIN_PLANET_SEPARATION * 2;
  my $avail  = $universe_size - 2 * $margin;
  die "Error: Universe too small for margin constraints.\n" if $avail <= 0;

  my $scale = ($img_w >= $img_h) ? $avail / $img_w : $avail / $img_h;
  my $scaled_w = $img_w * $scale;
  my $scaled_h = $img_h * $scale;
  my $offset_x = 1000 + $margin + ($avail - $scaled_w) / 2;
  my $offset_y = 1000 + $margin + ($avail - $scaled_h) / 2;
  printf "Scale factor: %.4f  Offset: (%.1f, %.1f)\n", $scale, $offset_x, $offset_y;

  # Map foreground pixels to universe coordinates and deduplicate
  my %seen;
  my @candidates;
  for my $fp (@foreground) {
    my $ux = int($fp->[0] * $scale + $offset_x + 0.5);
    my $uy = int($fp->[1] * $scale + $offset_y + 0.5);
    my $key = "$ux,$uy";
    push @candidates, [$ux, $uy] unless $seen{$key}++;
  }

  my $cand_count = scalar @candidates;
  print "Unique candidate positions: $cand_count\n";

  if ($cand_count < $num_planets) {
    warn "Warning: Only $cand_count unique positions available for $num_planets planets.\n";
    warn "  Try a larger universe size or fewer planets.\n";
  }

  # --- Poisson disk sampling ---
  # Phase 1: Shuffle all candidates and accept every point that clears
  #   MIN_PLANET_SEPARATION from all previously accepted points.
  # Phase 2: If we placed more than needed, thin to target count using
  #   stratified (grid-based) selection to preserve spatial coverage.

  # Reset package-level Poisson grid state
  %_poisson_grid   = ();
  $_poisson_cell_size = $MIN_PLANET_SEPARATION;

  @candidates = shuffle(@candidates);

  my @accepted;
  for my $c (@candidates) {
    if (_poisson_check_sep($c->[0], $c->[1])) {
      push @accepted, $c;
      _poisson_add($c->[0], $c->[1]);
    }
  }

  printf "Phase 1: Placed %d points (target: %d)\n", scalar(@accepted), $num_planets;

  # Phase 2: thin down if over target
  if (scalar(@accepted) > $num_planets) {
  my $thin_cell = $MIN_PLANET_SEPARATION * 4;
  my %cell_points;

  for my $i (0 .. $#accepted) {
    my $cx = floor($accepted[$i][0] / $thin_cell);
    my $cy = floor($accepted[$i][1] / $thin_cell);
    push @{$cell_points{"$cx,$cy"}}, $i;
  }

  for my $key (keys %cell_points) {
    @{$cell_points{$key}} = shuffle(@{$cell_points{$key}});
  }

  my %selected;
  my @cell_keys = shuffle(keys %cell_points);
  my $round = 0;

  while (scalar(keys %selected) < $num_planets) {
    my $added_this_round = 0;
    for my $key (@cell_keys) {
      last if scalar(keys %selected) >= $num_planets;
      my $pts = $cell_points{$key};
      if ($round < scalar(@$pts)) {
        $selected{$pts->[$round]} = 1;
        $added_this_round++;
      }
    }
    last unless $added_this_round;
    $round++;
  }

  @accepted = @accepted[sort { $a <=> $b } keys %selected];
  }

  my $placed = scalar @accepted;
  if ($placed < $num_planets) {
    warn "Warning: Could only place $placed of $num_planets planets.\n";
    warn "  The image may not have enough area for this density at min separation $MIN_PLANET_SEPARATION.\n";
  }
  print "Placed: $placed planets\n";

  # Convert arrayrefs to {x,y} hashrefs to match the rest of StarsShape
  return map { { x => $_->[0], y => $_->[1] } } @accepted;
}

# Poisson disk sampling helpers (use package-level %_poisson_grid / $_poisson_cell_size)

sub _poisson_grid_key {
  my ($x, $y) = @_;
  return floor($x / $_poisson_cell_size) . ',' . floor($y / $_poisson_cell_size);
}

sub _poisson_check_sep {
  my ($x, $y) = @_;
  my $gx = floor($x / $_poisson_cell_size);
  my $gy = floor($y / $_poisson_cell_size);
  my $min_sq = $MIN_PLANET_SEPARATION ** 2;

  for my $dx (-2 .. 2) {
    for my $dy (-2 .. 2) {
      my $key = ($gx + $dx) . ',' . ($gy + $dy);
      next unless exists $_poisson_grid{$key};
      for my $pt (@{$_poisson_grid{$key}}) {
      return 0 if ($x - $pt->[0])**2 + ($y - $pt->[1])**2 < $min_sq;
      }
    }
  }
  return 1;
}

sub _poisson_add {
  my ($x, $y) = @_;
  push @{$_poisson_grid{_poisson_grid_key($x, $y)}}, [$x, $y];
}

sub create_spiral {
  my ($num_planets, $arms, $universe_size) = @_;

  my $center = $universe_size / 2;
  my $max_radius = $universe_size * 0.45;
  my @coords;

  for my $i (0 .. $num_planets - 1) {
  my $arm = $i % $arms;
  my $arm_angle = (2 * pi * $arm) / $arms;

  my $t = $i / $num_planets;
  my $radius = $max_radius * sqrt($t);
  my $angle = $arm_angle + $t * 4 * pi;

  $radius += rand(20) - 10;
  $angle  += rand(0.3) - 0.15;

  my $x = $center + $radius * cos($angle);
  my $y = $center + $radius * sin($angle);

  push @coords, { x => $x + 1000, y => $y + 1000 };
  }
  return ensure_separation(\@coords, $MIN_PLANET_SEPARATION, $universe_size);
}

sub create_rings {
  my ($num_planets, $num_rings, $universe_size) = @_;

  my $center = $universe_size / 2;
  my $max_radius = $universe_size * 0.45;
  my @coords;

  my $planets_per_ring = int($num_planets / $num_rings);
  my $remainder = $num_planets % $num_rings;

  for my $ring (0 .. $num_rings - 1) {
    my $count  = $planets_per_ring + ($ring < $remainder ? 1 : 0);
    my $radius = $max_radius * ($ring + 1) / $num_rings;

    for my $i (0 .. $count - 1) {
      my $angle = (2 * pi * $i) / $count + rand(0.2) - 0.1;
      my $r   = $radius + rand(15) - 7.5;

      push @coords, {
      x => $center + $r * cos($angle) + 1000,
      y => $center + $r * sin($angle) + 1000,
      };
    }
  }
  return ensure_separation(\@coords, $MIN_PLANET_SEPARATION, $universe_size);  
}

sub create_clusters {
  my ($num_planets, $num_clusters, $universe_size) = @_;

  my $center = $universe_size / 2;
  my @coords;

  my @cluster_centers;
  for my $i (0 .. $num_clusters - 1) {
    my $angle  = (2 * pi * $i) / $num_clusters + rand(0.5) - 0.25;
    my $distance = $universe_size * (0.2 + rand(0.2));
    push @cluster_centers, {
      x => $center + $distance * cos($angle),
      y => $center + $distance * sin($angle),
    };
  }

  my $planets_per_cluster = int($num_planets / $num_clusters);
  my $remainder = $num_planets % $num_clusters;

  for my $c (0 .. $num_clusters - 1) {
    my $count      = $planets_per_cluster + ($c < $remainder ? 1 : 0);
    my $cluster_radius = $universe_size * 0.08;

    for my $i (0 .. $count - 1) {
      my $angle  = rand(2 * pi);
      my $radius = rand($cluster_radius);
      push @coords, {
      x => $cluster_centers[$c]{x} + $radius * cos($angle) + 1000,
      y => $cluster_centers[$c]{y} + $radius * sin($angle) + 1000,
      };
    }
  }
  return ensure_separation(\@coords, $MIN_PLANET_SEPARATION, $universe_size);  
}

sub create_barspiral {
  my ($num_planets, $universe_size) = @_;

  my $center   = $universe_size / 2;
  my $max_radius = $universe_size * 0.45;
  my @coords;

  my $bar_count  = int($num_planets * 0.3);
  my $spiral_count = $num_planets - $bar_count;

  my $bar_length = $universe_size * 0.25;
  for my $i (0 .. $bar_count - 1) {
    my $t = ($i / $bar_count) - 0.5;
    push @coords, {
      x => $center + $bar_length * $t + 1000,
      y => $center + rand(20) - 10 + 1000,
  };
  }

  for my $i (0 .. $spiral_count - 1) {
    my $arm     = $i % 2;
    my $arm_angle = $arm * pi;
    my $t     = $i / $spiral_count;
    my $radius  = $max_radius * 0.4 + $max_radius * 0.6 * sqrt($t);
    my $angle   = $arm_angle + $t * 3 * pi;
    push @coords, {
      x => $center + $radius * cos($angle) + 1000,
      y => $center + $radius * sin($angle) + 1000,
    };
  }
  return ensure_separation(\@coords, $MIN_PLANET_SEPARATION, $universe_size);  
}

sub create_elliptical {
  my ($num_planets, $universe_size, $mean_pct) = @_;

  my $center   = $universe_size / 2;
  my $max_radius = $universe_size * 0.45;
  my $min_radius = $universe_size * 0.1;
  my @coords;

  for my $i (0 .. $num_planets - 1) {
    my $r   = gaussian_radius($min_radius, $max_radius, $mean_pct);
    my $angle = rand(2 * pi);
    push @coords, {
      x => $center + $r      * cos($angle) + 1000,
      y => $center + $r * 0.8  * sin($angle) + 1000,
    };
  }
  return ensure_separation(\@coords, $MIN_PLANET_SEPARATION, $universe_size);
}

sub gaussian_radius {
  my ($min_radius, $max_radius, $mean_pct) = @_;

  my $u1 = rand();
  my $u2 = rand();
  my $z  = sqrt(-2 * log($u1)) * cos(2 * pi * $u2);

  my $range      = $max_radius - $min_radius;
  my $mean_fraction  = $mean_pct / 100.0;
  my $stddev_fraction = $mean_fraction / 2.0;

  my $radius = $min_radius + $range * ($mean_fraction + $z * $stddev_fraction);
  $radius = $min_radius if $radius < $min_radius;
  $radius = $max_radius if $radius > $max_radius;
  return $radius;
}

sub create_grid {
  my ($num_planets, $universe_size) = @_;

  my @coords;
  my $grid_size = int(sqrt($num_planets)) + 1;
  my $cell_size = $universe_size / $grid_size;

  for my $i (0 .. $num_planets - 1) {
    my $row = int($i / $grid_size);
    my $col = $i % $grid_size;
    push @coords, {
      x => $col * $cell_size + rand($cell_size * 0.8) + $cell_size * 0.1 + 1000,
      y => $row * $cell_size + rand($cell_size * 0.8) + $cell_size * 0.1 + 1000,
    };
  }
  return ensure_separation(\@coords, $MIN_PLANET_SEPARATION, $universe_size);
}

sub check_max_separation {
  my ($coords, $max_separation) = @_;

  for my $i (0 .. $#$coords) {
    my $min_dist_to_any = 999999;

    for my $j (0 .. $#$coords) {
      next if $i == $j;
      my $dx   = $coords->[$i]{x} - $coords->[$j]{x};
      my $dy   = $coords->[$i]{y} - $coords->[$j]{y};
      my $dist = sqrt($dx * $dx + $dy * $dy);
      $min_dist_to_any = $dist if $dist < $min_dist_to_any;
    }
    return $min_dist_to_any if $min_dist_to_any > $max_separation;
  }
  return 0;
}

# sub ensure_separation {
#   my ($coords, $min_dist) = @_;
# 
#   my $max_iterations = 1000;
#   my $min_dist_sq  = $min_dist * $min_dist;
# 
#   for my $iter (1 .. $max_iterations) {
#   my $collision_found = 0;
# 
#   for my $i (0 .. $#$coords) {
#     for my $j ($i + 1 .. $#$coords) {
#       my $dx    = $coords->[$i]{x} - $coords->[$j]{x};
#       my $dy    = $coords->[$i]{y} - $coords->[$j]{y};
#       my $dist_sq = $dx * $dx + $dy * $dy;
# 
#       if ($dist_sq < $min_dist_sq) {
#         $collision_found = 1;
#         my $dist = sqrt($dist_sq);
#         my $push = ($min_dist - $dist) / 2;
# 
#         if ($dist > 0) {
#         my $push_x = ($dx / $dist) * $push;
#         my $push_y = ($dy / $dist) * $push;
#         $coords->[$i]{x} += $push_x;
#         $coords->[$i]{y} += $push_y;
#         $coords->[$j]{x} -= $push_x;
#         $coords->[$j]{y} -= $push_y;
#         } else {
#         my $angle = rand(2 * pi);
#         $coords->[$i]{x} += $min_dist * cos($angle) / 2;
#         $coords->[$i]{y} += $min_dist * sin($angle) / 2;
#         $coords->[$j]{x} -= $min_dist * cos($angle) / 2;
#         $coords->[$j]{y} -= $min_dist * sin($angle) / 2;
#         }
#       }
#     }
#   }
#   last unless $collision_found;
#   }
#   return @$coords;
# }


sub ensure_separation {
  my ($coords, $min_dist, $universe_size) = @_;

  my $max_iterations = 1000;
  my $min_dist_sq  = $min_dist * $min_dist;
  my $coord_min = 1000;
  my $coord_max = 1000 + $universe_size;

  for my $iter (1 .. $max_iterations) {
    my $collision_found = 0;

    for my $i (0 .. $#$coords) {
      for my $j ($i + 1 .. $#$coords) {
        my $dx    = $coords->[$i]{x} - $coords->[$j]{x};
        my $dy    = $coords->[$i]{y} - $coords->[$j]{y};
        my $dist_sq = $dx * $dx + $dy * $dy;

        if ($dist_sq < $min_dist_sq) {
          $collision_found = 1;
          my $dist = sqrt($dist_sq);
          my $push = ($min_dist - $dist) / 2;

          if ($dist > 0) {
            my $push_x = ($dx / $dist) * $push;
            my $push_y = ($dy / $dist) * $push;
            $coords->[$i]{x} += $push_x;
            $coords->[$i]{y} += $push_y;
            $coords->[$j]{x} -= $push_x;
            $coords->[$j]{y} -= $push_y;
          } else {
            my $angle = rand(2 * pi);
            $coords->[$i]{x} += $min_dist * cos($angle) / 2;
            $coords->[$i]{y} += $min_dist * sin($angle) / 2;
            $coords->[$j]{x} -= $min_dist * cos($angle) / 2;
            $coords->[$j]{y} -= $min_dist * sin($angle) / 2;
          }
          # Clamp both planets back into valid Stars! coordinate bounds
          $coords->[$i]{x} = $coord_min if $coords->[$i]{x} < $coord_min;
          $coords->[$i]{x} = $coord_max if $coords->[$i]{x} > $coord_max;
          $coords->[$i]{y} = $coord_min if $coords->[$i]{y} < $coord_min;
          $coords->[$i]{y} = $coord_max if $coords->[$i]{y} > $coord_max;
          $coords->[$j]{x} = $coord_min if $coords->[$j]{x} < $coord_min;
          $coords->[$j]{x} = $coord_max if $coords->[$j]{x} > $coord_max;
          $coords->[$j]{y} = $coord_min if $coords->[$j]{y} < $coord_min;
          $coords->[$j]{y} = $coord_max if $coords->[$j]{y} > $coord_max;
        }
      }
    }
    last unless $collision_found;
  }
  return @$coords;
}