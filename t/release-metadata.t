use strict;
use warnings;
use Test::More;
use File::Find ();

my $makefile = do {
    open my $fh, '<', 'Makefile.PL' or die "cannot open Makefile.PL: $!";
    local $/;
    <$fh>;
};

like $makefile, qr/ABSTRACT_FROM\s*=>\s*'lib\/HTTP\/API\/Core\.pm'/, 'abstract comes from the main module';
like $makefile, qr/LICENSE\s*=>\s*'perl_5'/, 'distribution license is declared';
like $makefile, qr/MIN_PERL_VERSION\s*=>\s*'5\.010'/, 'minimum Perl version is declared';
like $makefile, qr{https://github\.com/kawamurashingo/HTTP-API-Core}, 'repository metadata is declared';

open my $manifest_fh, '<', 'MANIFEST' or die "cannot open MANIFEST: $!";
my %manifest = map { chomp; $_ => 1 } <$manifest_fh>;
ok $manifest{'docs/RELEASING.md'}, 'release guide ships in the distribution';

# The tarball must carry its legal and support information.
for my $required (qw(LICENSE CONTRIBUTING.md SECURITY.md)) {
    ok $manifest{$required}, "$required is included in the distribution";
}

# Catch stale entries and source files forgotten in MANIFEST before publishing.
for my $path (sort keys %manifest) {
    ok -f $path, "MANIFEST entry exists: $path";
}

my @source_files;
File::Find::find({
    no_chdir => 1,
    wanted => sub {
        my $path = $File::Find::name;
        return if !-f $path;
        $path =~ s{\A\./}{};
        push @source_files, $path
            if $path =~ m{\A(?:lib/.*\.pm|t/.*\.t|docs/.*\.md|examples/.*\.pm)\z};
    },
}, qw(lib t docs examples));

for my $path (sort @source_files) {
    ok $manifest{$path}, "source file is included in MANIFEST: $path";
}

ok -f 'docs/COMPATIBILITY.md', 'compatibility policy is present';
ok -f 'docs/RELEASING.md', 'release checklist is present';

done_testing;
