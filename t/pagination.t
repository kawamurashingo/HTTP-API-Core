use strict; use warnings; use Test::More; use HTTP::API::Core::Pagination;
{ package T::Response; sub new { bless {data=>$_[1]},$_[0] } sub json { $_[0]{data} } }
{ package T::Client; sub new { bless {calls=>[],pages=>$_[1]},$_[0] } sub get { my($s,$u,%o)=@_; push @{$s->{calls}},$u; die "no page for $u\n" if !exists $s->{pages}{$u}; T::Response->new($s->{pages}{$u}) } }
my $c=T::Client->new({'/users'=>{data=>{items=>[1,2]},links=>{next=>'/users?p=2'}},'/users?p=2'=>{data=>{items=>[3]},links=>{next=>undef}}}); my $p=HTTP::API::Core::Pagination->new(client=>$c,path=>'/users',mode=>'next_url',items=>'data.items',next=>'links.next'); is_deeply([$p->all],[1,2,3],'next URL');
my $pc=T::Client->new({'/users?page=1&per_page=2'=>{items=>[qw(a b)]},'/users?page=2&per_page=2'=>{items=>['c']}}); my $pp=HTTP::API::Core::Pagination->new(client=>$pc,path=>'/users',mode=>'page',items=>'items',page_size=>2); is_deeply(scalar($pp->all),[qw(a b c)],'page');
my $cc=T::Client->new({'/users?limit=2'=>{items=>[1,2],next_cursor=>'abc xyz'},'/users?cursor=abc%20xyz&limit=2'=>{items=>[3],next_cursor=>undef}}); my $cp=HTTP::API::Core::Pagination->new(client=>$cc,path=>'/users',mode=>'cursor',items=>'items',next=>'next_cursor',query=>{limit=>2}); is_deeply(scalar($cp->all),[1,2,3],'cursor');
done_testing;
