# Copyright (C) 2012 eBox Technologies S.L.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2, as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

package EBox::RemoteServices::Reporter::Base;

# Class: EBox::RemoteServices::Reporter::Base
#
#      Base class to perform the consolidation and send the result to
#      the cloud
#

use warnings;
use strict;

use EBox::Config;
use EBox::DBEngineFactory;
use EBox::Exceptions::NotImplemented;
use EBox::Global;
use File::Slurp;
use File::Temp;
use JSON::XS;
use Time::HiRes;

# Constants
use constant BASE_DIR => EBox::Config::conf() . 'remoteservices/reporter/';

# Group: Public methods

# Constructor
sub new
{
    my ($class) = @_;

    my $self = { db => EBox::DBEngineFactory::DBEngine() };
    bless($self, $class);
    return $self;
}

# Method: enabled
#
#     Return if the reporter helper is enabled or not to perform
#     consolidation.
#
#     Currently it checks whether the given module <module> exists or
#     not
#
sub enabled
{
    my ($self) = @_;

    my $gl = EBox::Global->getInstance();
    my $mod = $self->module();
    return 0 unless ($mod);

    return ($gl->modExists($mod));
}

# Method: module
#
#      Return the module the reporter requires to work
#
# Returns:
#
#      String - the module name
#
sub module
{
    return "";
}

# Method: name
#
#      The canonical name for the reporter
#
# Returns:
#
#      String - the canonical name
#
sub name
{
    throw EBox::Exceptions::NotImplemented();
}

# Method: timestampField
#
#      The timestamp field for the table to consolidate from
#
# Returns:
#
#      String - the timestamp field
#
sub timestampField
{
    return 'timestamp';
}

# Method: consolidate
#
#    Perform the consolidation given a range (begin, end)
#
#    The begin time is stored in name/times.json
#    The result is stored as name/rep-$time-XXX.json
#
#    Every subclass must implement <consolidate>
#
sub consolidate
{
    my ($self) = @_;

    my $beginTime = $self->_beginTime();
    my $endTime   = time();
    # TODO: Do not store all the result in a single var
    my $result = $self->_consolidate($beginTime, $endTime);
    $self->_storeResult($result);
    $self->_beginTime($endTime);
}

# Group: Protected methods

# Method: _consolidate
#
#      Consolidate the report data to the given range
#
#      The data must be splitted in hour frames
#
# Parameters:
#
#      begin - Int the begin time
#
#      end   - Int the end time
#
sub _consolidate
{
    throw EBox::Exceptions::NotImplemented();
}

# Method: _hourSQLStr
#
#    Return the SQL string as a function to truncate to hour
#
# Returns:
#
#    String - the hour SQL string
#
sub _hourSQLStr
{
    my ($self) = @_;

    my $timestampField = $self->timestampField();
    return "DATE_FORMAT($timestampField,"
           . q{'%y-%m-%d %H:00:00') AS hour};
}

# Method: _rangeSQLStr
#
#    Return the SQL string for the range in WHERE
#
# Parameters:
#
#    begin - Int the begin timestamp
#    end   - Int the end timestamp
#
# Returns:
#
#    String - the range SQL string
#
sub _rangeSQLStr
{
    my ($self, $begin, $end) = @_;

    my $timestampField = $self->timestampField();
    return "$timestampField >= FROM_UNIXTIME($begin) AND $timestampField <= FROM_UNIXTIME($end)";
}

# Method: _groupSQLStr
#
#    Return the SQL string for the GROUP BY
#
#    If you override this, make sure you override <_hourSQLStr> method
#    as well.
#
# Returns:
#
#    String - the GROUP BY SQL string
#
sub _groupSQLStr
{
    return 'hour'
}

# Group: Private methods

# The reporter sub dir
# Create it if it does not exist
sub _subdir
{
    my ($self) = @_;

    my $dirPath = BASE_DIR . $self->name() . '/';
    unless ( -d $dirPath ) {
        my $success = mkdir($dirPath);
        unless ( $success ) {
            EBox::Sudo::root('chown -R ebox:ebox ' . BASE_DIR);
            mkdir($dirPath);
        }
    }
    return $dirPath;
}

# Return the begin time
# If the file does not exist, then returns last month
# If a time is given, then it will be stored in that file
sub _beginTime
{
    my ($self, $time) = @_;

    my $filePath = $self->_subdir() . 'times.json';

    if (defined($time)) {
        File::Slurp::write_file($filePath, encode_json( { begin => $time } ));
    } else {
        if ( -r $filePath ) {
            my $fileContent = decode_json(File::Slurp::read_file($filePath));
            return $fileContent->{begin};
        } else {
            return time() - 30 * 24 * 60 * 60;
        }
    }
}

# Store the result in a file encoded in JSON
sub _storeResult
{
    my ($self, $result) = @_;

    my $dirPath = $self->_subdir();
    my $time = join("", Time::HiRes::gettimeofday());
    my $tmpFile = new File::Temp(TEMPLATE => "rep-$time-XXXX.json", DIR => $dirPath,
                                 UNLINK => 0);
    print $tmpFile encode_json($result);
}

1;
