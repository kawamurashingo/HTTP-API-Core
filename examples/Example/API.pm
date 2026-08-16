package Example::API;

use strict;
use warnings;
use parent 'HTTP::API::Core';

sub users {
    my ($self, %args) = @_;
    return $self->get(
        '/users',
        query => {
            active => $args{active},
            limit  => $args{limit},
        },
    );
}

sub user {
    my ($self, $id) = @_;
    die "user id is required\n" if !defined($id) || $id eq '';
    return $self->get('/users/' . $id);
}

sub create_user {
    my ($self, $user) = @_;
    return $self->post('/users', json => $user);
}

sub users_pager {
    my ($self, %args) = @_;
    return $self->paginate(
        '/users',
        mode  => 'cursor',
        items => 'data.users',
        next  => 'meta.next_cursor',
        query => { limit => $args{limit} || 100 },
    );
}

1;
