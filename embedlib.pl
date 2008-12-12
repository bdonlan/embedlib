#!/usr/bin/perl
use strict;
use warnings;

use Getopt::Long;
use File::Spec::Functions qw/rel2abs splitpath/;
use File::Path;
use File::Temp qw/tempdir/;
use File::Copy;

Getopt::Long::Configure("gnu_getopt");

sub usage {
	print STDERR <<END;
Usage: $0 [options] files ...
Pack some files into a library usable from C

  --prefix=PREFIX           Prefix symbols with this string
  --output=libfoo.[so|a]    The static or dynamic library to produce
  --header=foo.h            The header file to create
  --templatedir=...         The location of our template files
  --cc=gcc                  The path to your gcc
  --ld=ld                   The path to your ld
  --align=N                 Align all files to N bytes (where N is a power
                            of two)
  --static                  Produce a static library (has bugs)
  --help                    What you're reading now

Report bugs to <bdonlan\@gmail.com>
END
	exit 1;
}

my $tempdir;

END {
	if (defined $tempdir) {
		rmtree($tempdir);
	}
}

my $prefix = "earc_";
my $output = undef;
my $header = "earc.h";
my $template = ".";
my $cc = 'gcc';
my $ld = 'ld';
my $align = 8;
my @cargs;
my $static = 0;

sub subst_file_into {
	my ($src, $dest) = @_;
	open my $in, "<", $src or die "Can't open $src for read: $!";
	open my $out, ">", $dest or die "Can't open $dest for write: $!";

	my $headermangle = $header;
	$headermangle =~ s/[^A-Za-z0-9]/_/g;

	while (<$in>) {
		s/##HEADERNAME##/$headermangle/g;
		s/##PREFIX##/$prefix/g;
		print $out $_;
	}
	close $out;
	close $in;
}

my $result = GetOptions(
	"prefix=s" => \$prefix,
	"output=s" => \$output,
	"header=s" => \$header,
	"templatedir=s" => \$template,
	"cc=s" => \$cc,
	"ld=s" => \$ld,
	"align=i" => \$align,
	"static" => \$static,
	"help" => \&usage
);
usage() unless $result;

if (!defined $output) {
	$output = $static ? "libearc.a" : "libearc.so";
}

$output = rel2abs $output;
$header = rel2abs $header;
$template = rel2abs $template;

my %fhash = map { ( (splitpath($_))[2], rel2abs $_ ) } @ARGV;
my @files = sort keys %fhash;
my %fsym;
my $fidx = 0;

$tempdir = tempdir();
chdir $tempdir;
open my $asmscript, ">", "inc.s" or die "can't open temp file for writing: $!";

print $asmscript <<END;
	.section ".embedded_data", "a", \@progbits
	.globl mbed_data_start
	.globl mbed_data_end
	.p2align 3
mbed_data_start:
END

for my $fname (@files) {
	my $idx;
	$idx = $fidx++;
	my $sym = "mbed_f_$idx";
	die "Duplicate file $fname" if exists $fsym{$fname};
	$fsym{$fname} = $sym;
	
	print $asmscript "\t.globl $sym\n";
	print $asmscript "\t.globl $sym"."_end\n";
	print $asmscript "\t.balign $align\n";
	print $asmscript "$sym:\n";
	my $qname = quotemeta $fhash{$fname};
	print $asmscript qq{\t.incbin "$qname"\n};
	print $asmscript "$sym"."_end:\n";
}

print $asmscript <<END;
	.balign 4096
mbed_data_end:
	.byte 0
	.section .note.GNU-stack,"",\@progbits
END

close $asmscript;

open my $index, ">", "index.c" or die "cannot open temp file: $!";
print $index <<END;
struct ient {
	const char *filename;
	const void *start, *end;
};
END

for my $fname (@files) {
	print $index "extern char ", $fsym{$fname}, ", ", $fsym{$fname}, "_end;\n";
}

print $index "const struct ient mbed_index[] = {\n";

for my $fname (@files) {
	print $index "\t{ \"", $fname, "\", &", $fsym{$fname}, ", &",
		$fsym{$fname}, "_end }, \n";
}

print $index <<END;
	{ 0, 0, 0 }
};
END

print $index "const int mbed_index_ct = ", scalar(@files), ";\n";
close $index;

unless ($static) {
	unshift @cargs,
		'-fPIC';
}

unshift @cargs,
	'-DMBED_PREFIX='.$prefix,
	'-O2',
	'--std=gnu99';

## XXX - The '-x' option to ld does not seem to drop local symbols in the case
##       of partial (incremental) linking. This means we'll pollute the global
##       namespace with mbed_* symbols when linked in. While it's possible
##       to replace the mbed_ prefix with the user prefix, this would require
##       more preprocessor work than I'd prefer...
my @ldargs = ('--version-script', "$template/linkscript.lds", '-x');

for my $f ('inc.s', 'index.c', "$template/stub.c") {
	my $in = $f;
	my $out = $in;
	$out =~ s{^(?:.*/)?([^\.\\]+)\..*$}{$1.o};

	print "$in -> $out\n";
	system($cc, @cargs, '-c', '-o', $out, $in);
	if ($? >> 8 != 0) {
		die "gcc invocation failed: ".($? >> 8);
	}
}

## Do a partial link to hide our internal symbols in the static library case
system($ld, '-r', @ldargs, '-o', 'intermed.o',
	'inc.o', 'index.o', 'stub.o');

my $outtmp;
if ($static) {
	$outtmp = "out.a";
	system("ar", "-r", $outtmp, "intermed.o");
	if ($? >> 8 != 0) {
		die "ar invocation failed: ".($? >> 8);
	}
	system("ranlib", $outtmp);
	if ($? >> 8 != 0) {
		die "ranlib invocation failed: ".($? >> 8);
	}
} else {
	$outtmp = 'out.so';
	system($cc, @cargs, '-shared', '-o', $outtmp, 'intermed.o');
}

subst_file_into("$template/stub.h", $header) if defined $header;
copy($outtmp, $output);
exit 0;
