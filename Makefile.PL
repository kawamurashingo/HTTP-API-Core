use ExtUtils::MakeMaker;
WriteMakefile(
  NAME => 'HTTP::API::Core',
  VERSION_FROM => 'lib/HTTP/API/Core.pm',
  PREREQ_PM => {
    'HTTP::Tiny'    => 0,
    'JSON::PP'      => 0,
    'MIME::Base64'  => 0,
    'Scalar::Util'  => 0,
    'Time::HiRes'   => 0,
  },
);
