#!/usr/bin/perl

############################ LICENSE #################################################
## F5 Config backup script. Perl script to manage daily backups of F5 BigIP devices
## Copyright (C) 2013 Eric Flores
##
## This program is free software; you can redistribute it and/or
## modify it under the terms of the GNU General Public License
## as published by the Free Software Foundation; either version 2
## of the License, or any later version.
##
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with this program; if not, write to the Free Software
## Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#####################################################################################

# F5 Config backup 2.1 - Changed to subroutine format
# Version 2.1.1 -
# 	Added Name/IP format to device list w/ comment and empty line exclusion
#
# Features to add -
#	Separate config item for log archive
#	Separate directory for device archive
#	Fix time localization

use strict;
use warnings;
use DateTime;
use Net::OpenSSH;
use Config::Tiny;

# Input variable check
if (! defined($ARGV[0])) {
	print "No config file defined!\n";
	print "Syntax: f5backup.pl [config_file]\n\n";
	exit;
} elsif ($ARGV[0] eq "-h" || $ARGV[0] eq "--help") {
	print "Syntax: f5backup.pl [config_file]\n\n";
	exit;
};

# Get contents of config file
my $config = Config::Tiny->read($ARGV[0]);

# Set VAR of config elements
my $DIR = $config->{_}->{DIRECTORY};
my $ARCHIVE_SIZE = $config->{_}->{ARCHIVE_SIZE};
my $DEVICE_LIST = $config->{_}->{DEVICE_LIST};
my $SSH_KEY = $config->{_}->{SSH_KEY};
my $ERROR = 0;

# Set date
my $DATE = DateTime->now->ymd("-");

########################## DEFINE SUBS #####################################

############################################################################
# ParseNameIP - Parse name & IP from device list
# my ($NAME,$IP) = ParseNameIP $_;
############################################################################
sub ParseNameIP {
	my $element = $_[0];
	my ($name,$ip) = ("","");
	if ($element =~ "=") {
		($name,$ip) = split("=",$element);
	} else {
		($name,$ip) = ($element,$element);
	};
	return $name,$ip
};

############################################################################
# CreateDeviceDIR - Make a new device folder if does not exist
# CreateDeviceDIR [DEVICE];
############################################################################
sub CreateDeviceDIR {
	my ($DEVICE) = (@_);
	unless (opendir(DIRECTORY,"$DIR/devices/$DEVICE")) {
		print LOG "Device directory $DIR/devices/$DEVICE does not exist. Creating folder $DEVICE at ",DateTime->now->hms,".\n";
		my $NEW_DIR = "$DIR/devices/$DEVICE";
		unless (mkdir $NEW_DIR,0755) {
			print LOG "Error: Cannot create folder $DEVICE - $!.\n" ;
			$ERROR++;
			next;
		};
		undef $NEW_DIR;
	};
};

############################################################################
# GetHash - Get the config hash from device
# my $NEW_HASH = GetHash([device],[ssh_handle]);
############################################################################
sub GetHash {
	my ($DEVICE,$SSH) = (@_);
	my ($HASH,$errput) = $SSH->capture2("tmsh list | sha1sum | cut -d ' ' -f1");
	chomp ($HASH,$errput);
	if (length($errput) != 0) { 
		print LOG "Error: Get hash failed for $DEVICE: $errput.\n" ;
		$ERROR++;
		next ;
	};
	print LOG "Hash for $DEVICE is - $HASH.\n";
	undef $errput;
	return $HASH
};

############################################################################
# CreateUCS - Creates UCS file on device
# CreateUCS([device],[ssh_handle]);
############################################################################
sub CreateUCS {
	my ($DEVICE,$SSH) = (@_);
	print LOG "Hashes do not match for $DEVICE at ",DateTime->now->hms,". Downloading backup file.\n";
	my ($output,$errput) = $SSH->capture2("tmsh save sys ucs /shared/tmp/backup.ucs");
	chomp ($output,$errput);
	print LOG "Making device create UCS - $errput.\n" ;
	undef $output;
};

############################################################################
# GetUCS - Download UCS file from device
# GetUCS([device],[ssh_handle]);
############################################################################
sub GetUCS {
	my ($DEVICE,$SSH) = (@_);
	print LOG "Downloading UCS file at ",DateTime->now->hms,".\n";
	my $UCS_FILE = "$DIR/devices/$DEVICE/$DATE-$DEVICE-backup.ucs";
	$SSH->scp_get({},'/shared/tmp/backup.ucs',$UCS_FILE);
	if (length($SSH->error) > 1) {
		print LOG "Error: UCS file download failed - ",$SSH->error, ".\n" ;
		$ERROR++;
		next;
	};
};

############################################################################
# WriteHASH - write new hash to file
# WriteHash([device],[hash]);
############################################################################
sub WriteHash {
	my ($DEVICE,$HASH) = (@_);
	print LOG "Overwriting old hash file at ",DateTime->now->hms,".\n";
	if (open(HASH,"+>$DIR/devices/$DEVICE/backup-hash")) {
		print HASH $HASH ;
		close HASH;
	} else {
		print LOG "Error: Could not write new hash file for $DEVICE - $! .\n" ;
		$ERROR++;
	};
};

############################################################################
# CleanArchive - Delete old archive files
# CleanArchive [DEVICE_LIST];
############################################################################
sub CleanArchive {
	my @DEVICES = @_;
	foreach (@DEVICES) {
		my $DEVICE = $_;
		if (opendir(DIRECTORY,"$DIR/devices/$DEVICE")) { 
			my @DIRECTORY = readdir(DIRECTORY);
			@DIRECTORY = reverse sort grep(/backup.ucs/,@DIRECTORY); 
			foreach (@DIRECTORY[$ARCHIVE_SIZE..($#DIRECTORY)]) {
				print LOG "Deleting backup file at ",DateTime->now->hms,": $DEVICE/$_.\n" ;
				unlink ("$DIR/devices/$DEVICE/$_") or print LOG "Error: Cannot delete $DIR/devices/$DEVICE/$_ - $!.\n" and $ERROR++;
			};
			closedir DIRECTORY;
		} else {
			print LOG "Error: Can not open directory $DIR/devices/$DEVICE/ - $!.\n" ;
			$ERROR++ ;
			next;
		};
	};
};

############################################################################
# CleanLogs - Delete old log files
############################################################################
sub CleanLogs {
	if (opendir(DIRECTORY,"/var/f5backup/log/")) {
		my @DIRECTORY = readdir(DIRECTORY);
		@DIRECTORY = reverse sort grep(/backup.log/,@DIRECTORY);
		foreach (@DIRECTORY[$ARCHIVE_SIZE..($#DIRECTORY)]) {
			print LOG "Deleting log file at ",DateTime->now->hms,": $_.\n" ;
			unlink("$DIR/log/$_") or print LOG "Error: Cannot delete $DIR/log/$_ - $!.\n" and $ERROR++;
		};
		closedir DIRECTORY;
	} else {
		print LOG "Error: Can not open log directory: $!.\n" ;
		$ERROR++;
	};
};

############################################################################################
# *************************************** MAIN PROGRAM *************************************
############################################################################################

# Open files/arrays for logging
open LOG,"+>$DIR/log/$DATE-backup.log";
print LOG "Starting configuration backup on $DATE at ",DateTime->now->hms,".\n";

# Open device list, set into array, exclude commented and empty lines, remove LF
open DEVICE_LIST,"<$DIR/$DEVICE_LIST" or die "Cannot open device list - $!.\n";
my @DEVICE_LIST = <DEVICE_LIST>;
@DEVICE_LIST = grep (!(/#/|/^\n/),@DEVICE_LIST);
chomp(@DEVICE_LIST);


# Loop though device list
foreach (@DEVICE_LIST) {
	# Parse name=ip from device list
	my ($NAME,$IP) = ParseNameIP $_;

	print LOG "\nConnecting to $NAME at ",DateTime->now->hms,".\n";

	# Create device folder is it does not exist
	CreateDeviceDIR $NAME;

	# Open SSH connection to host
	my $ssh = Net::OpenSSH->new($IP,
		user=>'root',
		key_path=>$SSH_KEY,
		master_stderr_discard => 1,
		timeout => 5,
	);
	if (length($ssh->error) > 1) {
		print LOG "Error at ",DateTime->now->hms,": Can't connect to $NAME - ",$ssh->error, ".\n" ;
		$ERROR++ ;
		next;
	};

	# get hash from device and write to VAR
	my $NEW_HASH = GetHash($NAME,$ssh);

	# Check for new hash and break if it does not exist
	if (! defined($NEW_HASH) || length $NEW_HASH != 40) {
		print LOG "Get HASH failed for $NAME at ",DateTime->now->hms,". Skipping to next device.\n";
		$ERROR++;
		next;
	};

	# Check for old hash. if not present the set OLD_HASH to null
	my $OLD_HASH = "";
	if (open DEVICE_HASH,"<$DIR/devices/$NAME/backup-hash") {
		$OLD_HASH = <DEVICE_HASH> ;
		close DEVICE_HASH;
	};

	# Compare old hash to new hash
	if ($OLD_HASH eq $NEW_HASH) {
		print LOG "Hashes match for $NAME at ",DateTime->now->hms,". Configuration unchanged. Skipping download.\n";
	} else {
		# Make device create UCS file, Download UCS file, Disconnect SSH session, Write new hash to file
		CreateUCS($NAME,$ssh);
		GetUCS($NAME,$ssh);
		undef $ssh;
		WriteHash($NAME,$NEW_HASH);
	};
};

#  Add deletion note to log file
print LOG "\nDeleting old files:\n";

# Keep only the number of UCS files specified by ARCHIVE_SIZE and write deletion to log
CleanArchive @DEVICE_LIST;

# Keep only the number of log files specified by ARCHIVE_SIZE and write deletion to log
CleanLogs;

# Check number of errors. Print line if > 0
print LOG "\nThere is $ERROR error(s).\n" if ($ERROR > 0);

# All done
print LOG "\nBackup job completed.\n";
close LOG;
