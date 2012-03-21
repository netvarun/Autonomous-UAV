#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;
use JSON::XS;
use CGI qw(:standard);
use CGI::Carp qw(warningsToBrowser fatalsToBrowser);
use LWP::Simple qw($ua !get !head);
use Facebook::Graph;
use Log::Log4perl qw(:easy);

Log::Log4perl->easy_init(
  {
    level => $ERROR,
    file  => ">> /var/www/getScreenshots_log",
  }
);

my $startUrl = "http://api.face.com/faces/";

my $detectJson = "detect.json?";
my $recognizeJson = "recognize.json?";
my $apiPortion;
my $secondPart = "&detector=Aggressive&attributes=all&";
my $recognizePart;

$ua->timeout(10);

my @files = </var/www/images/*.png>;

for(my $i=0;$i<scalar(@files);$i++)
{
  my $file = $files[$i];
  $file=~s/\/var\/www\/images/http:\/\/dl\.dropbox\.com\/u\/11215948\/images/si;
  $files[$i] = $file;
}

@files = sort(@files);

my @last_n = @files[-5..-1];

foreach my $image(@last_n)
{
  my $ct=0;
  if(LWP::Simple::head($image))
  {
    #print STDERR "Url exists\n";
    ERROR("$image exists\n");
  }
  else
  {
    delete $last_n[$ct];
    ERROR("$image Doesn't exist!!!!\n");
  }
  $ct++;
}
my $imageUrl = $last_n[2];
if(!defined($imageUrl))
{
  $imageUrl  ="http://dl.dropbox.com/u/11215948/images/1329674346.png";
}
#$imageUrl  ="http://i.imgur.com/ef8RS.png";
#my $faceComUrl = $startUrl.$detectJson.$apiPortion.$imageUrl.$secondPart;
my $faceComUrl = $startUrl.$recognizeJson.$apiPortion.$imageUrl.$secondPart.$recognizePart;

ERROR("Face.com url is $faceComUrl\n");
my $jsonString = LWP::Simple::get($faceComUrl);
my $outputString = faceDetection($jsonString);
my $outputRef;
$outputRef->{'output'} = $outputString;
$outputRef->{'image'} = $imageUrl;

#print STDERR $outputString,"\n";
ERROR("$outputString\n");

my $json_text = encode_json($outputRef);

print header('application/json');
my $callback = param('callback');
if (length($callback) > 0) {
  print $callback . "(" . $json_text . ")";
}
else
{
  print $json_text;
}

sub faceDetection
{
  my $json = shift;
  ERROR("Json = $json\n");

  my $hash_ref = decode_json $json;

  my @photos = @{$hash_ref->{'photos'}};
  my $fb = Facebook::Graph->new;

  my $totalPeople = 0;
  my $malePeople = 0;
  my $femalePeople = 0;
  my $glassesPeople = 0;
  my $smilingPeople = 0;
  my $moods = "";
  my $totalString = "Found People from Facebook: ";

  foreach(@photos)
  {
    my $photo_ref = $_;

    my @tags =@{$photo_ref->{'tags'}};

    foreach(@tags)
    {
      #all people can be inferred from here
      my $tag_ref = $_;
      my %moodHash=();


      my $attribs_ref = $tag_ref->{'attributes'};

      if(defined($attribs_ref->{'face'}) && $attribs_ref->{'face'}->{'value'}=~/true/)
      {
        my @uids = @{$tag_ref->{'uids'}};
        my $facebookId = $uids[0]->{'uid'};
        my $facebookVal = $uids[0]->{'confidence'};
        if(defined($facebookId))
        {
          my $confidenceNum = int($facebookVal);
          if($confidenceNum > 75)
          {
            $facebookId=~s/(.*)\@.*/$1/si;
            $facebookId = "https://graph.facebook.com/".$facebookId;
            my $facebookName = $fb->query->request($facebookId)->as_hashref->{'name'};
            $totalString .= $facebookName.",";
          }
        }

        $totalPeople++;
        if(defined($attribs_ref->{'gender'}) && $attribs_ref->{'gender'}->{'value'} =~/male/)
        {
          $malePeople++;
        }
        else
        {
          $femalePeople++;
        }

        if(defined($attribs_ref->{'mood'}))
        {
          $moodHash{$attribs_ref->{'mood'}->{'value'}} = 1;
        }

        if(defined($attribs_ref->{'smiling'}) && $attribs_ref->{'smiling'}->{'value'}=~/true/)
        {
          $smilingPeople++;
        }

        if(defined($attribs_ref->{'glasses'}) && $attribs_ref->{'glasses'}->{'value'}=~/true/)
        {
          $glassesPeople++;
        }
      }

      for my $key(keys %moodHash)
      {
        $moods.=$key.",";
      }
      $moods=~s/,$//si;
      $totalString=~s/,$//si;

      $totalString .= ". Detected $totalPeople people. $malePeople of them are male and $femalePeople of them  are female. $glassesPeople people are wearing glasses and $smilingPeople people are smiling. Detected moods are $moods\n";
      #print Dumper(\@uids);

#      print STDERR $totalString,"\n";

      #  print Dumper(\$attributes_ref);
    }
  }

  return $totalString;
}
