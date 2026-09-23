use strict;
use warnings;
use Test::More;

use HTTP::API::Core;

is $HTTP::API::Core::VERSION, '1.06', 'distribution version is 1.06';

done_testing;
