package Groonga::Console;

use 5.012004;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Groonga::Console ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(

) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(

);

our $VERSION = '0.11';

require XSLoader;
XSLoader::load('Groonga::Console', $VERSION);

# Preloaded methods go here.

sub file {
    my $self = shift;
    my ( $path ) = @_;

    local $/ = '';
    local *FH;
    unless( open( FH, $path ) ) {
        return $self->add_error( "Failure to open file '$file': $!" );
    }

    my $content = <FH>;
    unless ( close(FH) ) {
        return $self->add_error( "Failure to close file '$file': $!" );
    }

    $self->console($content);
}

1;
__END__
=head1 NAME

Groonga::Console - Simple Perl binding to access Groonga console.

=head1 SYNOPSIS

  use Groonga::Console;

  # Open or create groonga database with a new context.
  my $groonga = Groonga::Console->new("path/to/groonga/db");

  # Returns the last error within the package scope.
  my $last_error = Groonga::Console::last_error;

  # Returnes the first of line outputted.
  my $result = $groonga->console("select --table Table");

  # @results has each results. But the order may not match with input.
  # @results is just lines console outputted.
  my @results = $groonga->console("COMMAND1", "COMMAND2");

  # Read commands from file.
  my @results = $groonga->file("path/to/file");

  # Getting the context errors and clear them.
  my @errors = $groonga->errors;
  $groonga->clear_errors;

=head1 DESCRIPTION

You can execute any command like a console.

Use other libraries to parse JSON.

=head2 EXPORT

None by default.

=head1 SEE ALSO

Groonga http://groonga.org/

=head1 AUTHOR

Kunihiko Miyanaga, E<lt>miyanaga@ideamans.com<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.12.4 or,
at your option, any later version of Perl 5 you may have available.

=cut
