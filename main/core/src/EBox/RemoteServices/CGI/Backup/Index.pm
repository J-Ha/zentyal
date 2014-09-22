# Copyright (C) 2008-2014 Zentyal S.L.
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

use strict;
use warnings;

package EBox::RemoteServices::CGI::Backup::Index;
use base qw(EBox::CGI::ClientBase);

use TryCatch::Lite;


use EBox::Gettext;
use EBox::Global;
use EBox::Exceptions::Internal;
use EBox::Exceptions::External;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new('title' => __('Import/Export Configuration Remotely'),
                                  'template' => '/backupTabs.mas',
                                  @_);

    $self->setMenuNamespace('EBox/Backup');

    bless($self, $class);
    return $self;
}


sub optionalParameters
{
    return ['selected'];
}

sub actuate
{
    my ($self) = @_;

    my $remoteservices = EBox::Global->modInstance('remoteservices');
    my $subscribed = $remoteservices->subscriptionLevel() >= 0;
    if (not $subscribed) {
        if ($remoteservices->commercialEdition()) {
            $self->setChain('RemoteServices/Backup/Unsubscribed');
        } else {
            $self->setChain('RemoteServices/Community/Register');
        }
        return;
    }

    try {
        my $backup = $remoteservices->confBackupResource();
        $self->{backups} =  $backup->list();
    } catch ($e) {
        $self->setErrorFromException($e);
        $self->setChain('RemoteServices/Backup/NoConnection');
        return;
    }
}

sub masonParameters
{
    my ($self) = @_;
    my @params = ();

    my $backups = {};
    if (defined($self->{backups})) {
        $backups = $self->{backups};
    }

    push @params, (backups => $backups);

    my $global = EBox::Global->getInstance();
    my $remoteservices  = $global->modInstance('remoteservices');
    my $modulesChanged = grep { $global->modIsChanged($_) } @{ $global->modNames() };
    push @params, (modulesChanged => $modulesChanged);

    my $subscriptionLevel = $remoteservices->subscriptionLevel();
    push @params, (subscriptionLevel => $subscriptionLevel);


    return \@params;
}

1;
