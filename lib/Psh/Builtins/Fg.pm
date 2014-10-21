package Psh::Builtins::Fg;

use Psh::Util ':all';

=item * C<fg [%JOB|COMMAND]>

Bring a job into the foreground. If JOB is omitted, uses the
highest-numbered stopped job, or, failing that, the highest-numbered job.
JOB may either be a job number or a command. If you specify a command
it will launch a new program (this is for consisteny with the bg command)

=cut

sub bi_fg
{
	my $arg = shift;

	if( ! Psh::OS::has_job_control()) {
		print_error_i18n('no_jobcontrol');
		return undef;
	}

	if (!defined($arg) || $arg eq '') {
		($arg)= $Psh::joblist->find_job();
	} else {
		if( $arg !~ /^\%/) {
			Psh::evl($arg.' &');
			return undef;
		}
		$arg =~ s/\%//;

		if ( $arg !~ /^\d+$/) {
			($arg)= $Psh::joblist->find_last_with_name($arg,0);
		}
		$arg-- if defined($arg);
	}
	return undef unless defined($arg);

	Psh::OS::restart_job(1, $arg );

	return undef;
}

1;
