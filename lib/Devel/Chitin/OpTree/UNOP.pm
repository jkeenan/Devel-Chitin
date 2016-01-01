package Devel::Chitin::OpTree::UNOP;
use base 'Devel::Chitin::OpTree';

use Devel::Chitin::Version;

use strict;
use warnings;

sub first {
    shift->{children}->[0];
}

sub pp_leavesub {
    my $self = shift;
    $self->first->deparse;
}


# Normally, pp_list is a LISTOP, but this happens when a pp_list is turned
# into a pp_null by the optimizer, and it has one child
sub pp_list {
    my $self = shift;
    $self->first->deparse;
}

sub pp_srefgen {
    my $self = shift;
    '\\' . $self->first->deparse;
}

sub pp_rv2sv {
    my $self = shift;
    '$' . $self->first->deparse;
}

sub pp_rv2av {
    my $self = shift;
    '@' . $self->first->deparse;
}

sub pp_rv2hv {
    my $self = shift;
    '%' . $self->first->deparse;
}

sub pp_rv2cv {
    my $self = shift;
    $self->first->deparse;
}

sub pp_entersub {
    my $self = shift;

    my @params_ops;
    if ($self->first->op->flags & B::OPf_KIDS) {
        # normal sub call
        # first is a pp_list containing a pushmark, followed by the arg
        # list, followed by the sub name
        (undef, @params_ops) = @{ $self->first->children };

    } elsif ($self->first->op->name eq 'pushmark') {
        # method call
        # the args are children of $self: a pushmark, invocant, then args, then method_named() with the method name
        (undef, undef, @params_ops) = @{ $self->children };

    } else {
        die "unknown entersub";
    }
    my $sub_name_op = pop @params_ops;

print "There are ", scalar(@params_ops)," children: ",join(', ', map { $_->op->name } @params_ops),"\n";

    return _deparse_sub_invocation($sub_name_op)
            . '( '
                . join(', ', map { $_->deparse } @params_ops)
            . ' )';
}

sub _deparse_sub_invocation {
    my $op = shift;

    my $op_name = $op->op->name;
    if ($op_name eq 'rv2cv'
        or
        ( $op->is_null and $op->_ex_name eq 'pp_rv2cv' )
    ) {
        # subroutine call

        if ($op->first->op->name eq 'gv') {
            # normal sub call: Some::Sub::named(...)
            $op->deparse;
        } else {
            # subref call
            $op->deparse . '->';
        }

    } elsif ($op_name eq 'method_named') {
        join('->',  $op->parent->children->[1]->deparse(skip_quotes => 1),  # class
                    $op->deparse(skip_quotes => 1));

    } else {
        die "unknown sub invocation for $op_name";
    }
}

1;
