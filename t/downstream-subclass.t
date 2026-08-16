use strict;
use warnings;
use Test::More;

use lib 'examples';
use Example::API;

my @calls;
my $api = Example::API->new(
    base_url => 'https://api.example.test',
    transport => sub {
        my ($method, $url, $opts) = @_;
        push @calls, [$method, $url, $opts];

        if ($url =~ m{/users\?}) {
            return {
                status => 200,
                headers => { 'Content-Type' => 'application/json' },
                content => '{"data":{"users":[{"id":1}]},"meta":{"next_cursor":null}}',
            };
        }

        if ($method eq 'POST') {
            return {
                status => 201,
                headers => { 'Content-Type' => 'application/json' },
                content => '{"id":2}',
            };
        }

        return {
            status => 200,
            headers => { 'Content-Type' => 'application/json' },
            content => '{"id":1}',
        };
    },
);

isa_ok $api, 'Example::API';
isa_ok $api, 'HTTP::API::Core';

my $users = $api->users(active => 1, limit => 25);
is_deeply $users->json->{data}{users}, [{ id => 1 }], 'subclass endpoint returns normalized response';
like $calls[0][1], qr{/users\?}, 'subclass endpoint uses inherited request construction';
like $calls[0][1], qr/(?:[?&])active=1(?:&|$)/, 'subclass endpoint forwards query options';
like $calls[0][1], qr/(?:[?&])limit=25(?:&|$)/, 'subclass endpoint forwards query limit';

my $user = $api->user(1);
is $user->json->{id}, 1, 'subclass can expose resource helpers';

my $created = $api->create_user({ name => 'Ada' });
is $created->status, 201, 'subclass can expose JSON POST helpers';
is $calls[-1][0], 'POST', 'POST method reaches transport';
like $calls[-1][2]{content}, qr/Ada/, 'JSON body reaches transport';

my $pager = $api->users_pager(limit => 10);
isa_ok $pager, 'HTTP::API::Core::Pagination';
my @paged = $pager->all;
is_deeply \@paged, [{ id => 1 }], 'subclass can expose inherited pagination';

my $ok = eval { $api->user(''); 1 };
ok !$ok, 'API-specific validation remains in subclass';
like $@, qr/user id is required/, 'subclass owns service-specific validation';

done_testing;
