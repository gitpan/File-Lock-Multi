#!perl

use strict;
use warnings (FATAL => 'all');
use Test::More qw(no_plan);
use Test::Exception;
use File::Temp qw(tmpnam);
use File::Lock::Multi;
use File::Lock::Multi::Fuser;
use Time::HiRes qw(time);

my $file = tmpnam;
my @lockers;

foreach (1 .. 6) {
  push(@lockers, File::Lock::Multi::Fuser->new(file => $file, max => 5, timeout => 0));
}

diag("non-blocking locks");
throws_ok { $lockers[0]->release } qr/i do not have a lock/,
  "can't release if we have never locked";
ok($lockers[0]->lock);
ok($lockers[0]->locked);
is($lockers[0]->lockers, 1);
ok($lockers[1]->lock);
is($lockers[0]->lockers, 2);
ok($lockers[2]->lock);
throws_ok { $lockers[2]->lock } qr/i already have a lock/,
  "can't double-lock";
is($lockers[0]->lockers, 3);
ok($lockers[3]->lock);
is($lockers[0]->lockers, 4);
ok($lockers[4]->lock);
ok(!$lockers[5]->lock);
ok(!$lockers[5]->locked);

diag("lock w/timeout");
$lockers[5]->timeout(2);
my $st = time();
ok(!$lockers[5]->lock);
my $et = time();
my $dt = $et - $st;
ok($dt >= 1, "waited for our timeout");
$lockers[5]->polling_interval(6);
$st = time();
ok(!$lockers[5]->lock, "funny polling_interval");
$et = time();
$dt = $et - $st;
ok($dt >= 1, "waited for our timeout");
ok($dt <= 3, "didn't wait too long");

diag("blocking lock");
ok($lockers[4]->release);
$lockers[5]->timeout(-1);
ok($lockers[5]->lock, 'blocking lock');
ok($lockers[5]->release, 'blocking unlock');
throws_ok { $lockers[5]->release } qr/i do not have a lock/,
  "can't double-release";
ok($lockers[5]->lockable, 'lockability test');
ok($lockers[4]->lock, 'non-blocking lock');
ok(!$lockers[5]->lockable, 'lockability test never blocks');

diag("obligatory coverage tests");

ok(File::Lock::Multi::Fuser->new(file => $file), "base default args");
dies_ok { File::Lock::Multi::Fuser->new } "file is required";
throws_ok { File::Lock::Multi->new } qr/is a base class/,
    "Can't instantiate the base class directly";
ok(
  File::Lock::Multi::Fuser->new(file => $file, polling_interval => 2, timeout => 1),
  "new()"
);

unlink($file);

