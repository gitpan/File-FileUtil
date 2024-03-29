#!perl
#
#
use 5.001;
use strict;
use warnings;
use warnings::register;

use vars qw($VERSION $DATE);
$VERSION = '0.06';
$DATE = '2003/06/21';

use Cwd;
use File::Spec;
use File::FileUtil;
use Test;

######
#
# T:
#
# use a BEGIN block so we print our plan before Module Under Test is loaded
#
BEGIN { 
   use vars qw( $__restore_dir__ @__restore_inc__ $__tests__);

   ########
   # Create the test plan by supplying the number of tests
   # and the todo tests
   #
   $__tests__ = 25;
   plan(tests => $__tests__);

   ########
   # Working directory is that of the script file
   #
   $__restore_dir__ = cwd();
   my ($vol, $dirs, undef) = File::Spec->splitpath( __FILE__ );
   chdir $vol if $vol;
   chdir $dirs if $dirs;

   #######
   # Add the current test directory to @INC
   #   (first t directory in upward march)
   #
   # Add the library of the unit under test (UUT) to @INC
   #   (lib directory at the same level as the t directory)
   #
   @__restore_inc__ = @INC;

   my $work_dir = cwd(); # remember the work directory so can restore it

   #######
   # Add the test directory root t to @INC
   #
   ($vol,$dirs) = File::Spec->splitpath( $work_dir, 'nofile');
   my @dirs = File::Spec->splitdir( $dirs );
   while( $dirs[-1] ne 't' ) { 
       chdir File::Spec->updir();
       pop @dirs;
   };


   ######
   # Add the unit under test root lib to @INC
   #
   unshift @INC, cwd();  # include the current test directory
   chdir File::Spec->updir();
   my $lib_dir = File::Spec->catdir( cwd(), 'lib' );
   unshift @INC, $lib_dir;

   chdir $work_dir;

}

END {

    #########
    # Restore working directory and @INC back to when enter script
    #
    @INC = @__restore_inc__;
    chdir $__restore_dir__;
}

#####
# New $fu object
#
my $fu = 'File::FileUtil';

#######
#
# ok: 1 
#
# R:
#
my $loaded;
print "# is_package_loaded\n";
ok ($loaded = $fu->is_package_loaded('File::Basename'), ''); 

#######
# 
# ok:  2
#
# R:
# 
print "# load_package\n";
my $errors = $fu->load_package( 'File::Basename' );
skip($loaded, $errors, '');
skip_rest( $errors, 2 );

#######
#
# ok:  3
#
# R:
#
print "# Pod_pod_errors\n";
ok( $fu->pod_errors( 'File::Basename'), 0 );

####
#
# ok: 4
#
# R:
#
print "# fspec2fspec\n";
ok( $fu->fspec2fspec( 'Unix', 'MSWin32', 'File/FileUtil.pm'), 
   'File\\FileUtil.pm');

####
#
# ok: 5
#
# R:
#
print "# fspec2os os2fspec 1\n";
ok( $fu->os2fspec( 'Unix', ($fu->fspec2os( 'Unix', 'File/FileUtil.pm'))), 
   'File/FileUtil.pm' );

####
#
# ok: 6
#
# R:
#
print "# fspec2os os2fspec 2\n";
ok( $fu->os2fspec( 'MSWin32', ($fu->fspec2os( 'MSWin32', 'Test\\TestUtil.pm'))), 
   'Test\\TestUtil.pm');

####
#
# ok: 7
#
# R:
#
print "# pm2require\n";
ok( $fu->pm2require( "$fu"), 
    $fu->fspec2os( 'Unix', 'File/FileUtil.pm'));

####
#
# ok: 8
#
# R:
#
print "# pm2file\n";
my ($file) = $fu->pm2file( "$fu" );
my  $found = 0;
foreach my $path (@INC) {
    if( $file =~ m=^\Q$path\E= ) {
       $found = 1;
       last;
    }   
}
ok ($found, 1);

####
#
# ok: 9
#
# R:
#
print "# sub_modules\n";
my @drivers = sort $fu->sub_modules( __FILE__, 'Drivers' );
ok( join (', ', @drivers), 'Driver, Generate, IO');

####
#
# ok: 10
#
# R:
#
print "# is_module\n";
ok( $fu->is_module('dri', @drivers ), 'Driver');

####
#
# ok: 11
#
# R:
#
print "# fspec2pm\n";
ok( $fu->fspec2pm('Unix', 'File/FileUtil.pm'), "$fu");

####
#
# ok: 12
#
# R:
#
print "# find_t_paths\n";
unshift @INC,File::Spec->catdir(cwd(),'lib');
my @t_path = $fu->find_t_paths( );
ok( $t_path[0], File::Spec->catdir(cwd(),'t'));
shift @INC;

####
#
# ok: 13
#
# R:
#
print "# fspec_glob Unix 1\n";
@drivers = sort $fu->fspec_glob('Unix','Drivers/G*.pm');
ok( join (', ', @drivers), 
    File::Spec->catfile('Drivers', 'Generate.pm'));

####
#
# ok: 14
#
print "# fspec_glob Unix 2\n";
@drivers = sort $fu->fspec_glob('MSWin32','Drivers\\I*.pm');
ok( join (', ', @drivers), 
    File::Spec->catfile('Drivers', 'IO.pm'));


####
#
# ok: 15
#
# R:
#
print "# test_lib2inc\n";
my @restore_inc = $fu->test_lib2inc( );

my ($vol,$dirs) = File::Spec->splitpath( cwd(), 'nofile');
my @dirs = File::Spec->splitdir( $dirs );
pop @dirs; pop @dirs;
shift @dirs unless $dirs[0];
my @expected_lib = ();
my @t_root = @dirs;
pop @t_root;
unshift @expected_lib, File::Spec->catdir($vol, @t_root);
$dirs[-1] = 'lib';
unshift @expected_lib, File::Spec->catdir($vol, @dirs);

ok( join('; ', ($INC[0],$INC[1])), 
    join('; ', @expected_lib));

@INC = @restore_inc;


####
#
# ok: 16
#
# R:
#
print "# pm2datah\n";
my $fh = $fu->pm2datah('File::FileUtil::Drivers::Driver');
my $actual_datah = $fu->fin($fh);
$actual_datah =~ s/^\s*(.*)\s*$/$1/gs;

my $expected_datah = << 'EOF';
\=head1 Title Page

 Software Version Description

 for

 ${TITLE}

 Revision: ${REVISION}

 Version: ${VERSION}

 Date: ${DATE}

 Prepared for: ${END_USER} 

 Prepared by:  ${AUTHOR}

 Copyright: ${COPYRIGHT}

 Classification: ${CLASSIFICATION}

\=cut
EOF

$expected_datah =~ s/^\s*(.*)\s*$/$1/gs;
ok($actual_datah, $expected_datah);

####
#
# ok: 17
#
# R:
#
print "# pm2data\n";
$actual_datah = $fu->pm2data('File::FileUtil::Drivers::Driver');
$actual_datah =~ s/^\s*(.*)\s*$/$1/gs;
ok($actual_datah, $expected_datah);

####
#
# ok: 18
#
# R:
#
print "# fin fout 1\n";
unlink 'test.pm';
my $fout_expected = "=head1 Title Page\n\nSoftware Version Description\n\nfor\n\n";
$fu->fout( 'test.pm', $fout_expected, {binary => 1} );
my $fout_actual = $fu->fin( 'test.pm' );
ok($fout_actual,$fout_expected);
unlink 'test.pm';

####
#
# ok: 19
#
# R:
#
print "# fin fout 2\n";
my $fout_dos = "=head1 Title Page\r\n\r\nSoftware Version Description\r\n\r\nfor\r\n\r\n";
$fu->fout( 'test.pm', $fout_dos, {binary => 1} );
$fout_actual = $fu->fin('test.pm');
ok($fout_actual, $fout_expected);
unlink 'test.pm';


####
#
# ok: 20
#
# R:
#
print "# find_in_path\n";
($vol,$dirs) = File::Spec->splitpath( cwd(), 'nofile');
@dirs = File::Spec->splitdir( $dirs );
pop @dirs; pop @dirs;
shift @dirs unless $dirs[0];
my $expected_file = File::Spec->catfile($vol, @dirs, 'File', 'FileUtil', 'FileUtil.t');
my $expected_dir = File::Spec->catdir($vol, @dirs);
my @actual = $fu->find_in_path('Unix', 'File/FileUtil/FileUtil.t');
ok( ( @actual ) ? join '; ', @actual : '', "$expected_file; $expected_dir" );


#######
# 
# ok:  21
#
# R:
# 
print "# load_package bad package\n";
my $error = $fu->load_package( 'File::FileUtil::BadLoad' );
ok($error =~ /Cannot load File::FileUtil::BadLoad/);

#######
# 
# ok:  22
#
# R:
# 
print "# load_package bad vocab\n";
ok($fu->load_package( 'File::FileUtil::BadVocab' ),
   "# File::FileUtil::BadVocab loaded but package vocabulary absent.\n");

#######
# 
# ok:  23
#
# R:
# 
print "# smart_nl\n";
my $text_actual =   "line1\015\012line2\012\015line3\012line4\015";
my $text_expected = "line1\nline2\nline3\nline4\n";
ok($fu->smart_nl($text_actual), $text_expected);


#######
# 
# ok:  24
#
# R:
# 
print "# hex_dump\n";
$text_actual = <<'EOF';
1..8 todo 2 5;
# OS            : MSWin32
# Perl          : 5.6.1
# Local Time    : Thu Jun 19 23:49:54 2003
# GMT Time      : Fri Jun 20 03:49:54 2003 GMT
# Number Storage: string
# Test::Tech    : 1.06
# Test          : 1.15
# Data::Dumper  : 2.102
# =cut 
# Pass test
ok 1
EOF
    
$text_actual =~ s/\n/\012/g; # replace logcial \n with ASCII \012 LF

$text_expected = <<'EOF';
312e2e3820746f646f203220353b0a23204f5320
20202020202020202020203a204d5357696e3332
0a23205065726c202020202020202020203a2035
2e362e310a23204c6f63616c2054696d65202020
203a20546875204a756e2031392032333a34393a
353420323030330a2320474d542054696d652020
202020203a20467269204a756e2032302030333a
34393a3534203230303320474d540a23204e756d
6265722053746f726167653a20737472696e670a
2320546573743a3a54656368202020203a20312e
30360a232054657374202020202020202020203a
20312e31350a2320446174613a3a44756d706572
20203a20322e3130320a23203d637574200a2320
5061737320746573740a6f6b20310a
EOF

$text_actual  = $fu->hex_dump( $text_actual  );
$fu->fout( 'actual.txt', $text_actual);
ok($text_actual, $text_expected);


####
#
# ok: 25
#
# R:
#
print "# find_t_roots\n";
my $dir = File::Spec->catdir(cwd(),'lib');
$dir =~ s=/=\\=g if $^O eq 'MSWin32';
unshift @INC,$dir;
@t_path = $fu->find_t_roots( );
$dir = cwd();
$dir =~ s=/=\\=g if $^O eq 'MSWin32';
ok( $t_path[0], $dir);
shift @INC;


####
# 
# Support:
#
#

sub skip_rest
{
    my ($results, $test_num) = @_;
    if( $results ) {
        for (my $i=$test_num; $i < $__tests__; $i++) { skip(1,0,0) };
        exit 1;
    }
}


__END__


=head1 NAME

FileUtil.t - test script for $fu

=head1 SYNOPSIS

 FileUtil.t 

=head1 COPYRIGHT

copyright � 2003 Software Diamonds.

Software Diamonds permits the redistribution
and use in source and binary forms, with or
without modification, provided that the 
following conditions are met: 

=over 4

=item 1

Redistributions of source code, modified or unmodified
must retain the above copyright notice, this list of
conditions and the following disclaimer. 

=item 2

Redistributions in binary form must 
reproduce the above copyright notice,
this list of conditions and the following 
disclaimer in the documentation and/or
other materials provided with the
distribution.

=back

SOFTWARE DIAMONDS, http://www.SoftwareDiamonds.com,
PROVIDES THIS SOFTWARE 
'AS IS' AND ANY EXPRESS OR IMPLIED WARRANTIES,
INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT
SHALL SOFTWARE DIAMONDS BE LIABLE FOR ANY DIRECT,
INDIRECT, INCIDENTAL, SPECIAL,EXEMPLARY, OR 
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE,DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING USE OF THIS SOFTWARE, EVEN IF
ADVISED OF NEGLIGENCE OR OTHERWISE) ARISING IN
ANY WAY OUT OF THE POSSIBILITY OF SUCH DAMAGE.

=cut

## end of test script file ##

