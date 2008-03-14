# --
# Kernel/System/SLA.pm - all sla function
# Copyright (C) 2001-2008 OTRS AG, http://otrs.org/
# --
# $Id: SLA.pm,v 1.19 2008-03-14 14:33:02 mh Exp $
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see http://www.gnu.org/licenses/gpl-2.0.txt.
# --

package Kernel::System::SLA;

use strict;
use warnings;

use Kernel::System::CheckItem;
use Kernel::System::Valid;

use vars qw(@ISA $VERSION);
$VERSION = qw($Revision: 1.19 $) [1];

=head1 NAME

Kernel::System::SLA - sla lib

=head1 SYNOPSIS

All sla functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create a object

    use Kernel::Config;
    use Kernel::System::Log;
    use Kernel::System::DB;
    use Kernel::System::Service;

    my $ConfigObject = Kernel::Config->new();
    my $LogObject = Kernel::System::Log->new(
        ConfigObject => $ConfigObject,
    );
    my $DBObject = Kernel::System::DB->new(
        ConfigObject => $ConfigObject,
        LogObject    => $LogObject,
        MainObject   => $MainObject,
    );

    my $SLAObject = Kernel::System::SLA->new(
        ConfigObject => $ConfigObject,
        LogObject => $LogObject,
        DBObject => $DBObject,
    );

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for (qw(DBObject ConfigObject LogObject MainObject)) {
        $Self->{$_} = $Param{$_} || die "Got no $_!";
    }
    $Self->{CheckItemObject} = Kernel::System::CheckItem->new( %{$Self} );
    $Self->{ValidObject}     = Kernel::System::Valid->new( %{$Self} );

    return $Self;
}

=item SLAList()

return a hash list of slas

    my %SLAList = $SLAObject->SLAList(
        ServiceID => 1,  # (optional)
        Valid     => 0,  # (optional) default 1 (0|1)
        UserID    => 1,
    );

=cut

sub SLAList {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{UserID} ) {
        $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
        return;
    }

    # check valid param
    if ( !defined $Param{Valid} ) {
        $Param{Valid} = 1;
    }

    # quote
    $Param{UserID} = $Self->{DBObject}->Quote( $Param{UserID}, 'Integer' );

    # check ServiceID
    my $Where = '';
    if ( $Param{ServiceID} ) {
        $Param{ServiceID} = $Self->{DBObject}->Quote( $Param{ServiceID}, 'Integer' );
        $Where .= "WHERE service_id = $Param{ServiceID} ";
    }

    # add valid part
    if ( $Param{Valid} ) {
        if ($Where) {
            $Where .= "AND ";
        }
        else {
            $Where .= "WHERE ";
        }
        $Where .= "valid_id IN ( ${\(join ', ', $Self->{ValidObject}->ValidIDsGet())} )";
    }

    # ask database
    my %SLAList;
    $Self->{DBObject}->Prepare( SQL => "SELECT id, name FROM sla $Where", );
    while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
        $SLAList{ $Row[0] } = $Row[1];
    }

    return %SLAList;
}

=item SLAGet()

return a sla as hash

Return
    $SLAData{SLAID}
    $SLAData{ServiceID}
    $SLAData{Name}
    $SLAData{Calendar}
    $SLAData{FirstResponseTime}
    $SLAData{FirstResponseNotify}
    $SLAData{UpdateTime}
    $SLAData{UpdateNotify}
    $SLAData{SolutionTime}
    $SLAData{SolutionNotify}
    $SLAData{ValidID}
    $SLAData{Comment}
    $SLAData{CreateTime}
    $SLAData{CreateBy}
    $SLAData{ChangeTime}
    $SLAData{ChangeBy}

    my %SLAData = $SLAObject->SLAGet(
        SLAID  => 123,
        UserID => 1,
        Cache  => 1,  # (optional)
    );

=cut

sub SLAGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(SLAID UserID)) {
        if ( !$Param{$_} ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    if ( $Param{Cache} && $Self->{"Cache::SLAGet::$Param{SLAID}"} ) {
        return %{ $Self->{"Cache::SLAGet::$Param{SLAID}"} };
    }

    # quote
    for (qw(SLAID UserID)) {
        $Param{$_} = $Self->{DBObject}->Quote( $Param{$_}, 'Integer' );
    }

    # get sla from db
    my %SLAData = ();
    $Self->{DBObject}->Prepare(
        SQL =>
            "SELECT id, service_id, name, calendar_name, first_response_time, first_response_notify, "
            . "update_time, update_notify, solution_time, solution_notify, "
            . "valid_id, comments, create_time, create_by, change_time, change_by "
            . "FROM sla WHERE id = $Param{SLAID}",
        Limit => 1,
    );

    # fetch the result
    while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
        $SLAData{SLAID}               = $Row[0];
        $SLAData{ServiceID}           = $Row[1];
        $SLAData{Name}                = $Row[2];
        $SLAData{Calendar}            = $Row[3] || '';
        $SLAData{FirstResponseTime}   = $Row[4];
        $SLAData{FirstResponseNotify} = $Row[5];
        $SLAData{UpdateTime}          = $Row[6];
        $SLAData{UpdateNotify}        = $Row[7];
        $SLAData{SolutionTime}        = $Row[8];
        $SLAData{SolutionNotify}      = $Row[9];
        $SLAData{ValidID}             = $Row[10];
        $SLAData{Comment}             = $Row[11] || '';
        $SLAData{CreateTime}          = $Row[12];
        $SLAData{CreateBy}            = $Row[13];
        $SLAData{ChangeTime}          = $Row[14];
        $SLAData{ChangeBy}            = $Row[15];
    }

    # check sla
    if ( !$SLAData{SLAID} ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "No such SLAID ($Param{SLAID})!",
        );
        return;
    }

    # cache the data
    $Self->{"Cache::SLAGet::$Param{SLAID}"} = \%SLAData;

    return %SLAData;
}

=item SLALookup()

return a sla id, name and service_id

    my $SLAName = $SLAObject->SLALookup(
        SLAID => 123,
    );

    or

    my $SLAID = $SLAObject->SLALookup(
        Name => 'SLA Name',
    );

=cut

sub SLALookup {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{SLAID} && !$Param{Name} ) {
        $Self->{LogObject}->Log( Priority => 'error', Message => "Need SLAID or Name!" );
        return;
    }

    if ( $Param{SLAID} ) {

        # check cache
        if ( $Self->{"Cache::SLALookup::ID::$Param{SLAID}"} ) {
            return $Self->{"Cache::SLALookup::ID::$Param{SLAID}"};
        }

        # quote
        $Param{SLAID} = $Self->{DBObject}->Quote( $Param{SLAID}, 'Integer' );

        # lookup
        $Self->{DBObject}->Prepare(
            SQL   => "SELECT name FROM sla WHERE id = $Param{SLAID}",
            Limit => 1,
        );

        # fetch the result
        my $Name;
        while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
            $Name = $Row[0];
        }

        # cache
        $Self->{"Cache::SLALookup::ID::$Param{SLAID}"} = $Name;

        return $Name;
    }
    else {

        # check cache
        if ( $Self->{"Cache::SLALookup::Name::$Param{Name}"} ) {
            return $Self->{"Cache::SLALookup::Name::$Param{Name}"};
        }

        # quote
        $Param{Name} = $Self->{DBObject}->Quote( $Param{Name} );

        # lookup
        $Self->{DBObject}->Prepare(
            SQL   => "SELECT id FROM sla WHERE name = '$Param{Name}'",
            Limit => 1,
        );

        # fetch the result
        my $ID;
        while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
            $ID = $Row[0];
        }

        # cache
        $Self->{"Cache::SLALookup::Name::$Param{Name}"} = $ID;

        return $ID;
    }
}

=item SLAAdd()

add a sla

    my $SLAID = $SLAObject->SLAAdd(
        ServiceID           => 1,
        Name                => 'Service Name',
        Calendar            => 'Calendar1',  # (optional)
        FirstResponseTime   => 120,          # (optional)
        FirstResponseNotify => 60,           # (optional) notify agent if first response escalation is 60% reached
        UpdateTime          => 180,          # (optional)
        UpdateNotify        => 80,           # (optional) notify agent if update escalation is 80% reached
        SolutionTime        => 580,          # (optional)
        SolutionNotify      => 80,           # (optional) notify agent if solution escalation is 80% reached
        ValidID             => 1,
        Comment             => 'Comment',    # (optional)
        UserID              => 1,
    );

=cut

sub SLAAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ServiceID Name ValidID UserID)) {
        if ( !$Param{$_} ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }
    for (qw(Calendar Comment)) {
        $Param{$_} ||= '';
    }

    # check escalation times
    for (
        qw(FirstResponseTime FirstResponseNotify UpdateTime UpdateNotify SolutionTime SolutionNotify)
        )
    {
        $Param{$_} ||= 0;
    }

    # quote
    for (qw(Name Calendar Comment)) {
        $Param{$_} = $Self->{DBObject}->Quote( $Param{$_} );
    }
    for (
        qw(ServiceID FirstResponseTime FirstResponseNotify UpdateTime UpdateNotify SolutionTime SolutionNotify ValidID UserID)
        )
    {
        $Param{$_} = $Self->{DBObject}->Quote( $Param{$_}, 'Integer' );
    }

    # cleanup given params
    for my $Argument (qw(Name Comment)) {
        $Self->{CheckItemObject}->StringClean(
            StringRef         => \$Param{$Argument},
            RemoveAllNewlines => 1,
            RemoveAllTabs     => 1,
        );
    }

    # add sla to database
    my $Success = $Self->{DBObject}->Do(
        SQL => "INSERT INTO sla "
            . "(service_id, name, calendar_name, first_response_time, first_response_notify, "
            . "update_time, update_notify, solution_time, solution_notify, "
            . "valid_id, comments, create_time, create_by, change_time, change_by) VALUES "
            . "($Param{ServiceID}, '$Param{Name}', '$Param{Calendar}', $Param{FirstResponseTime}, "
            . "$Param{FirstResponseNotify}, $Param{UpdateTime}, $Param{UpdateNotify}, "
            . "$Param{SolutionTime}, $Param{SolutionNotify}, $Param{ValidID}, '$Param{Comment}', "
            . "current_timestamp, $Param{UserID}, current_timestamp, $Param{UserID})",
    );

    return if !$Success;

    # get sla id
    $Self->{DBObject}->Prepare(
        SQL   => "SELECT id FROM sla WHERE name = '$Param{Name}'",
        Limit => 1,
    );

    # fetch the result
    my $SLAID;
    while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
        $SLAID = $Row[0];
    }

    return $SLAID;
}

=item SLAUpdate()

update a existing sla

    my $True = $SLAObject->SLAUpdate(
        SLAID               => 2,
        ServiceID           => 1,
        Name                => 'Service Name',
        Calendar            => 'Calendar1',  # (optional)
        FirstResponseTime   => 120,          # (optional)
        FirstResponseNotify => 60,           # (optional) notify agent if first response escalation is 60% reached
        UpdateTime          => 180,          # (optional)
        UpdateNotify        => 80,           # (optional) notify agent if update escalation is 80% reached
        SolutionTime        => 580,          # (optional)
        SolutionNotify      => 80,           # (optional) notify agent if solution escalation is 80% reached
        ValidID             => 1,
        Comment             => 'Comment',    # (optional)
        UserID              => 1,
    );

=cut

sub SLAUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(SLAID ServiceID Name ValidID UserID)) {
        if ( !$Param{$_} ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    # reset cache
    delete $Self->{"Cache::SLAGet::$Param{SLAID}"};
    delete $Self->{"Cache::SLALookup::Name::$Param{Name}"};
    delete $Self->{"Cache::SLALookup::ID::$Param{SLAID}"};

    # set default values
    for (qw(Calendar Comment)) {
        $Param{$_} ||= '';
    }

    # check escalation times
    for (
        qw(FirstResponseTime FirstResponseNotify UpdateTime UpdateNotify SolutionTime SolutionNotify)
        )
    {
        $Param{$_} ||= 0;
    }

    # quote
    for (qw(Name Calendar Comment)) {
        $Param{$_} = $Self->{DBObject}->Quote( $Param{$_} );
    }
    for (
        qw(ServiceID FirstResponseTime FirstResponseNotify UpdateTime UpdateNotify SolutionTime SolutionNotify ValidID UserID)
        )
    {
        $Param{$_} = $Self->{DBObject}->Quote( $Param{$_}, 'Integer' );
    }

    # cleanup given params
    for my $Argument (qw(Name Comment)) {
        $Self->{CheckItemObject}->StringClean(
            StringRef         => \$Param{$Argument},
            RemoveAllNewlines => 1,
            RemoveAllTabs     => 1,
        );
    }

    # update service
    return $Self->{DBObject}->Do(
        SQL => "UPDATE sla SET service_id = $Param{ServiceID}, name = '$Param{Name}', "
            . "calendar_name = '$Param{Calendar}', "
            . "first_response_time = $Param{FirstResponseTime}, first_response_notify = $Param{FirstResponseNotify}, "
            . "update_time = $Param{UpdateTime}, update_notify = $Param{UpdateNotify}, "
            . "solution_time = $Param{SolutionTime}, solution_notify = $Param{SolutionNotify}, "
            . "valid_id = $Param{ValidID}, "
            . "comments = '$Param{Comment}', change_time = current_timestamp, change_by = $Param{UserID} "
            . "WHERE id = $Param{SLAID}",
    );
}

1;

=back

=head1 TERMS AND CONDITIONS

This Software is part of the OTRS project (http://otrs.org/).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (GPL). If you
did not receive this file, see http://www.gnu.org/licenses/gpl-2.0.txt.

=cut

=head1 VERSION

$Revision: 1.19 $ $Date: 2008-03-14 14:33:02 $

=cut
