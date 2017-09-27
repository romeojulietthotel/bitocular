#!/usr/bin/perl
use warnings;
use Gtk2 qw(-init -threads-init);
use threads;
use FindBin '$Bin';
use utf8;
use Image::Magick;

use constant TRUE  => 1;
use constant FALSE => 0;

my $pi = 3.141592653589793;

my $n = 0;
my $maxhisto = 0;

die "No file provided.\ne.g.\t$0 interesting.file\n" unless (-f $ARGV[0]);

sub autoflush {
    my $h = select($_[0]); $|=$_[1]; select($h);
}

my $builder = Gtk2::Builder->new();
$builder->add_from_file("$Bin/bitui.ui");

my @uitems = qw(
    window1 hd-label entlabel meanlabel
    chi2label magiclabel corrlabel histoimage
    poincimage entimage meanimage chi2image
    corrimage ccorrimage hexframe magicframe
    entframe histoframe poincframe statusbar );

for $uitem (@uitems) {
    $gui{$uitem} = $builder->get_object($uitem)
}

my $context_id = $gui{"statusbar"}->get_context_id("");

$gui{"window1"}->signal_connect (delete_event => sub {Gtk2->main_quit; FALSE});
$gui{"window1"}->show_all();
$gui{"window1"}->set_title($ARGV[0]);

my $histo = Image::Magick->new(size=>'256x256');
my $poinc = Image::Magick->new(size=>'256x256');

my  $ent_img = '/tmp/entmeter.png';
my  $chi_img = '/tmp/chi2meter.png';
my $mean_img = '/tmp/meanmeter.png';
my $corr_img = '/tmp/corrmeter.png';


# color gradient
$rgb[0] = chr(0) x 3;
for (1..511) {
  $rgb[$_] = chr(0) .
             chr(0xbb * ($_/511)).
             chr(0x33);
}
for (512..1023) {
  $rgb[$_] = chr(0) .
             chr(0xbb + 0x44*(($_-512)/(1023-512))).
             chr(0x33 + 0xcc*(($_-512)/(1023-512)));
}

my @allthreads;
# initialize

push @allthreads, threads->create(\&mkhistogram);
push @allthreads, threads->create(\&worksub);

Gtk2->main;

sub worksub {

  Gtk2::Gdk::Threads->enter;
  $gui{"statusbar"}->push($context_id, "hexdump...");
  Gtk2::Gdk::Threads->leave;

  open(S,"hexdump -C -n 384 -v '$ARGV[0]'|head -n 24|") or die "No hexdump exe found.\n";
  ($hd = join("",<S>)) =~ s/\|/│/g;;
  close(S);
  Gtk2::Gdk::Threads->enter;
  $gui{"hexframe"}->set_sensitive(TRUE);
  $gui{"hd-label"}->set_text($hd);
  Gtk2::Gdk::Threads->leave;
  
  Gtk2::Gdk::Threads->enter;
  $gui{"statusbar"}->push($context_id, "magic...");
  Gtk2::Gdk::Threads->leave;

  open(S,"file -b '$ARGV[0]'|");
  $magic = join("",<S>);
  close(S);
  Gtk2::Gdk::Threads->enter;
  $gui{"magicframe"}->set_sensitive(TRUE);
  $gui{"magiclabel"}->set_text($magic);
  Gtk2::Gdk::Threads->leave;
  
  Gtk2::Gdk::Threads->enter;
  $gui{"statusbar"}->push($context_id, "ent...");
  Gtk2::Gdk::Threads->leave;

  open(SIS,"ent '$ARGV[0]'|");
  for (<SIS>) {
    chomp();
    if    (/Entropy = ([\d\.]+)/)          { $ent  = $1; }
    elsif (/exceed this [^\d]+ ([\d\.]+)/) { $chi2 = $1; }
    elsif (/mean value .* is ([\d\.]+)/)   { $mean = $1; }
    elsif (/oefficient is ([-\d\.]+)/)     { $corr = $1; }
  }
  close(SIS);
      
  if    ($chi2 < 1  || $chi2 > 99) { $chirand = "non-random";     }
  elsif ($chi2 < 5  || $chi2 > 95) { $chirand = "suspect";        }
  elsif ($chi2 < 10 || $chi2 > 90) { $chirand = "almost suspect"; }
  else                             { $chirand = "very random";    }

  Gtk2::Gdk::Threads->enter;
  $gui{"entframe"}->set_sensitive(TRUE);
  $gui{"entlabel"}->set_text("$ent b/B");
  $gui{"meanlabel"}->set_text($mean);
  #$gui{"chi2label"}->set_text("$chi2 % ($chirand)");
  $gui{"chi2label"}->set_text("$chi2 %");
  $gui{"corrlabel"}->set_text("$corr");
  Gtk2::Gdk::Threads->leave;


  $entangle  = -$ent/8 * $pi + $pi/2;
  $meanangle = -(255-abs(127.5-$mean)/127.5) * $pi;# + $pi/2;
  
  $chi2 = 100-$chi2 if ($chi2 > 50);
  if ($chi2 >= 25) {
    $chiangle = -$pi + $pi/2;
  } else {
    $chiangle = $chi2/25 * $pi + $pi/2;
  }

  print "$corr\n";
  $corr = abs(0.01/$corr);
  $corr = 1 if ($corr > 1);
  print "$corr corr\n";
  $corrangle = -$corr * $pi + $pi/2;
  print "$corrangle corrangle\n";

  $entangle  = $entangle  * .778;
  $meanangle = $meanangle * .778;
  $chiangle  = $chiangle  * .778;
  $corrangle = $corrangle * .778;

  my $stroke = '-stroke black -strokewidth 2 -draw \'line 37,37';
  my $init_specs = '-fill transparent -draw \'arc 12,12 64,64 200,340\' ';
  my $specs = ' -size 75x46 xc:transparent -draw \'circle 38,38 42,38\'';
    $specs .= ' -stroke \'#cccccc\' -strokewidth 5 ';
  my $xpspecs = '-fill transparent -draw \'arc 12,12 64,64 200,340\'';

  my $ent_ang1  = 38-26*sin($entangle);
  my $ent_ang2  = 37-26*cos($entangle);
  my $strk_ang1 = 38-26*sin($meanangle);
  my $strk_ang2 = 37-26*cos($meanangle);
  my  $chi_ang1 = 38-26*sin($chiangle);
  my  $chi_ang2 = 37-26*cos($chiangle);
  my $corr_ang1 = 38-26*sin($corrangle);
  my $corr_ang2 = 37-26*cos($corrangle);

  system("convert $specs $init_specs $stroke,$ent_ang1, $ent_ang2\' $ent_img");
  system("convert $specs $xpspecs $stroke,$strk_ang1, $strk_ang2\' $mean_img"); 
  system("convert $specs $xpspecs $stroke,$chi_ang1, $chi_ang2\' $chi_img"); 

  if ($corr ne "undefined") {
      system("convert $specs $xpspecs $stroke,$corr_ang1, $corr_ang2\' $corr_img"); 
  }
  Gtk2::Gdk::Threads->enter;
  $gui{"entimage"}->set_from_file("$ent_img");
  $gui{"chi2image"}->set_from_file("$chi_img");
  $gui{"meanimage"}->set_from_file("$mean_img");
  $gui{"corrimage"}->set_from_file("$corr_img");
  Gtk2::Gdk::Threads->leave;
  
  Gtk2::Gdk::Threads->enter;
  $gui{"statusbar"}->push($context_id, "histogram...");
  Gtk2::Gdk::Threads->leave;

  open(SIS,$ARGV[0]) or die($!);
  $s = -s $ARGV[0];
  while ($n++ < $s) {
    read(SIS,$a,1);
    $a = ord($a);
    $histo[$a]++;
    $maxhisto = $histo[$a] if ($histo[$a] > ($maxhisto // 0));
    if (defined $prev) {
      $poinc[$prev][$a]++;
      $maxpoinc = $poinc[$prev][$a] if ($poinc[$prev][$a] > ($maxpoinc // 0));
    }
    $prev = $a;

    push(@corrarr,$a);
    if (@corrarr > 256) {
      for $c (1..256) {
        for $b (0..7) {
          my $i = (7-$b);
          my $j = (($corrarr[$c] >> $i) & 1) & (($corrarr[0] >> $i) & 1);
          $corr[$b][$c-1] += $j; 
        }
      }
      shift(@corrarr);
    }

    if ($n % 4096 == 0) {
      push @allthreads, threads->create(\&mkhistogram);
      Gtk2::Gdk::Threads->enter;
      $gui{"histoframe"}->set_sensitive(TRUE);
      $gui{"poincframe"}->set_sensitive(TRUE);
      $gui{"statusbar"}->push($context_id, sprintf("histogram... (%.0f %%)",$n/$s*100));
      Gtk2::Gdk::Threads->leave;
    }
  }
  close(SIS);
  push @allthreads, threads->create(\&mkhistogram);
  
  Gtk2::Gdk::Threads->enter;
  $gui{"histoframe"}->set_sensitive(TRUE);
  $gui{"poincframe"}->set_sensitive(TRUE);
  $gui{"statusbar"}->push($context_id, "Done");
  Gtk2::Gdk::Threads->leave;

  use Data::Dumper;
  print Dumper @corr;

}

sub histo {

  open(IM, "|convert -depth 8 -size 256x256 rgb:- /tmp/histo.png");
  autoflush(IM, 1);

  for $y (0..255) {
    for $x (0..255) {
      if ( (($maxhisto // 0) > 0) &&
        ( (($histo[$x] // 0) / $maxhisto * 255 >= 256 - $y) )) {
          print IM $rgb[768];
      } else {
        print IM chr(0) x 3;
      }
    }
  }
  close(IM);
}

sub poinc {

  open(IM, "|convert -depth 8 -size 256x256 rgb:- /tmp/poinc.png");
  autoflush(IM, 1);

  for $y (0..255) {
    for $x (0..255) {
      if (($maxpoinc // 0) > 0 && ($poinc[$x][$y] // 0)/$maxpoinc > 0) {
        if (log($poinc[$x][$y]) / log($maxpoinc*.6) > 1) {
          print IM $rgb[1023];
        } else {
          print IM $rgb[log($poinc[$x][$y]) / log($maxpoinc*.6)*1023];
        }
      } else {
        print IM chr(0) x 3;
      }
    }
  }
  close(IM);
}

sub ccorr {

  open(IM, "|convert -depth 8 -size 256x256 rgb:- /tmp/ccorr.png");
  autoflush(IM, 1);

  for $y (0..255) {
    for $x (0..255) {
      if ($x % 32 == 0) {
        print IM chr(127) x 3;
      } else {
        print IM $rgb[($corr[int($x/32)][$y] // 0)/($n+1)*1023];
      }
    }
  }
  close(IM);
}

sub mkhistogram {

  push @allthreads, threads->create(\&histo);
  push @allthreads, threads->create(\&poinc);
  push @allthreads, threads->create(\&ccorr);
    
  Gtk2::Gdk::Threads->enter;
  $gui{"histoimage"}->set_from_file ("/tmp/histo.png");
  $gui{"poincimage"}->set_from_file ("/tmp/poinc.png");
  $gui{"ccorrimage"}->set_from_file ("/tmp/ccorr.png");
  Gtk2::Gdk::Threads->leave;
}


exit 0;

#for my $athread (0..$#allthreads) {
#    $allthreads[$athread]->join();
#}



