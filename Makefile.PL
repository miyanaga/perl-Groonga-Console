use 5.008;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Groonga::Console',
    VERSION_FROM      => 'lib/Groonga/Console.pm', # finds $VERSION
    PREREQ_PM         => {}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Groonga/Console.pm', # retrieve abstract from module
       AUTHOR         => 'Kunihiko Miyanaga <miyanaga@ideamans.com>') : ()),
    LIBS              => ['-L/usr/local/lib -L/usr/lib -lgroonga'], # e.g., '-lm'
    DEFINE            => '', # e.g., '-DHAVE_SOMETHING'
    INC               => '-I. -I/usr/local/include -I/usr/include', # e.g., '-I. -I/usr/include/other'
	# Un-comment this if you add C files to link with later:
    # OBJECT            => '$(O_FILES)', # link all the C files too
    XSOPT             => '-C++',
    CCFLAGS           => '-g',
    CC                => 'g++',
    LD                => 'g++',
);
