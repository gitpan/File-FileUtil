#!perl
#
# Documentation, copyright and license is at the end of this file.
#


#####
#
# File::FileUtil package
#
package  File::FileUtil;

use 5.001;
use strict;
use warnings;
use warnings::register;

use vars qw($VERSION $DATE);
$VERSION = '1.07';
$DATE = '2003/06/18';

use SelfLoader;
use File::Spec;

######
#
# Having trouble with requires in Self Loader
#
#####

######
# Many of the methods in this package are use the File::Spec
# module submodules. 
#
# The L<File::Spec||File::Spec> uses the current operating system,
# as specified by the $^O to determine the proper File::Spec submodule
# to use.
#
# Thus, when using File::Spec method, only the submodule for
# the current operating system is loaded and the File::Spec
# method directed to the corresponding method of the
# File::Spec submodule.
#
my %module = (
      MacOS   => 'Mac',
      MSWin32 => 'Win32',
      os2     => 'OS2',
      VMS     => 'VMS',
      epoc    => 'Epoc');

sub fspec2module
{
    my (undef,$fspec) = @_;
    $module{$fspec} || 'Unix';
}


#####
# Convert between file specifications for different operating systems to a Unix file specification
#
sub fspec2fspec
{
    my (undef, $from_fspec, $to_fspec, $fspec_file, $nofile) = @_;

    return $fspec_file if $from_fspec eq $to_fspec;

    #######
    # Extract the raw @dirs, file
    #
    my $from_module = File::FileUtil->fspec2module( $from_fspec );
    my $from_package = "File::Spec::$from_module";
    File::FileUtil->load_package( $from_package);
    my (undef, $fspec_dirs, $file) = $from_package->splitpath( $fspec_file, $nofile); 
    my @dirs = ($fspec_dirs) ? $from_package->splitdir( $fspec_dirs ) : ();

    return $file unless @dirs;  # no directories, file spec same for all os


    #######
    # Contruct the new file specification
    #
    my $to_module = File::FileUtil->fspec2module( $to_fspec );
    my $to_package = "File::Spec::$to_module";
    File::FileUtil->load_package( $to_package);
    my @dirs_up;
    foreach my $dir (@dirs) {
       $dir = $to_package->updir() if $dir eq $to_package->updir();
       push @dirs_up, $dir;
    }
    return $to_package->catdir(@dirs_up) if $nofile;
    $to_package->catfile(@dirs_up, $file); # to native operating system file spec

}

__DATA__

######
#
#
sub load_package
{

    my (undef, $package) = @_;
    unless ($package) { # have problem if there is no package
        my $error = "# The package name is empty. There is no package to load.\n";
        return $error;
    }
    if( $package =~ /\-/ ) {
        my $error =  "# The - in $package causes problem. Perl thinks - is subtraction when it evals it.\n";
        return $error;      
    }
    return '' if File::FileUtil->is_package_loaded( $package );

    #####
    # Load the module
    #
    # On error when evaluating "require $package" only the last
    # line of STDERR, at least on one Perl, is return in $@.
    # Save the entire STDERR to a memory variable
    #
    my $restore_warn = $SIG{__WARN__};
    my $warn_string = '';
    $SIG{__WARN__} = sub { $warn_string .= join '', @_; };
    eval "require $package;";
    $SIG{__WARN__} = $restore_warn;
    $warn_string = $@ . $warn_string if $@;
    if($warn_string) {
        $warn_string =~ s/\n/\n\t/g;
        return "Cannot load $package\n\t" . $warn_string;
    }

    #####
    # Verify the package vocabulary is pressent
    #
    unless (File::FileUtil->is_package_loaded( $package )) {
        return "# $package loaded but package vocabulary absent.\n";
    }
    ''
}


######
# Perl 5.6 introduced a built-in smart nl functionality as an IO discipline :crlf.
# See I<Programming Perl> by Larry Wall, Tom Christiansen and Jon Orwant,
# page 754, Chapter 29: Functions, open function.
# For Perl 5.6 or above, the :crlf IO discipline my be preferable over the
# smart_nl method of this package.
#
sub smart_nl
{
   my (undef, $data) = @_;
   $data =~ s/\015\012|\012\015/\012/g;  # replace LFCR or CRLF with a LF
   $data =~ s/\012|\015/\n/g;   # replace CR or LF with logical \n 
   $data;
}

####
# slurp in a text file in a platform independent manner
#
sub fin
{
   my (undef, $file, $options_p) = @_;


   ######
   # If have a file name, open the file, otherwise
   # the file is opened and the file name is a 
   # file handle.
   #
   my $fh;
   if( ref($file) eq 'GLOB' ) {
       $fh = $file;
   }
   else {
       my $fspec = $options_p->{fspec};
       $fspec = 'Unix' unless $fspec;
       $file = File::FileUtil->fspec2os($fspec, $file );   
       unless(open $fh, "<$file") {
           warn("# Cannot open <$file\n");
           return undef;
       }
   } 

   #####
   # slurp in the file contents with no operating system
   # translations
   #
   binmode $fh; # make the test friendly for more platforms
   my $data = join '', <$fh>;

   #####
   # Close the file
   #
   unless(close($fh)) {
       warn( "# Cannot close $file\n");
       return undef;
   }
   return $data unless( $data );

   #########
   # No matter what platform generated the data, convert
   # all platform dependent new lines to the new line for
   # the current platform.
   #
   $data = File::FileUtil->smart_nl($data) unless $options_p->{binary};
   $data          

}

####
# Find find
#
sub find_in_path
{
   my (undef, $fspec, $file, $path) = @_;

   $file = File::FileUtil->fspec2os($fspec, $file);
   $path = \@INC unless( $path );

   ######
   # Find the file in the search path
   #
   (undef, my $dirs, $file) = File::Spec->splitpath( $file ); 
   my (@dirs) = File::Spec->splitdir( $dirs );
   foreach my $path_dir (@$path) {
       my $file_abs = File::Spec->catfile( $path_dir, @dirs, $file );  
       if(-f $file_abs) {
          $path_dir =~ s|/|\\|g if $^O eq 'MSWin32';
          return ($file_abs, $path_dir) ;
       }
   }
   return undef;
}

###
# slurp a file out, current platform text format
#
sub fout
{
   my (undef, $file, $data, $options_p) = @_;

   my $fspec = $options_p->{fspec};
   $fspec = 'Unix' unless $fspec;
   $file = File::FileUtil->fspec2os($fspec, $file );   

   if($options_p->{append}) {
       unless(open OUT, ">>$file") {
           warn("# Cannot open >$file\n");
           return undef;
       }
   }
   else {
       unless(open OUT, ">$file") {
           warn("# Cannot open >$file\n");
           return undef;
       }
   }
   binmode OUT if $options_p->{binary};
   my $char_out = print OUT $data;
   unless(close(OUT)) {
       warn( "# Cannot close $file\n");
       return undef;
   }
   $char_out; 
}


######
#
#
sub pm2datah
{
    my (undef, $pm) = @_;
   
    #####
    #
    # Alternative:
    #    $fh = \*{"${svd_pm}::DATA"}; only works the first time load, thereafter, closed
    #
    # Only works the one time after loading a module. Thereafter it is closed. No rewinds.
    # 
    #
    my ($file) = File::FileUtil->pm2file( $pm );

    unless( $file ) {
        warn "# Cannot find file for $pm\n";
        return undef;
    }

    local($/);
    $/ = "__DATA__";
    my $fh;
    unless( open $fh, "< $file" ) {
        warn "# Cannot open $file\n";
        return undef;
    }    
    binmode $fh;

    ######
    # Move to the __DATA__ token
    #
    my $data = 'Start Search';

    while($data && $data !~ /[\012\015]__DATA__$/ ) {
        $data =  <$fh>;
    }

    $fh
}

######
#
#
sub pm2data
{
    my (undef, $pm) = @_;
    my $fh = File::FileUtil->pm2datah( $pm );
    my $data = File::FileUtil->fin($fh);
    close $fh;
    $data;
}


######
#
#
sub pm2file
{
   my (undef, $pm) = @_;
   my $require = File::FileUtil->pm2require( $pm );
   my ($file,$path) = File::FileUtil->find_in_path($^O, $require);
   ($file,$path)
}

#####
#
#
sub os2fspec
{
    my (undef, $fspec, $os_file, $nofile) = @_;
    File::FileUtil->fspec2fspec($^O, $fspec, $os_file, $nofile);
}

#####
#
#
sub fspec2os
{
    my (undef, $fspec, $fspec_file, $nofile) = @_;
    File::FileUtil->fspec2fspec( $fspec, $^O, $fspec_file, $nofile);
}


#####
#
#
sub pm2require
{
   my (undef, $pm) = @_;
   $pm .= '.pm';
   my @dirs = split /::/, $pm;
   my $require = File::Spec->catfile( @dirs );

}


#####
#
#
sub test_lib2inc
{
   #######
   # Add the library of the unit under test (UUT) to @INC
   #
   use Cwd;
   my $work_dir = cwd();
   my ($vol,$dirs) = File::Spec->splitpath( $work_dir, 'nofile');
   my @dirs = File::Spec->splitdir( $dirs );
   while( $dirs[-1] ne 't' ) { 
       chdir File::Spec->updir();
       pop @dirs;
   };
   my @inc = @INC;
   my $lib_dir = cwd();
   $lib_dir =~ s|/|\\|g if $^O eq 'MSWin32';  # microsoft abberation
   unshift @INC, $lib_dir;  # include the current test directory
   chdir File::Spec->updir();
   $lib_dir = File::Spec->catdir( cwd(), 'lib' );
   unshift @INC, $lib_dir;
   chdir $work_dir if $work_dir;
   @inc;
 
}

######
#
#
sub is_package_loaded
{
    my (undef, $package) = @_;
   
    $package .= "::";
    defined %$package

}



########
########
#
# Below is an attempt to make the reading and writing text files in the
# test software in a platform independent manner
#
########
########


sub fspec2pm
{
    my (undef, $fspec, $fspec_file) = @_;

    ##########
    # Must be a pm to conver to :: specification
    #
    return $fspec_file unless $fspec_file =~ /\.pm$/; 
    my $module = File::FileUtil->fspec2module( $fspec );
    my $fspec_package = "File::Spec::$module";
    File::FileUtil->load_package( $fspec_package);
    
    #####
    # extract the raw @dirs and file from the file spec
    # 
    my (undef, $fspec_dirs, $file) = $fspec_package->splitpath( $fspec_file ); 
    my @dirs = $fspec_package->splitdir( $fspec_dirs );
    pop @dirs unless $dirs[-1]; # sometimes get empty for last directory

    #####
    # Contruct the pm specification
    #
    $file =~ s/\..*?$//g; # drop extension
    $file = join '::', (@dirs,$file);    
    $file
}


#####
#
# Check pod for errors
#
sub pod_errors 
{

    my (undef, $module, $output_file) = @_;

    use Pod::Checker;
    my $checker = new Pod::Checker();
    my @module = split '::', $module;

    $module = File::Spec->catfile( @module );
    return undef unless ($module) = File::FileUtil->find_in_path( $^O, $module . '.pm');

    ## Now check the pod document for errors
    if( $output_file ) {
        $checker->parse_from_file($module, $output_file);
    }
    else {
        open (LOG, '> __null__.log');
        $checker->parse_from_file($module, \*LOG);
        close LOG;
        unlink '__null__.log';
    }

    $checker->num_errors()
}



####
# Find test paths
#
sub find_t_paths
{
   #######
   # Add t directories to the search path
   #
   my ($t_dir,@dirs,$vol);
   my @t_path=();
   foreach my $dir (@INC) {
       ($vol,$t_dir) = File::Spec->splitpath( $dir, 'nofile' );
       @dirs = File::Spec->splitdir($t_dir);
       $dirs[-1] = 't';
       $t_dir = File::Spec->catdir( @dirs);
       $t_dir = File::Spec->catpath( $vol, $t_dir, '');
       push @t_path,$t_dir;
   }
   @t_path;
}




#######
#
# Glob a file specification
#
sub fspec_glob
{
   my (undef, $fspec, @files) = @_;

   use File::Glob ':glob';

   my @glob_files = ();
   foreach my $file (@files) {
       $file = File::FileUtil->fspec2os( $fspec, $file );
       push @glob_files, bsd_glob( $file );
   }
   @glob_files;
}


#####
# Determine the output generator program modules
#
sub sub_modules
{
   my (undef, $base_file, @dirs ) = @_;

   use Cwd;
   use File::Glob ':glob';

   my $restore_dir = cwd();
   my ($vol, $dirs, undef) = File::Spec->splitpath(File::Spec->rel2abs($base_file));
   chdir $vol if $vol;
   chdir $dirs if $dirs;
   $dirs = File::Spec->catdir( @dirs );
   chdir $dirs if $dirs;
   my @modules = bsd_glob( '*.pm' );
   foreach my $module (@modules) {
       $module =~ s/\.pm$//;
   }
   chdir $restore_dir;
   @modules

}


#####
# Determine if a module is valid
#
sub is_module
{
   my (undef, $module, @modules) = @_;

   ($module) = $module =~ /^\s*(.*)\s*$/; # zap leading, trailing white space
   my $length = length($module);
   $module = lc($module);
   return undef unless( $length );

   my $module_found = '';
   foreach my $module_test (@modules) {
       if( $module eq  substr(lc($module_test), 0, $length)) {
           if( $module_found ) {
               warn "# Ambiguous $module\n";
               return undef;
           }
           $module_found = $module_test;
       }
   }
   return $module_found if $module_found;
   warn( "# Cannot find sub module $module.\n");
   undef

}



########
# Create a version file name based on a current file name.
#
sub version
{
   my ($self, $file, $base_new, $ext_new, $seq, $places) = @_;

   my ($base, $vol, $dir, $ext);
   if( $file ) {
       #####
       # Parse the file into an path, base name and extension 
       #
       ($base, $vol, $dir, $ext) = File::Parse->fileparse($file, '\..*' );
   }
   else {
       $file = 'temp.dat';
       $base = 'temp';
       $ext = '.dat';
       $dir='';
   }
  
   $ext = $ext_new if $ext_new;
   $base = $base_new if $base_new;
   $seq = 1 unless $seq;
   $places = 3 unless $places;
 
   my $top_seq = 10 ** $places;
   do {

       if ($top_seq <= $seq) {
           warn( "Sequence number $seq overflowed limit of $top_seq.\n");
           return  undef;
       }

       ######
       # Form a new base name with a sequence number
       #
       $file = sprintf( "$base%0$places" . "d$ext", $seq );
       $file = File::Spec->catpath($vol,$dir,$file);
       $seq += 1;

   }  while ( -e $file );

   unless( $file ) {
       warn("Empty sequence file name.\n");
       return undef;
   }
   return ($file, $seq);

}



1


__END__



=head1 NAME

File::FileUtil - various low-level subroutines that involve files

=head1 SYNOPSIS

  use File::FileUtil

  $data          = smart_nl($data)
  $data          = File::FileUtil->fin( $file_name )
  $success       = File::FileUtil->fout($file_name, $data)

  $package       = File::FileUtil->is_package_loaded($package)
  $error         = File::FileUtil->load_package($package)
  $errors        = File::FileUtil->pod_errors($package)

  $file          = File::FileUtil->fspec2fspec($from_fspec, $to_fspec $fspec_file, [$nofile])
  $os_file       = File::FileUtil->fspec2os($fspec, $file, [$no_file])
  $fspec_file    = File::FileUtil->os2fspec($fspec, $file, [$no_file])
  $pm_file       = File::FileUtil->fspec2pm( $fspec, $file )
  $file          = File::FileUtil->pm2file($pm_file)
  $file          = File::FileUtil->pm2require($pm_file)

  ($file, $path) = File::FileUtil->find_in_path($fspec, $file, [\@path])
  @INC           = File::FileUtil->test_lib2inc()
  @t_path        = File::FileUtil->find_t_paths()

  $fh            = File::FileUtil->pm2datah($pm_file)
  $data          = File::FileUtil->pm2data($pm_file)

  @sub_modules   = File::FileUtil->sub_modules($base_file, @dirs)
  $module        = File::FileUtil->is_module($module, @modules)

  @globed_files  = File::FileUtil->fspec_glob($fspec, @files)

=head1 DESCRIPTION

The methods in the C<File::FileUtil> package are designed to support the
L<C<Test::STDmaker>|Test::STDmaker> and 
the L<C<ExtUtils::SVDmaker>|ExtUtils::SVDmaker> package.
This is the focus and no other focus.
Since C<File::FileUtil> is a separate package, the methods
may be used elsewhere.
In all likehood, any revisions will maintain backwards compatibility
with previous revisions.
However, support and the performance of the 
L<C<Test::STDmaker>|Test::STDmaker> and 
L<C<ExtUtils::SVDmaker>|ExtUtils::SVDmaker> packages has
priority over backwards compatibility.

Many of the methods in this package are use the L<File::Spec||File::Spec>
module submodules. 
The L<File::Spec||File::Spec> uses the current operating system,
as specified by the $^O to determine the 
proper L<File::Spec||File::Spec> submodule to use.
Thus, when using L<File::Spec||File::Spec> method, 
only the submodule for the current operating system is
loaded and the L<File::Spec||File::Spec> method directed
to the corresponding method of the L<File::Spec||File::Spec>
submodule.

Many methods in this package, manipulate file specifications for 
operating systems other then the current site operating system.
The input variable I<$fspec> tells the methods in this package
the file specification for file names used as input to the methods.
Thus, when using methods in this package up to two, the method may 
load up to two L<File::Spec||File::Spec> submodules methods and
neither of them is a submodule for the current site operating
system.

Supported operating system file specifications are as follows:

 MacOS
 MSWin32
 os2
 VMS
 epoc

Of course since, the variable I<$^O> contains the file specification
for the current site operating system, it may be used for the
I<$fspec> variable.

=head2 fin fout method

  $data = File::FileUtil->fin( $file_name )
  $success = File::FileUtil->fout($file_name, $data, \%options)

Different operating systems have different new line sequences. Microsoft uses
\015\012 for text file, \012 for binary files, Macs \015 and Unix 012.  
Perl adapts to the operating system and uses \n as a logical new line.
The \015 is the L<ASCII|http://ascii.computerdiamonds.com> Carraige Return (CR)
character and the \012 is the L<ASCII|http://ascii.computerdiamonds.com> Line
Feed character.

The I<fin> method will translate any CR LF combination into the logical Perl
\n character. Normally I<fout> will use the Perl \n character. 
In other words I<fout> uses the CR LF combination appropriate of the operating
system and file type.
However supplying the option I<{binary => 1}> directs I<fout> to use binary mode and output the
CR LF raw without any translation.

By using the I<fin> and I<fout> methods, text files may be freely exchanged between
operating systems without any other processing. For example,

 ==> my $text = "=head1 Title Page\n\nSoftware Version Description\n\nfor\n\n";
 ==> File::FileUtil->fout( 'test.pm', $text, {binary => 1} );
 ==> File::FileUtil->fin( 'test.pm' );

 =head1 Title Page\n\nSoftware Version Description\n\nfor\n\n

 ==> my $text = "=head1 Title Page\r\n\r\nSoftware Version Description\r\n\r\nfor\r\n\r\n";
 ==> File::FileUtil->fout( 'test.pm', $text, {binary => 1} );
 ==> File::FileUtil->fin( 'test.pm' );

=head2 find_in_path method

 ($file_absolute, $path) = File::FileUtil->find_in_path($fspec, $file_relative, [\@path])

The I<find_in_path> method looks for the I<$file_relative> in one of the directories in
the I<@INC> path or else the I<@path> in the order listed.
The file I<$file_relative> may include relative directories.
When I<find_in_path> finds the file, it returns the abolute file I<$file_absolute> and
the directory I<$path> where it found I<$file_relative>.
The input variable I<$fspec> is the file specification for I<$file_relative>.

For example, running on Microsoft windows with I<C:\Perl\Site\t> in the I<@INC> path,
and the file I<Test\TestUtil\TestUtil.t> present

 ==> File::FileUtil->find_in_path('Unix', 'Test/TestUtil/TestUtil.t')

 C:\Perl\Site\t\Test\TestUtil\TestUtil.t
 C:\Perl\Site\t

=head2 find_t_paths method

This method operates on the assumption that the test files are a subtree to
a directory named I<t> and the I<t> directories are on the same level as
the last directory of each directory tree specified in I<@INC>.
If this assumption is not true, this method most likely will not behave
very well.

The I<find_t_paths> method returns the directory trees in I<@INC> with
the last directory changed to I<t>.

For example, 

 ==> @INC

 myperl/lib
 perl/site/lib
 perl/lib 

 => File::FileUtil->find_t_paths()

 myperl/t
 perl/site/t
 perl/t 

=head2 fspec_glob method

  @globed_files = File::FileUtil->fspec_glob($fspec, @files)

The I<fspec_glob> method BSD globs each of the files in I<@files>
where the file specification for each of the files is I<$fspec>.

For example, running under the Microsoft operating system, that contains a
directory I<Drivers> with file I<Generators.pm Driver.pm IO.pm>
under the current directory

 => File::FileUtil->fspec_glob('Unix','Drivers/G*.pm')

 Drivers\Generate.pm

 => File::FileUtil->fspec_glob('MSWin32','Drivers\\I*.pm') 

 Drivers\IO.pm

=head2 fspec2fspec method

 $to_file = File::FileUtil->fspec2fspec($from_fspec, $to_fspec $from_file, $nofile)

THe I<fspec2fspec> method translate the file specification for I<$from_file> from
the I<$from_fspec> to the I<$to_fpsce>. Supplying anything for I<$nofile>, tells
the I<fspec2fspec> method that I<$from_file> is a directory tree; otherwise, it
is a file.

For example,

 => File::FileUtil->fspec2fspec( 'Unix', 'MSWin32', 'Test/TestUtil.pm') 

 Test\\TestUtil.pm

=head2 fspec2os method

  $os_file = File::FileUtil->fspec2os($fspec, $file, $no_file)

The I<fspec2os> method translates a file specification, I<$file>, from the
current operating system file specification to the I<$fspec> file specification.
Supplying anything for I<$nofile>, tells
the I<fspec2fspec> method that I<$from_file> is a directory tree; otherwise, it
is a file.

For example, running under the Microsoft operating system:

 ==> File::FileUtil->fspec2os( 'Unix', 'Test/TestUtil.pm')
 
 Test\\TestUtil.pm

=head2 fspec2pm method

 $pm_file = File::FileUtil->fspec2pm( $fspec, $file )

The I<fspec2pm> method translates a filespecification I<$file>
in the I<$fspce> format to the Perl module formate.

For example,

 ==> File::FileUtil->fspec2pm('Unix', 'Test/TestUtil.pm')

 File::FileUtil

=head2 is_module method

 $driver = Test::TestUtil->is_module($module, @modules)

The I<is_module> method determines if I<$module> is present
in I<@modules>. The detemination is case insensitive and
only the leading characters are needed.

For example, 

 ==> @drivers

 (Driver
 Generate
 IO)

 ==> Test::TestUtil->is_driver('dri', @drivers )

 Driver

=head2 is_package_loaded method

 $package = File::FileUtil->is_package_loaded($package)

The I<is_package_loaded> method determines if a package
vocabulary is present.

For example, if I<File::Basename> is not loaded

 ==> File::FileUtil->is_package_loaded('File::Basename')

 ''

=head2 load_package method

 $error = File::FileUtil->load_package($package)

The I<load_package> method loads attempts to load a package.
The return is any I<$error> that occurred during the load
attempt. The I<load_package> will check that the package
vocabulary is present. Altough it is a Perl convention,
the package name(s) in a package file do not have to
be the same as the package file name. 
For these few cases, this method will load the packages
in the file, but fail the package vocabulary test.

For example,

 ==> File::FileUtil->load_package( 'File::Basename' )
 ''

=head2 os2fspec method

 $file = File::FileUtil->os2fspec($fspec, $os_file, $no_file)

The I<fspec2os> method translates a file specification, I<$file>, from the
current operating system file specification to the I<$fspec> file specification.
Supplying anything for I<$nofile>, tells
the I<fspec2fspec> method that I<$from_file> is a directory tree; otherwise, it
is a file.

For example, running under the Microsoft operating system:

 ==> File::FileUtil->os2fspec( 'Unix', 'Test\\TestUtil.pm')

 Test/TestUtil.pm

=head2 pm2datah method

 $fh = File::FileUtil->pm2datah($pm_file)

The I<pm2datah> method will open the I<$pm_file> and
return a handle positioned at the first I</[\012\015]__DATA__/>
token occuring in the file.
This function is very similar to the I<DATA> file handle
that Perl creates when loading a module file with the
I</[\012\015]__DATA__/> token.
The differences is that I<pm2datah> works whether or
not the file module is loaded. 
The method does not close the file handle.
Unlike the I<DATA> file handle, which cannot be reused
after the module data is read the first time,
the I<pm2datah> will always return an opened file handle,
the first time, the second time, any time.

CAUTION: 

If the I</[\012\015]__DATA__/> token appears
in the code section, say in a comment, or as
a value assigned to a variable,
the I<pm2datah> method will misbehave.

For example,

 ==> my $fh = File::FileUtil->pm2datah('File::FileUtil::Drivers::Driver')
 ==> join '',<$fh>;

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

=head2 pm2data method

 $data = File::FileUtil->pm2data($pm_file)

The I<pm2data> uses the L<I<pm2datah>|File::FileUtil/pm2datah>
to return all the data in a I<$pm_file> form the I<__DATA__>
token to the end of the file.

For example,

 ==> my $fh = File::FileUtil->pm2data('File::FileUtil::Drivers::Driver')

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

=head2 pm2file method

  ($file, $path) = File::FileUtil->pm2file($pm_file)

The I<pm2file> method returns the absolute file and
the directory in I<@INC> for a the program module
I<$pm_file>.

For example, running on a Microsoft operating system,
if I<File::FileUtil> is in the I<C:\myperl\t> directory, 
and I<C:\myperl\t> is in the I<@INC> path,

 ==> File::FileUtil->pm2file( 'File::FileUtil');

 (C:\myperl\t\Test\TestUtil.pm
 C:\myperl\t)

=head2 pod_errors method

 $errors = File::FileUtil->pod_errors($package)

The I<pod_errors> uses I<Pod::Checker> to analyze
a package and returns the number of I<$errors>

For example,

 ==> File::FileUtil->pod_errors( 'File::Basename')

 0

=head2 pm2require

 $file = File::FileUtil->pm2require($pm_file)

The I<pm2require> method returns the file suitable
for use in a Perl I<require> given the I<$pm_file>
file.

For example, running under Microsoft Windows

 ==> File::FileUtil->pm2require( 'File::FileUtil')

 File\FileUtil.pm

=head2 smart_nl method

  $data = File::FileUtil->smart_nl( $data  )

Different operating systems have different new line sequences. Microsoft uses
\015\012 for text file, \012 for binary files, Macs \015 and Unix 012.  
Perl adapts to the operating system and uses \n as a logical new line.
The \015 is the L<ASCII|http://ascii.computerdiamonds.com> Carraige Return (CR)
character and the \012 is the L<ASCII|http://ascii.computerdiamonds.com> Line
Feed character.

The I<fin> method will translate any CR LF combination into the logical Perl
\n character. Normally I<fout> will use the Perl \n character. 
In other words I<fout> uses the CR LF combination appropriate of the operating
system and file type.
However supplying the option I<{binary => 1}> directs I<fout> to use binary mode and output the
CR LF raw without any translation.

Perl 5.6 introduced a built-in smart nl functionality as an IO discipline :crlf.
See I<Programming Perl> by Larry Wall, Tom Christiansen and Jon Orwant,
page 754, Chapter 29: Functions, open function.
For Perl 5.6 or above, the :crlf IO discipline my be preferable over the
smart_nl method of this package.

=head2 sub_modules method

  @sub_modules = File::FileUtil->sub_modules($base_file, @dirs)

Placing sub modules in their own private directory provides
a method to add a new sub_modules without changing the using module.
The parent object finds all the available sub_modules by listing
the modules in the sub_module directory using the I<sub_modules> method.

The I<sub_modules> method takes as its input a I<$base_file>, a file
in the parent directory, and a list of subdirectories, I<@dirs>, relative to
the I<$base_file>. It returns the a list,  I<@sub_modules>, of I<*.pm> file names 
stripped of the extension I<.pm> in the identified directory.

For example, if the subdirectory I<Drivers> to the file I<__FILE__>
contains the files I<Driver.pm Generate.pm IO.pm>, then

 ==> join ',', sort File::FileUtil->sub_modules( __FILE__, 'Drivers' );

 'Driver, Generate, IO'


=head1 NOTES

=head2 AUTHOR

The holder of the copyright and maintainer is

E<lt>support@SoftwareDiamonds.comE<gt>

=head2 COPYRIGHT NOTICE

Copyrighted (c) 2002 Software Diamonds

All Rights Reserved

=head2 BINDING REQUIREMENTS NOTICE

Binding requirements are indexed with the
pharse 'shall[dd]' where dd is an unique number
for each header section.
This conforms to standard federal
government practices, 490A (L<STD490A/3.2.3.6>).
In accordance with the License, Software Diamonds
is not liable for any requirement, binding or otherwise.

=head2 LICENSE

Software Diamonds permits the redistribution
and use in source and binary forms, with or
without modification, provided that the 
following conditions are met: 

=over 4

=item 1

Redistributions of source code must retain
the above copyright notice, this list of
conditions and the following disclaimer. 

=item 2

Redistributions in binary form must 
reproduce the above copyright notice,
this list of conditions and the following 
disclaimer in the documentation and/or
other materials provided with the
distribution.

=back

SOFTWARE DIAMONDS, http::www.softwarediamonds.com,
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

=for html
<p><br>
<!-- BLK ID="NOTICE" -->
<!-- /BLK -->
<p><br>
<!-- BLK ID="OPT-IN" -->
<!-- /BLK -->
<p><br>
<!-- BLK ID="EMAIL" -->
<!-- /BLK -->
<p><br>
<!-- BLK ID="COPYRIGHT" -->
<!-- /BLK -->
<p><br>
<!-- BLK ID="LOG_CGI" -->
<!-- /BLK -->
<p><br>

=cut

### end of file ###