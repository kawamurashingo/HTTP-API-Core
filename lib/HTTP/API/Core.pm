package HTTP::API::Core;

use strict;
use warnings;
use HTTP::Tiny;
use JSON::PP qw(encode_json);
use Scalar::Util qw(blessed);
use Time::HiRes qw(sleep time);

use HTTP::API::Core::Response;
use HTTP::API::Core::Error;
use HTTP::API::Core::Pagination;

our $VERSION = '0.01';

sub new {
    my ($class, %args) = @_;
    my $base_url = delete $args{base_url};
    die "base_url is required\n" if !defined($base_url) || $base_url eq '';
    $base_url =~ s{/+\z}{};
    my $headers = delete($args{headers}) || {};
    die "headers must be a hash reference\n" if ref($headers) ne 'HASH';
    my $timeout = exists $args{timeout} ? delete($args{timeout}) : 10;
    die "timeout must be a positive number\n" if !defined($timeout) || $timeout !~ /\A(?:\d+(?:\.\d*)?|\.\d+)\z/ || $timeout <= 0;
    my $transport = delete $args{transport};
    die "transport must be a code reference or object with request()\n" if defined($transport) && ref($transport) ne 'CODE' && !(blessed($transport) && $transport->can('request'));
    my $retry = exists $args{retry} ? delete($args{retry}) : {};
    die "retry must be a hash reference\n" if ref($retry) ne 'HASH';
    $retry = _normalize_retry($retry);
    my $hooks = exists $args{hooks} ? delete($args{hooks}) : {};
    $hooks = _normalize_hooks($hooks);
    die "unknown constructor option: $_\n" for sort keys %args;
    my $self = bless { base_url=>$base_url, headers=>{%$headers}, timeout=>$timeout, transport=>$transport, retry=>$retry, hooks=>$hooks }, $class;
    $self->{http} = HTTP::Tiny->new(timeout => $timeout) if !$transport;
    return $self;
}
sub base_url{$_[0]{base_url}} sub timeout{$_[0]{timeout}} sub retry{+{%{$_[0]{retry}},methods=>[@{$_[0]{retry}{methods}}]}} sub hooks{_clone_hooks($_[0]{hooks})}
sub get{my($s,$p,%o)=@_;$s->request('GET',$p,%o)} sub post{my($s,$p,%o)=@_;$s->request('POST',$p,%o)} sub put{my($s,$p,%o)=@_;$s->request('PUT',$p,%o)} sub patch{my($s,$p,%o)=@_;$s->request('PATCH',$p,%o)} sub delete{my($s,$p,%o)=@_;$s->request('DELETE',$p,%o)}
sub paginate{my($s,$p,%o)=@_;HTTP::API::Core::Pagination->new(client=>$s,path=>$p,%o)}
sub request{
    my($self,$method,$path,%opts)=@_;$method=uc($method//'');die "method is required\n" if $method eq'';die "path is required\n" if !defined$path;
    my$url=$path=~m{\Ahttps?://}?$path:$self->_join_url($path);
    my$query=exists$opts{query}?delete($opts{query}):{};die "query must be a hash reference\n" if ref($query) ne'HASH';$url=_append_query($url,$query);
    my%headers=(%{$self->{headers}},%{delete($opts{headers})||{}});
    if(exists$opts{idempotency}){my$id=delete$opts{idempotency};die "idempotency must be a hash reference\n" if ref($id) ne'HASH';my%c=%$id;my$key=delete$c{key};my$header=delete$c{header};die "idempotency key must be a non-empty scalar\n" if !defined($key)||ref($key)||$key eq'';die "idempotency header must be a non-empty scalar\n" if !defined($header)||ref($header)||$header eq'';die "unknown idempotency option: $_\n" for sort keys%c;my$wanted=lc$header;my$already=grep{lc($_) eq$wanted}keys%headers;$headers{$header}="$key" if !$already}
    my$content;if(exists$opts{json}){my$value=delete$opts{json};$content=eval{encode_json($value)};if($@){die HTTP::API::Core::Error->new(category=>'encode',method=>$method,url=>$url,message=>"failed to encode JSON request: $@")} $headers{'content-type'}||='application/json';$headers{'accept'}||='application/json'}elsif(exists$opts{content}){$content=delete$opts{content}}
    my$retry=exists$opts{retry}?delete($opts{retry}):$self->{retry};if(ref($retry) eq'HASH'&&$retry!=$self->{retry}){$retry=_normalize_retry($retry)}elsif(!ref($retry)){$retry=$retry?$self->{retry}:_normalize_retry({attempts=>1})}
    my$request_hooks=exists$opts{hooks}?_normalize_hooks(delete$opts{hooks}):{};my$hooks=_merge_hooks($self->{hooks},$request_hooks);die "unknown request option: $_\n" for sort keys%opts;
    my$attempts=_method_is_retryable($method,$retry)?$retry->{attempts}:1;my$attempt=0;
    while(++$attempt<=$attempts){my$ctx={method=>$method,url=>$url,headers=>{%headers},content=>$content,attempt=>$attempt};my$he=_run_hooks($hooks->{before_request},$ctx);die _hook_error($he,$method,$url) if$he;$ctx->{started_at}=time;my($res,$err,$elapsed)=$self->_request_once($ctx->{method},$ctx->{url},$ctx->{headers},$ctx->{content});$ctx->{elapsed}=$elapsed;$ctx->{request_id}=$res?$res->request_id:$err?$err->request_id:undef;if($res){my$ae=_run_hooks($hooks->{after_response},$res,$ctx);die _hook_error($ae,$ctx->{method},$ctx->{url}) if$ae;return$res}my$oe=_run_hooks($hooks->{on_error},$err,$ctx);die _hook_error($oe,$ctx->{method},$ctx->{url}) if$oe;die$err if$attempt>=$attempts||!$err->retryable;my$d=_retry_delay($retry,$attempt,$err);sleep($d) if$d>0}
    die "unreachable retry state\n";
}
sub _request_once{
    my($self,$method,$url,$headers,$content)=@_;my$raw;my$started=time;
    eval{if($self->{transport}){my$o={headers=>$headers,(defined($content)?(content=>$content):())};$raw=ref($self->{transport}) eq'CODE'?$self->{transport}->($method,$url,$o):$self->{transport}->request($method,$url,$o)}else{$raw=$self->{http}->request($method,$url,{headers=>$headers,(defined($content)?(content=>$content):())})}1}or do{my$cause=$@;return(undef,$cause,time-$started) if blessed($cause)&&$cause->isa('HTTP::API::Core::Error');my$e=time-$started;return(undef,HTTP::API::Core::Error->new(category=>'transport',method=>$method,url=>$url,retryable=>1,elapsed=>$e,message=>"HTTP transport failed: $cause"),$e)};
    if(ref($raw) ne'HASH'||!exists$raw->{status}){my$e=time-$started;return(undef,HTTP::API::Core::Error->new(category=>'transport',method=>$method,url=>$url,retryable=>1,elapsed=>$e,message=>'HTTP transport returned an invalid response'),$e)}
    my$elapsed=time-$started;my$response=HTTP::API::Core::Response->new(status=>0+$raw->{status},reason=>$raw->{reason},headers=>$raw->{headers}||{},content=>defined($raw->{content})?$raw->{content}:'',method=>$method,url=>$url,elapsed=>$elapsed);return($response,undef,$elapsed) if$response->is_success;my$rl=$response->rate_limit;my$limited=($response->status==403||$response->status==429)&&$rl->exhausted;return(undef,HTTP::API::Core::Error->new(category=>'http',status=>$response->status,method=>$method,url=>$url,retryable=>_retryable_status($response->status)||$limited,retry_after=>$response->header('retry-after'),request_id=>$response->request_id,elapsed=>$elapsed,response=>$response,message=>sprintf('HTTP %d%s',$response->status,defined($response->reason)&&length($response->reason)?' '.$response->reason:'')),$elapsed)
}
sub _normalize_hooks{my($h)=@_;$h={} if !defined$h;die "hooks must be a hash reference\n" if ref($h) ne'HASH';my%c=%$h;my%n;for my$name(qw(before_request after_response on_error)){my$v=delete$c{$name};next if !defined$v;my@cb=ref($v) eq'ARRAY'?@$v:($v);die "hook $name must be a code reference or array reference of code references\n" if grep{ref($_) ne'CODE'}@cb;$n{$name}=\@cb}die "unknown hook: $_\n" for sort keys%c;\%n}
sub _clone_hooks{my($h)=@_;+{map{$_=>[@{$h->{$_}||[]}]}qw(before_request after_response on_error)}}
sub _merge_hooks{my($a,$b)=@_;+{map{$_=>[@{$a->{$_}||[]},@{$b->{$_}||[]}]}qw(before_request after_response on_error)}}
sub _run_hooks{my($c,@a)=@_;for my$cb(@{$c||[]}){my$ok=eval{$cb->(@a);1};return$@ if !$ok}undef}
sub _hook_error{my($cause,$method,$url)=@_;return$cause if blessed($cause)&&$cause->isa('HTTP::API::Core::Error');HTTP::API::Core::Error->new(category=>'hook',method=>$method,url=>$url,retryable=>0,message=>"HTTP API core hook failed: $cause")}
sub _normalize_retry{my($r)=@_;my%c=%$r;my$a=exists$c{attempts}?delete$c{attempts}:3;die "retry attempts must be a positive integer\n" if$a!~/\A\d+\z/||$a<1;my$b=exists$c{base_delay}?delete$c{base_delay}:0.25;die "retry base_delay must be a non-negative number\n" if!_non_negative_number($b);my$m=exists$c{max_delay}?delete$c{max_delay}:5;die "retry max_delay must be a non-negative number\n" if!_non_negative_number($m);my$j=exists$c{jitter}?delete$c{jitter}:1;$j=$j?1:0;my$methods=exists$c{methods}?delete$c{methods}:[qw(GET HEAD PUT DELETE OPTIONS)];die "retry methods must be an array reference\n" if ref($methods) ne'ARRAY';my@methods=map{uc($_//'')}@$methods;die "retry methods must not contain empty values\n" if grep{$_ eq''}@methods;die "unknown retry option: $_\n" for sort keys%c;{attempts=>0+$a,base_delay=>0+$b,max_delay=>0+$m,jitter=>$j,methods=>\@methods}}
sub _method_is_retryable{my($m,$r)=@_;my%a=map{$_=>1}@{$r->{methods}};$a{$m}?1:0}
sub _retry_delay{my($r,$a,$e)=@_;my$ra=$e->retry_after;return 0+$ra if defined($ra)&&$ra=~/\A(?:\d+(?:\.\d*)?|\.\d+)\z/;my$rl=$e->rate_limit;if($rl&&$rl->exhausted){my$w=$rl->wait_seconds;return$w if defined$w}my$d=$r->{base_delay}*(2**($a-1));$d=$r->{max_delay} if$d>$r->{max_delay};$d=rand($d) if$r->{jitter}&&$d>0;$d}
sub _append_query{my($url,$q)=@_;my@pairs;for my$key(sort keys%$q){my$v=$q->{$key};next if !defined$v;my@values;if(ref($v) eq'ARRAY'){@values=grep{defined$_}@$v}elsif(ref($v)){die "query values must be scalars, array references, or undef\n"}else{@values=($v)}push@pairs,map{_uri_escape($key).'='._uri_escape($_)}@values}return$url if !@pairs;my$f='';if($url=~s/(#.*)\z//){$f=$1}my$sep=index($url,'?')>=0?'&':'?';$sep='' if$url=~/[?&]\z/;$url.$sep.join('&',@pairs).$f}
sub _uri_escape{my($v)=@_;my$b="$v";utf8::encode($b) if utf8::is_utf8($b);$b=~s/([^A-Za-z0-9\-._~])/sprintf('%%%02X',ord($1))/ge;$b}
sub _retryable_status{my($s)=@_;return 1 if$s==408||$s==425||$s==429;return 1 if$s>=500&&$s<=599;0}
sub _non_negative_number{my($v)=@_;defined($v)&&$v=~/\A(?:\d+(?:\.\d*)?|\.\d+)\z/&&$v>=0}
sub _join_url{my($self,$path)=@_;return$self->{base_url} if$path eq'';$self->{base_url}.($path=~m{\A/}?$path:"/$path")}
1;
