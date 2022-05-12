#!/usr/bin/env perl

#    git-resolve-conflict-using-kdiff3
#    Copyright (C) 2022 Håkon Løvdal <kode@denkule.no>
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <https://www.gnu.org/licenses/>.

use warnings;
use strict;
# use diagnostics; Depends on perl_pods package on cygwin (not installed by default, https://stackoverflow.com/a/36538115/23118). Not available in git-for-windows.
use File::Temp qw/ tempfile /;
#use Data::Printer;
use Text::Wrap;
use Term::ANSIColor;
use String::ShellQuote;

###use IPC::System::Simple qw(capturex);

# In case of problems with "X Error: BadShmSeg (invalid shared segment parameter) 128", run
# env QT_X11_NO_MITSHM=1 git-resolve-conflict-using-kdiff3

my $terminal_width = 80;

# http://stackoverflow.com/a/823638/23118
if  (eval {require Term::ReadKey;1;}) {
	#module loaded
	Term::ReadKey->import();
	($terminal_width, undef, undef, undef) = GetTerminalSize();
	$terminal_width = 80 if ($terminal_width > 80);
}

$Text::Wrap::columns = $terminal_width;

sub help {
	my $line1 = "This command will interactively start kdiff3 with all versions "
	. "of a file involved in a merge conflict. Git has natively support for using "
	. "kdiff3 for the command mergetool (and difftool) so if you just run the "
	. "command git-merge you are set, however there are many situations were a "
	. "conflict might occur where git is unable to assist with kdiff3 "
	. "(git-rebase, git-cherry-pick).\n";
	print wrap('', '', $line1), "\n";
	print "This command fills that void.\n";
}

my $one_descr = "the common ancestor";
my $two_descr = "the current branch";
my $three_descr = "the other branch";

my %one = ();
my %two = ();
my %three = ();

# Example output from ls-files -u
# 100644 d0ede601dde8db821c130de742e01b0c805730bc 1       main.c
# 100644 8adaa18e17c8f381ed97035e884ced00b1d27a72 2       main.c
# 100644 e71a590ceea22ce3cd5096e5bf07f7e6739378da 3       main.c
#
# This function updates global hashes %one, %two and %three.
# It returns an array with the file names.
sub find_unmerged_files {
	my $toplevel_dir = shift @_;
	my %tmp;
	open(PIPE, "git ls-files --unmerged " . shell_quote($toplevel_dir) . " -z |");
	if (not eof(PIPE)) {
		foreach my $line (split(/\0/, <PIPE>)) {
			chomp($line);
			my ($prefix, $file) = split(/\t/, $line);
			my (undef, $sha, $number) = split(/ /, $prefix);
			$one{$file}   = $sha if $number == 1;
			$two{$file}   = $sha if $number == 2;
			$three{$file} = $sha if $number == 3;
			$tmp{$file} = 0;
		}
	}
	close(PIPE);
	return keys %tmp;
}

sub any_files_modified {
	my $ret = 0;
	open(PIPE, 'git status --porcelain |');
	foreach my $line (<PIPE>) {
		if ($line =~ /^[MUDA]/) {
			$ret = 1;
			last;
		}
	}
	close(PIPE);
	return $ret;
}

sub prompt {
	my $display_prompt = shift @_;
	my $chars = shift @_;
	my $default = shift @_;
	my $input;
	do {
		print "$display_prompt [$chars] ($default): ";
		$input = <>;
		chomp $input;
		$input = $default if $input =~ /^$/;
	} while (! ($input =~ /^[$chars]/));
	return $input;
}

sub blob2file {
	my $file = shift @_;
	my $sha1 = shift @_;
	my (undef, $tempfilename) = tempfile($file . '.XXXXXX');
	### my $blob = capturex("git", "cat-file", "blob", $sha1);
	#system("sh", "-c", "git", "cat-file", "blob", $sha1, ">", $tempfilename);
	system("git cat-file blob $sha1 > " . shell_quote($tempfilename));
	return $tempfilename;
}

sub git_add_file_from_blob {
	my $filename = shift;
	my $sha1 = shift;
	my $file_to_add = blob2file($filename, $sha1);
	system("mv", $file_to_add, $filename);
	system("git", "add", $filename);
}

sub rebase_ongoing {
	my $git_dir = shift;
	return (-d "$git_dir/rebase-merge" || -d "$git_dir/rebase-apply");
}
sub merge_ongoing {
	my $git_dir = shift;
	return (-f "$git_dir/MERGE_HEAD");
}
sub cherry_pick_ongoing {
	my $git_dir = shift;
	return (-f "$git_dir/CHERRY_PICK_HEAD");
}
sub imerge_ongoing {
	my $git_dir = shift;
	my $branch_name = `git symbolic-ref HEAD`;
	return $branch_name =~ /^refs\/heads\/imerge/;
}

sub print_continue_commands {
	my $git_dir = shift;
	system("git", "status");

	print "Command(s) suggested to continue:\n\n\n";
	if (any_files_modified()) {
		print "git diff --cached\n\n";
	}
	if (rebase_ongoing($git_dir)) {
		if (any_files_modified()) {
			print "git rebase --continue\n";
		} else {
			print "git rebase --skip\n";
		}
	} elsif (imerge_ongoing($git_dir)) {
		print "git imerge continue\n";
	} elsif (cherry_pick_ongoing($git_dir) || merge_ongoing($git_dir)) {
		print "git commit\n";
	}
	print "\n\n";
}

sub operation_ongoing {
	my $git_dir = shift;
	return 1 if rebase_ongoing($git_dir);
	return 1 if imerge_ongoing($git_dir);
	return 1 if (cherry_pick_ongoing($git_dir) || merge_ongoing($git_dir));
	return 0;
}

################################################################################

my $git_dir = `git rev-parse --git-dir`;
chomp($git_dir);

if ($git_dir eq "") {
	print "$0: error: not within a git repository\n\n";
	help();
	exit 1;
}

my $git_toplevel_dir = `git rev-parse --show-toplevel`;
chomp($git_toplevel_dir);

my @unmerged_files = find_unmerged_files($git_toplevel_dir); # modifies %one, %two and %three as well

if (scalar(@unmerged_files) == 0) {
	if (operation_ongoing($git_dir)) {
		print_continue_commands($git_dir);
		exit 0;
	} else {
		print "$0: error: no files in conflict\n\n";
		help();
		exit 1;
	}
}

print '=' x $terminal_width, "\n";
print scalar(@unmerged_files), " unmerged files in total:\n";
foreach my $file (@unmerged_files) {
	print("\t$file\n");
}
print '=' x $terminal_width, "\n";

my $n = 1;
foreach my $file (@unmerged_files) {
	print "Handling " . colored($file, 'green' ) . " (", $n++, "/", scalar(@unmerged_files), "): ";
	my $file_added_on_only_one_branch = 0;
	my $file_removed = 0;

	# http://gitster.livejournal.com/25801.html
	if (defined $one{$file} && defined $two{$file} && defined $three{$file}) {
		my $msg = "Modified on both branches\n";
		print colored($msg, 'yellow' );
	}
	if (defined $one{$file} && defined $two{$file} && !defined $three{$file}) {
		my $msg = "Deleted on ${three_descr} but modified on ${two_descr}\n";
		print colored($msg, 'yellow' );
		$file_removed = 3;
	}
	if (defined $one{$file} && !defined $two{$file} && defined $three{$file}) {
		my $msg = "Modified on ${three_descr} but deleted on ${two_descr}\n";
		print colored($msg, 'yellow' );
		$file_removed = 2;
	}
	if (defined $one{$file} && !defined $two{$file} && !defined $three{$file}) {
		my $msg = "Deleted on both branches\n";
		print colored($msg, 'yellow' );
		$file_removed = 23;
	}
	if (!defined $one{$file} && defined $two{$file} && defined $three{$file}) {
		my $msg = "File added independently on both branches\n";
		print colored($msg, 'yellow' );
	}
	if (!defined $one{$file} && defined $two{$file} && !defined $three{$file}) {
		my $msg = "File added only on ${two_descr}\n";
		print colored($msg, 'yellow' );
		$file_added_on_only_one_branch = 2;
	}
	if (!defined $one{$file} && !defined $two{$file} && defined $three{$file}) {
		my $msg = "File added only on ${three_descr}\n";
		print colored($msg, 'yellow' );
		$file_added_on_only_one_branch = 3;
	}

	print("1: ", substr($one{$file}, 0, 7), " ") if (defined $one{$file});
	print("2: ", substr($two{$file}, 0, 7), " ") if (defined $two{$file});
	print("3: ", substr($three{$file}, 0, 7), "") if (defined $three{$file});
	print "\n";

	my $input;
	if ($file_added_on_only_one_branch) {
		$input = prompt("Add or remove " . colored($file, 'green' ) . " (or skip/quit)?", "AaRrSsQq", "a");
		last if $input =~ /^[Qq]/;
		if ($input =~ /^[Rr]/) {
			system("git", "rm", $file);
			next;
		} elsif ($input =~ /^[Aa]/) {
			system("git", "add", $file);
			next;
		} elsif ($input =~ /^[Ss]/) {
			next;
		}
	}
	if ($file_removed == 2) {
		$input = prompt("Remove or add from ${three_descr} " . colored($file, 'green' ) . " (or skip/quit)?", "RrAaSsQq", "?");  # No default choice
		last if $input =~ /^[Qq]/;
		if ($input =~ /^[Aa]/) {
			git_add_file_from_blob($file, $three{$file});
			next;
		} elsif ($input =~ /^[Rr]/) {
			system("git", "rm", $file);
			next;
		} elsif ($input =~ /^[Ss]/) {
			next;
		}
	} elsif ($file_removed) {
		$input = prompt("Remove " . colored($file, 'green' ) . " (or skip/quit)?", "RrSsQq", "r");
		last if $input =~ /^[Qq]/;
		if ($input =~ /^[Rr]/) {
			system("git", "rm", $file);
			next;
		} elsif ($input =~ /^[Ss]/) {
			next;
		}
	}

	my $override = "";
	$override = $override . "1" if defined $one{$file};
	$override = $override . "2" if defined $two{$file};
	$override = $override . "3" if defined $three{$file};
	$input = prompt("Launch kdiff3 for " . colored($file, 'green' ) . "?", "YyNnQq$override", "y");
	last if $input =~ /^[Qq]/;
	next if $input =~ /^[Nn]/;

	if ($input =~ /^[1]/ && defined $one{$file}) {
		git_add_file_from_blob($file, $one{$file});
		next;
	}
	if ($input =~ /^[2]/ && defined $two{$file}) {
		git_add_file_from_blob($file, $two{$file});
		next;
	}
	if ($input =~ /^[3]/ && defined $three{$file}) {
		git_add_file_from_blob($file, $three{$file});
		next;
	}

	my @input_files = ();
	push @input_files, blob2file($file, $one{$file}  ) if defined $one{$file};
	push @input_files, blob2file($file, $two{$file}  ) if defined $two{$file};
	push @input_files, blob2file($file, $three{$file}) if defined $three{$file};
	system("kdiff3", "-o", "$file.merged", @input_files);
	unlink(@input_files);

	$input = prompt("Update " . colored($file, 'green' ) . " with merge result?", "YyNnQq", "y");
	unlink("$file.merged") unless $input =~ /^[Yy]/;
	last if $input =~ /^[Qq]/;
	next if $input =~ /^[Nn]/;

	system("mv", "$file.merged", $file);
	system("git", "add", $file);

}

print_continue_commands($git_dir);

