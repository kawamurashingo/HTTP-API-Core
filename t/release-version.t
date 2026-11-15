use strict;
use warnings;
use Test::More;

use HTTP::API::Core;

is $HTTP::API::Core::VERSION, '1.09', 'distribution version is 1.09';

done_testing;
