#! /usr/bin/perl -w

print "Content-type: text/html\n\n";

print<< "TOP";
<html>
<head><title>cgi test</title><head>
<body>
<h2>Env variables as seen by httpd</h2>
TOP

foreach $key (sort keys %ENV) {
	print "$key: $ENV{$key}<br>\n";
}
print "</body></html>\n";
