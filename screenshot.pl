#!/usr/bin/perl
use strict;
use warnings;
use WWW::Selenium;
use Image::Magick;

my $sel = WWW::Selenium->new( host => "localhost", 
                              port => 4444, 
                              browser => "*firefox", 
                              browser_url => "",
                            );

$sel->start;
$sel->open("justin.html");
sleep(15);

my $path = "/var/www/images/";

while(1)
{

    my $curTime = time();

    my $file = $path.$curTime.".png";

    $sel->capture_entire_page_screenshot($file);
    my($image, $x);

    $image = Image::Magick->new;
    $x = $image->Read($file);
    warn "$x" if "$x";

    $x = $image->Crop(geometry=>'480x340');
    warn "$x" if "$x";

    $x = $image->Write($file);
    warn "$x" if "$x";
    sleep(8);
}
$sel->close;

