package Psh::Builtins::Help;

sub get_pod_from_file {
	my $tmpfile= shift;
	my $arg= shift;
	my $tmp='';
	if( -r $tmpfile) {
		open(FILE, "< $tmpfile");
		my $add=0;
		while(<FILE>) {
			if( !$add && /\=item \* C\<$arg/) {
				$tmp="\n".$_;
				$add=1;
			} elsif( $add) {
				$tmp.=$_;
			}
			if( $add && $_ =~ /\=cut/) {
				$add=0;
				last;
			}
		}
		close(FILE);
	}
	return $tmp;
}

=item * C<help [COMMAND]>

If COMMAND is specified, print out help on it; otherwise print out a list of 
B<psh> builtins.

=cut

sub bi_help
{
	my $arg= shift;
	if( $arg) {
		my $tmp= eval '$Psh::Builtins::help_'.$arg;
		if( !$tmp) {
			my $tmpfile;
			foreach my $line (@INC) {
				$tmpfile= File::Spec->catfile(
						File::Spec->catdir($line,'Psh'),'Builtins.pm');
				$tmp= get_pod_from_file($tmpfile,$arg);
				last if $tmp;
				$tmpfile= File::Spec->catfile(
						File::Spec->catdir($line,'Psh','Builtins'),ucfirst($arg).'.pm');
				$tmp= get_pod_from_file($tmpfile,$arg);
				last if $tmp;
				$tmpfile= File::Spec->catfile(
						File::Spec->catdir($line,'Psh','Builtins','Fallback'),ucfirst($arg).'.pm');
				$tmp= get_pod_from_file($tmpfile,$arg);
				last if $tmp;
			}
		}
		if( $tmp ) {
			Psh::OS::display_pod("=over 4\n".$tmp."\n=back\n");
		} else {
			Psh::Util::print_error_i18n('no_help',$arg);
		}
	} else {
		Psh::Util::print_out_i18n('help_header');
		Psh::Util::print_list(Psh::Builtins::get_builtin_commands());
	}
    return undef;
}

sub cmpl_help {
	my $text= shift;
	return (1,grep { Psh::Util::starts_with($_,$text) } Psh::Builtins::get_builtin_commands());
}

1;
