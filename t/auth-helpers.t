use strict; use warnings; use Test::More; use MIME::Base64 qw(encode_base64); use HTTP::API::Core; use HTTP::API::Core::Auth qw(bearer_auth basic_auth api_key_auth);
sub capture_client { my($hook)=@_; my @seen; my $api=HTTP::API::Core->new(base_url=>'https://api.example.test',hooks=>{before_request=>$hook},transport=>sub{my($method,$url,$opts)=@_; push @seen,[$method,$url,$opts]; return {status=>200,reason=>'OK',headers=>{},content=>'{}'};}); return($api,\@seen); }
{my($api,$seen)=capture_client(bearer_auth('secret-token')); $api->get('/users'); is $seen->[0][2]{headers}{Authorization},'Bearer secret-token','bearer';}
{my($api,$seen)=capture_client(basic_auth('alice','s3cret')); $api->get('/users'); is $seen->[0][2]{headers}{Authorization},'Basic '.encode_base64('alice:s3cret',''),'basic';}
{my($api,$seen)=capture_client(api_key_auth(name=>'X-API-Key',value=>'key-123')); $api->get('/users'); is $seen->[0][2]{headers}{'X-API-Key'},'key-123','api key header';}
{my($api,$seen)=capture_client(api_key_auth(in=>'query',name=>'api_key',value=>'key 123')); $api->get('/users',query=>{page=>2}); like $seen->[0][1],qr/[?&]api_key=key%20123(?:&|$)/,'query key';}
{my($api,$seen)=capture_client(bearer_auth('default-token')); $api->get('/users',headers=>{authorization=>'Explicit value'}); is $seen->[0][2]{headers}{authorization},'Explicit value','explicit wins'; ok !exists $seen->[0][2]{headers}{Authorization},'no duplicate';}
for my $case ([sub{bearer_auth('')},qr/non-empty/],[sub{basic_auth('user',undef)},qr/password is required/],[sub{api_key_auth(in=>'cookie',name=>'x',value=>'y')},qr/header or query/],[sub{api_key_auth(name=>'',value=>'y')},qr/non-empty/]) { my($b,$re)=@$case; my $ok=eval{$b->();1}; ok !$ok,'invalid rejected'; like $@,$re,'descriptive'; }
done_testing;
