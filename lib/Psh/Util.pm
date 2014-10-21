package Psh::Util;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

use Cwd;
use Config;
use Psh::OS;
use File::Spec;

require Exporter;

$VERSION = do { my @r = (q$Revision: 1.26 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; # must be all one line, for MakeMaker

@ISA= qw(Exporter);

@EXPORT= qw( );
@EXPORT_OK= qw( starts_with ends_with print_list);
%EXPORT_TAGS = ( all => [qw(print_warning print_debug print_debug_class
							print_warning_i18n print_error
							print_out print_error_i18n print_out_i18n
							which abs_path)] );

Exporter::export_ok_tags('all'); # Add EXPORT_TAGS to EXPORT_OK

sub print_warning
{
	print STDERR @_;
}

#
# Print unclassified debug output
#
sub print_debug
{
	print STDERR @_ if $Psh::debugging && $Psh::debugging =~ /o/;
}

#
# Print classified debug output
#
sub print_debug_class
{
	my $class= shift;
	print STDERR @_ if $Psh::debugging =~ /$class/ ||
	  $Psh::debugging==1;
}

sub print_error
{
	print STDERR @_;
}

#
# print_i18n( stream, key, args)
# print_out_i18n( key, args)
# print_error_i18n( key, args)
#
# The print..._i18n suite of functions will fetch the
# text from the %text hash, replace %1 with the first arg,
# %2 with the second and so on and then print it out
#

sub _print_i18n
{
	my( $stream, $text, @rest) = @_;
	$text= $Psh::text{$text} || '';
	# This was looping over 0 and 1 and replacing %0 and %1
	for( my $i=1; $i<=@rest; $i++)
	{
		$text=~ s/\%$i/$rest[$i-1]/g; # removed o from flags huggie
	}
	print $stream $text;
}


sub print_error_i18n
{
	_print_i18n(*STDERR,@_);
}

sub print_warning_i18n
{
	_print_i18n(*STDERR,@_);
}

sub print_out_i18n
{
	_print_i18n(*STDOUT,@_);
}

sub print_out
{
	print STDOUT @_;
}

# Copied from readline.pl - pretty prints a list in columns
sub print_list
{
	my @list= @_;
    return unless @list;
    my ($lines, $columns, $mark, $index);

    ## find width of widest entry
    my $maxwidth = 0;
	my $screen_width=$ENV{COLUMNS};
    grep(length > $maxwidth && ($maxwidth = length), @list);
    $maxwidth++;

    $columns = $maxwidth >= $screen_width?1:int($screen_width / $maxwidth);

    ## if there's enough margin to interspurse among the columns, do so.
    $maxwidth += int(($screen_width % $maxwidth) / $columns);

    $lines = int((@list + $columns - 1) / $columns);
    $columns-- while ((($lines * $columns) - @list + 1) > $lines);

    $mark = $#list - $lines;
    for (my $l = 0; $l < $lines; $l++) {
        for ($index = $l; $index <= $mark; $index += $lines) {
            print_out(sprintf("%-$ {maxwidth}s", $list[$index]));
        }
        print_out($list[$index]) if $index <= $#list;
        print_out("\n");
    }
}

{
	my $abs_path;

	sub basic_abs_path {
		my $dir = shift;
		$dir = '~' unless defined $dir and $dir ne '';
		if ($dir =~ m|^(~([a-zA-Z0-9-]*))(.*)$|) {
			my $user = $2;
			my $rest = $3;
			my $home;

			$home= Psh::OS::get_home_dir($user);
			if ($home) { $dir = "$home$rest"; } # If user's home not found, leave it alone.
		}

		if( !File::Spec->file_name_is_absolute($dir)) {
			$dir = File::Spec->catdir($ENV{PWD},$dir);
		}
		return $dir;
	};

	#
	# string abs_path(string DIRECTORY)
	#
	# expands the argument DIRECTORY into a full, absolute pathname.
	#

	eval "use Cwd 'fast_abs_path';";
	if ($@) {
		$abs_path=\&basic_abs_path;
	} else {
		$abs_path=\&fast_abs_path;
	}

	sub abs_path {
		my $dir= shift;
		my $dir2= Psh::OS::abs_path($dir);
		unless ($dir2) {
			eval {
				$dir2= &$abs_path($dir);
			};
			$dir2= basic_abs_path($dir) if $@;
			$dir2.='/' unless $dir2=~m:[/\\]:; # abs_path strips / from letter: on Win
		}
		return $dir2;
	}
}

#
# string which(string FILENAME)
#
# search for an occurrence of FILENAME in the current path as given by 
# $ENV{PATH}. Return the absolute filename if found, or undef if not.
#

{
	#
	# "static variables" for which() :
	#

	my $last_path_cwd = '';
	my %hashed_cmd    = ();
	my $FS=$Psh::OS::FILE_SEPARATOR;

	my $re1="\Q$FS\E";
	my $re2="^(.*)\Q$FS\E([^\Q$FS\E]+)\$";

	if ($]>=5.005) {
		eval {
			$re1= qr{$re1};
			$re2= qr{$re2};
		}
	}

	sub which
    {
		my $cmd      = shift;

		if ($cmd =~ m|$re1|o) {
			$cmd =~ m|$re2|o;
			my $path_element= $1;
			my $cmd_element= $2||'';
			my $try = Psh::Util::abs_path($path_element).$FS.$cmd_element;
			if ((-x $try) and (! -d _)) { return $try; }
			return undef;
		}

		# Only search for names which match a given regexp
		if ($cmd !~ m/$Psh::which_regexp/) { return undef; }

		if ($last_path_cwd ne ($ENV{PATH} . $ENV{PWD})) {
			$last_path_cwd = $ENV{PATH} . $ENV{PWD};
			@Psh::absed_path    = ();
			%hashed_cmd    = ();

			my @path = split($Psh::OS::PATH_SEPARATOR, $ENV{PATH});

			eval {
				foreach my $dir (@path) {
					push @Psh::absed_path, Psh::Util::abs_path($dir);
				}
			};
			# Without the eval Psh might crash if the directory
			# does not exist
		}

		if (exists($hashed_cmd{$cmd})) { return $hashed_cmd{$cmd}; }

		my @path_extension=Psh::OS::get_path_extension();

		foreach my $dir (@Psh::absed_path) {
			my $try = File::Spec->catfile($dir,$cmd);
			foreach my $ext (@path_extension) {
				if ((-x $try.$ext) and (!-d _)) { 
					$hashed_cmd{$cmd} = $try.$ext;
					return $try.$ext;
				}
			}
		}
		$hashed_cmd{$cmd} = undef;

		return undef;
	}
}

#
# starts_with( text, prefix)
# Returns true if text starts with prefix
#

sub starts_with {
	my ($text, $prefix) = @_;

	return length($text)>=length($prefix) &&
		substr($text,0,length($prefix)) eq $prefix;
}

#
# ends_with( text, suffix)
# Returns true if text ends with suffix
#

sub ends_with {
	my ( $text, $suffix) = @_;

	return length($text)>=length($suffix) &&
		substr($text,-length($suffix)) eq $suffix;
}

#
# list parse_hosts_file( text)
# 
# Gets a standard hosts file as input and returns
# a list of the hostnames mentioned in the file
#
sub parse_hosts_file {
	my $text= shift;
	my @lines= split( /\n|\r|\r\n/, $text);
	my @result= ();
	foreach my $line (@lines) {
		next if $line=~/^\s*$/;   # Skip blank lines
		next if $line=~/^\s*\#/;  # Skip comment lines
		$line=~/^\s*\S+\s(.*)$/;
		my $rest= $1;
		push @result, grep { length($_)>0 } split( /\s/, $rest);
	}
	return @result;
}

#
# char prompt( string allowedchars, string prompt)
# prompts the user until he answers with one of the
# allowed characters
#
sub prompt {
	my $allowed= shift;
	$allowed= "^[$allowed]\$";
	my $text= shift;
	my $line='';

	do {
		print $text;
		$line=<STDIN>;
	} while (!$line || lc($line) !~ $allowed);
	chomp $line;
	return lc($line);
}


1;

__END__

=head1 NAME

Psh::Utils - Containing certain Psh utility functions

=head1 SYNOPSIS

  use Psh::Utils (:all);

=head1 DESCRIPTION

TBD


=head1 AUTHOR

blaaa

=head1 SEE ALSO

=cut

# The following is for Emacs - I hope it won't annoy anyone
# but this could solve the problems with different tab widths etc
#
# Local Variables:
# tab-width:4
# indent-tabs-mode:t
# c-basic-offset:4
# perl-indent-level:4
# End:


