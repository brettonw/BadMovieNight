#! /usr/bin/perl

use Cwd;
use File::Find;
use File::Path;
use File::Copy;

#-----------------------------------------------------------
sub Append
{
    my ($base, $append) = @_;
    if (length ($base) > 0)
    {
        $base = $base . " ";
    }
    return $base . $append;
}

#-----------------------------------------------------------
sub AppendIfFileInProject
{
    my ($projectFileName, $base, $test, $append) = @_;
    #my $pwd = `pwd`;
    #print "PWD = $pwd\n";
    #print "TEST: grep -c $append $projectFileName\n";
    my $grepResult = `grep -c $test $projectFileName`;
    if ($grepResult > 0)
    {
        return Append ($base, $append);
    }
    return $base;
}

#-----------------------------------------------------------
sub MakeFullPath
{
    my ($path, $file) = @_;
    if ($file =~ /^\.\//)
    {
        $file =~ s/^\.\//$path/;
    }
    elsif ($file =~ /^\.\.\//)
    {
        $path =~ s/\/[^\/]*\/$/\//;
        $file =~ s/^\.\.\//$path/;
    }
    else
    {
        $file = $path . $file;
    }
    return $file;
}

#-----------------------------------------------------------
sub ProcessStringFile
{
    my ($stringFileName, $stringFileFullPath, %stringsFileDict) = @_;
    if ($stringsFileDict{$stringFileName} ne "")
    {
        print "Processing strings file: $stringFileName\n";
        
        # open the existing source and read it into a hash
        my %existingFileHash;
        my $line = "";
        open (EXISTING_FILE, "$stringsFileDict{$stringFileName}");
        while ($line = <EXISTING_FILE>) 
        {
            chomp $line;
            if ($line =~ /^(.*)=(.*)$/)
            {
                my ($key, $value) = ($1, $2);
                $existingFileHash{$key} = $value;
                #print "$key=$value\n";
            }
        }
        close (EXISTING_FILE);
        
        # open the new file and walk it, if a line has a value in the hash then
        # replace it with the existing value
        my $shouldCopy = 0;
        my $outputFileName = "$stringFileFullPath.out";
        open (NEW_FILE, "$stringFileFullPath");
        open (OUTPUT_FILE, ">$outputFileName");
        #print "$stringFileFullPath\n";
        while ($line = <NEW_FILE>) 
        {
            chomp $line;
            if ($line =~ /^(.*)=(.*)$/)
            {
                my ($key, $value) = ($1, $2);
                #print "$key=$value\n";
                if ($existingFileHash{$key})
                {
                    $value = $existingFileHash{$key};
                }
                else
                {
                    $shouldCopy = 1;
                }
                print OUTPUT_FILE "$key=$value\n";
            }
            else
            {
                print OUTPUT_FILE "$line\n";
            }
        }
        close (NEW_FILE);
        close (OUTPUT_FILE);

        
        # if there was a value in the new file not present in the old file, copy 
        # the new file over top of the old file
        if ($shouldCopy == 1)
        {
            print "  Copying due to new entries found...\n";
            move ($outputFileName, $stringsFileDict{$stringFileName});
        }
    }
    else
    {
        # because it's not already anywhere else...
        print "Skipping strings file: $stringFileName\n";
    }
}

#-----------------------------------------------------------
# find the project file
my $projectFileName = "";
my $path = cwd () . "/";
find (sub { if (/\.pbxproj$/) { $projectFileName = MakeFullPath ($path, $File::Find::name); } }, ".");
#print "Project File is: $projectFileName\n";

# find all of the source files
my $sourceFileList = "";
foreach $argnum (0 .. $#ARGV) {
    #print "Argument: $ARGV[$argnum]\n";
    find (sub { if (/\.m$/) { $sourceFileList = AppendIfFileInProject ($projectFileName, $sourceFileList, $_, MakeFullPath ($path, $File::Find::name)); } }, $ARGV[$argnum]);
}
#print "Source File List is: $sourceFileList\n";

# clear out the temp directory
my $tmp = "StringsTmp";
rmtree([$tmp]);

# find all the strings files in the project
my %stringsFileDict;
find (sub { if (/\.strings$/) { $stringsFileDict{$_} = MakeFullPath ($path, $File::Find::name); } }, ".");
while (($key, $value) = each (%stringsFileDict))
{
    #print "Found existing strings file: $key => $value\n";
}

# generate strings files into the new directory
mkdir ($tmp);
system ("genstrings -o $tmp/ $sourceFileList");
#system ("echo hello > $tmp/test.strings");

# look at all the strings files we just created
find (sub { if (/\.strings$/) { ProcessStringFile ($_, MakeFullPath ($path, $File::Find::name), %stringsFileDict); } }, $tmp);

# clean up now that we're done
rmdir ($tmp);

#-----------------------------------------------------------
