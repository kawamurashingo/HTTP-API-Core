package HTTP::API::Core::Auth;
use strict;use warnings;use Exporter 'import';use MIME::Base64 qw(encode_base64);our @EXPORT_OK=qw(bearer_auth basic_auth api_key_auth);
sub bearer_auth{my($t)=@_;die "bearer token must be a non-empty scalar\n" if !defined($t)||ref($t)||$t eq'';sub{my($c)=@_;_set_header_if_absent($c->{headers},'Authorization',"Bearer $t")}}
sub basic_auth{my($u,$p)=@_;die "basic auth username is required\n" if !defined($u)||ref($u);die "basic auth password is required\n" if !defined($p)||ref($p);my$c=encode_base64("$u:$p",'');sub{my($ctx)=@_;_set_header_if_absent($ctx->{headers},'Authorization',"Basic $c")}}
sub api_key_auth{my(%a)=@_;my$in=delete($a{in})//'header';my$n=delete$a{name};my$v=delete$a{value};die "unknown api_key auth option: $_\n" for sort keys%a;die "api_key in must be header or query\n" if$in ne'header'&&$in ne'query';die "api_key name must be a non-empty scalar\n" if !defined($n)||ref($n)||$n eq'';die "api_key value must be a scalar\n" if !defined($v)||ref($v);return sub{my($c)=@_;_set_header_if_absent($c->{headers},$n,"$v")} if$in eq'header';sub{my($c)=@_;my$u=$c->{url};return if$u=~/(?:[?&])\Q$n\E=/;my$s=index($u,'?')>=0?'&':'?';$c->{url}=$u.$s._uri_escape($n).'='._uri_escape($v)}}
sub _set_header_if_absent{my($h,$n,$v)=@_;my$w=lc$n;return if grep{lc($_) eq$w}keys%$h;$h->{$n}=$v}
sub _uri_escape{my($v)=@_;my$b="$v";utf8::encode($b) if utf8::is_utf8($b);$b=~s/([^A-Za-z0-9\-._~])/sprintf('%%%02X',ord($1))/ge;$b}
1;
