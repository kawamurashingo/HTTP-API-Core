package HTTP::API::Core::Example::GitLab;

use strict;
use warnings;

use HTTP::API::Core;
use HTTP::API::Core::Auth qw(api_key_header);

sub new {
    my ($class, %args) = @_;
    my $token = delete $args{token};
    die "token is required\n" if !defined($token) || $token eq '';

    my $api = HTTP::API::Core->new(
        base_url => delete($args{base_url}) || 'https://gitlab.com/api/v4',
        hooks => { before_request => api_key_header('PRIVATE-TOKEN', $token) },
        %args,
    );
    return bless { api => $api }, $class;
}

sub projects_pager {
    my ($self, %query) = @_;
    return $self->{api}->paginate(
        '/projects',
        mode => 'page',
        items => sub { $_[0] },
        page_param => 'page',
        per_page_param => 'per_page',
        query => \%query,
    );
}

1;
