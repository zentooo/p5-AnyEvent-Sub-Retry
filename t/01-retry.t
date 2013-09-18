use strict;
use warnings;
use Test::More;

use AnyEvent::Sub::Retry qw(retry);


subtest 'no retry' => sub {
    subtest 'success' => sub {
        my $call_count = 0;
        my $t;
        my $code_ref = sub {
            $call_count ++;
            my $cv = AE::cv;
            $t = AnyEvent->timer(cb => sub { $cv->send('foo', 'var') });
            return $cv;
        };
        my $cv = retry 1, 1, $code_ref;
        is_deeply([$cv->recv], ['foo', 'var']);
        is $call_count, 1;
    };
    subtest 'failure' => sub {
        my $call_count = 0;
        my $t;
        my $code_ref = sub {
            $call_count ++;
            my $cv = AE::cv;
            $t = AnyEvent->timer(cb => sub { $cv->croak('oh no!') });
            return $cv;
        };
        my $cv = retry 1, 1, $code_ref;
        eval { $cv->recv; };
        like $@, qr/oh no!/;
        is $call_count, 1;
    }
};

subtest 'with retry' => sub {
    my $call_count = 0;
    my $t;
    my $now = AnyEvent->time;
    my $code_ref = sub {
        $call_count ++;
        my $cv = AE::cv;
        my $should_return_success = $call_count == 1 ? 0 : 1;
        $t = AnyEvent->timer(
            cb => sub {
                if ($should_return_success) {
                    $cv->send('foo', 'var');
                } else {
                    $cv->croak('error!');
                }
            }
        );
        return $cv;
    };
    my $cv = retry 2, 0.1, $code_ref;
    is_deeply([$cv->recv], ['foo', 'var']);
    is $call_count, 2;
    
    my $t_diff = AnyEvent->time - $now;
    ok ($t_diff > 0.09 && $t_diff < 0.11) or note $t_diff;;
};


done_testing;

1;
