# --
# Kernel/Modules/AdminPGP.pm - to add/update/delete pgp keys
# Copyright (C) 2001-2005 Martin Edenhofer <martin+code@otrs.org>
# --
# $Id: AdminPGP.pm,v 1.8 2005-02-16 16:49:13 martin Exp $
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see http://www.gnu.org/licenses/gpl.txt.
# --

package Kernel::Modules::AdminPGP;

use strict;
use Kernel::System::Crypt;

use vars qw($VERSION);
$VERSION = '$Revision: 1.8 $';
$VERSION =~ s/^\$.*:\W(.*)\W.+?$/$1/;

# --
sub new {
    my $Type = shift;
    my %Param = @_;

    # allocate new hash for object
    my $Self = {};
    bless ($Self, $Type);

    # get common opjects
    foreach (keys %Param) {
        $Self->{$_} = $Param{$_};
    }

    # check all needed objects
    foreach (qw(ParamObject DBObject LayoutObject ConfigObject LogObject)) {
        die "Got no $_" if (!$Self->{$_});
    }

    $Self->{CryptObject} = Kernel::System::Crypt->new(%Param, CryptType => 'PGP');

    return $Self;
}
# --
sub Run {
    my $Self = shift;
    my %Param = @_;
    my $Output = '';
    $Param{Search} = $Self->{ParamObject}->GetParam(Param => 'Search');
    if (!defined($Param{Search})) {
        $Param{Search} = $Self->{PGPSearch} || '';
    }
    if ($Self->{Subaction} eq '' ) {
        $Param{Search} = '';
    }
    if ($Self->{Subaction} eq '' ) {
        $Param{Search} = '';
    }
    $Self->{SessionObject}->UpdateSessionID(
        SessionID => $Self->{SessionID},
        Key => 'PGPSearch',
        Value => $Param{Search},
    );

    # delete key
    if ($Self->{Subaction} eq 'Delete') {
        my $Key = $Self->{ParamObject}->GetParam(Param => 'Key') || '';
        my $Type = $Self->{ParamObject}->GetParam(Param => 'Type') || '';
        if (!$Key) {
            my $Output .= $Self->{LayoutObject}->Header(Title => 'Error');
            $Output .= $Self->{LayoutObject}->Error(
                Message => 'Need param Key to delete!',
            );
            $Output .= $Self->{LayoutObject}->Footer();
            return $Output;
        }
        my $Message = '';
        if ($Type eq 'sec') {
            $Message = $Self->{CryptObject}->SecretKeyDelete(Key => $Key);
        }
        else {
            $Message = $Self->{CryptObject}->PublicKeyDelete(Key => $Key);
        }
        if (!$Message) {
            $Message = $Self->{LogObject}->GetLogEntry(
                Type => 'Error',
                What => 'Message',
            );
        }
        my @List = $Self->{CryptObject}->KeySearch(Search => $Param{Search});
        foreach my $Key (@List) {
            $Self->{LayoutObject}->Block(
                Name => 'Row',
                Data => {
                    StartFont => '<font color ="red">',
                    StopFont => '</font>',
                    %{$Key},
                },
            );
        }
        my $Output = $Self->{LayoutObject}->Header(Area => 'Admin', Title => 'PGP Key Management');
        $Output .= $Self->{LayoutObject}->NavigationBar();
        if (!$Message) {
            $Message = "Key $Key deleted!";
        }
        $Output .= $Self->{LayoutObject}->Notify(Info => $Message);
        $Output .= $Self->{LayoutObject}->Output(TemplateFile => 'AdminPGPForm', Data => \%Param);
        $Output .= $Self->{LayoutObject}->Footer();
        return $Output;
    }
    # add key
    elsif ($Self->{Subaction} eq 'Add') {
        $Self->{SessionObject}->UpdateSessionID(
            SessionID => $Self->{SessionID},
            Key => 'PGPSearch',
            Value => '',
        );
        my %UploadStuff = $Self->{ParamObject}->GetUploadAll(
            Param => 'file_upload',
            Source => 'String',
        );
        if (!%UploadStuff) {
            my $Output .= $Self->{LayoutObject}->Header(Title => 'Error');
            $Output .= $Self->{LayoutObject}->Error(
                Message => 'Need Key!',
            );
            $Output .= $Self->{LayoutObject}->Footer();
            return $Output;
        }
        my $Message = $Self->{CryptObject}->KeyAdd(Key => $UploadStuff{Content});
        if (!$Message) {
            $Message = $Self->{LogObject}->GetLogEntry(
                Type => 'Error',
                What => 'Message',
            );
        }
        my @List = $Self->{CryptObject}->KeySearch(Search => $Param{Search});
        foreach my $Key (@List) {
            $Self->{LayoutObject}->Block(
                Name => 'Row',
                Data => {
                    StartFont => '<font color ="red">',
                    StopFont => '</font>',
                    %{$Key},
                },
            );
        }
        my $Output = $Self->{LayoutObject}->Header(Area => 'Admin', Title => 'PGP Key Management');
        $Output .= $Self->{LayoutObject}->NavigationBar();
        $Output .= $Self->{LayoutObject}->Notify(Info => $Message);
        $Output .= $Self->{LayoutObject}->Output(TemplateFile => 'AdminPGPForm', Data => \%Param);
        $Output .= $Self->{LayoutObject}->Footer();
        return $Output;
    }
    # download key
    elsif ($Self->{Subaction} eq 'Download') {
        my $Key = $Self->{ParamObject}->GetParam(Param => 'Key') || '';
        my $Type = $Self->{ParamObject}->GetParam(Param => 'Type') || '';
        if (!$Key) {
            my $Output .= $Self->{LayoutObject}->Header(Title => 'Error');
            $Output .= $Self->{LayoutObject}->Error(
                Message => 'Need param Key to download!',
            );
            $Output .= $Self->{LayoutObject}->Footer();
            return $Output;
        }
        my $KeyString = '';
        if ($Type eq 'sec') {
            $KeyString = $Self->{CryptObject}->SecretKeyGet(Key => $Key);
        }
        else {
            $KeyString = $Self->{CryptObject}->PublicKeyGet(Key => $Key);
        }
        return $Self->{LayoutObject}->Attachment(
            ContentType => 'text/plain',
            Content => $KeyString,
            Filename => "$Key.asc",
            Type => 'inline',
        );
    }
    # download key
    elsif ($Self->{Subaction} eq 'DownloadFingerprint') {
        my $Key = $Self->{ParamObject}->GetParam(Param => 'Key') || '';
        my $Type = $Self->{ParamObject}->GetParam(Param => 'Type') || '';
        if (!$Key) {
            my $Output .= $Self->{LayoutObject}->Header(Title => 'Error');
            $Output .= $Self->{LayoutObject}->Error(
                Message => 'Need param Key to download!',
            );
            $Output .= $Self->{LayoutObject}->Footer();
            return $Output;
        }
        my $Download = '';
        if ($Type eq 'sec') {
            my @Result = $Self->{CryptObject}->PrivateKeySearch(Search => $Key);
            if ($Result[0]) {
                $Download = $Result[0]->{Fingerprint};
            }
        }
        else {
            my @Result = $Self->{CryptObject}->PublicKeySearch(Search => $Key);
            if ($Result[0]) {
                $Download = $Result[0]->{Fingerprint};
            }
        }
        return $Self->{LayoutObject}->Attachment(
            ContentType => 'text/plain',
            Content => $Download,
            Filename => "$Key.txt",
            Type => 'inline',
        );
    }
    # search key
    else {
        my @List = $Self->{CryptObject}->KeySearch(Search => $Param{Search});
        foreach my $Key (@List) {
            $Self->{LayoutObject}->Block(
                Name => 'Row',
                Data => {
                    StartFont => '<font color ="red">',
                    StopFont => '</font>',
                    %{$Key},
                },
            );
        }
        $Output .= $Self->{LayoutObject}->Header(Area => 'Admin', Title => 'PGP Key Management');
        $Output .= $Self->{LayoutObject}->NavigationBar();
        $Output .= $Self->{LayoutObject}->Output(TemplateFile => 'AdminPGPForm', Data => \%Param);
        $Output .= $Self->{LayoutObject}->Footer();
    }
    return $Output;
}
# --
1;
