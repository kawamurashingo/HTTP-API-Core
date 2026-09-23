use strict;
use warnings;
use Test::More;

use HTTP::API::Core;

is $HTTP::API::Core::VERSION, '1.07', 'distribution version is 1.07';

done_testing;
