package Pod::Weaver::Role::ReplaceRegion;

use 5.010001;
use Moose::Role;

use Encode qw(decode encode);
#use Pod::Elemental;
use Pod::Elemental::Element::Nested;

# AUTHORITY
# DATE
# DIST
# VERSION

sub replace_region {
    my ($self, $document, $format_name, $region_content, $text, $opts) = @_;

    $opts //= {};
    $opts->{ignore} //= 0;

    # convert characters to bytes, which is expected by read_string()
    $text = encode('UTF-8', $text, Encode::FB_CROAK);

    my $text_elem = Pod::Elemental->read_string($text);

    # dump document
    #use DD; dd $document->children;
    #say $document->as_debug_string;
    #say $document->as_pod_string;

    # find the wanted region below root
    my $region_elem;
    my $region_elem_pos;
    my $section_elem_before_region;
    {
        my $i = -1;
        for my $elem (@{ $document->children }) {
            $i++;
            if ($elem->can('command')) {
                $section_elem_before_region = $elem;
            }
            $self->log_debug(["Found element $elem"]);
            unless ($elem->isa('Pod::Elemental::Element::Pod5::Region')) {
                $self->log_debug(["Skipping element because it is not a Pod5 region element"]);
                next;
            }
            unless ($elem->format_name eq $format_name) {
                $self->log_debug(["Skipping Pod5 region element because format name (%s) is not what we want (%s)", $elem->format_name, $format_name]);
                next;
            }
            if (ref $region_content eq 'Regexp') {
                unless ($elem->as_pod_string =~ $region_content) {
                    $self->log_debug(["Skipping Pod5 region element because content (%s) is not what we want (%s)", $elem->as_pod_string, $region_content]);
                    next;
                }
            } else {
                unless ($elem->as_pod_string eq $region_content) {
                    $self->log_debug(["Skipping Pod5 region element because content (%s) is not what we want (%s)", $elem->as_pod_string, $region_content]);
                    next;
                }
            }

            $region_elem_pos = $i;
            $region_elem = $elem;
            last;
        }
    }
    if (!$region_elem) {
        if ($opts->{ignore}) {
            $self->log_debug(["Can't find POD region named '$format_name', ignoring"]);
            return;
        } else {
            die "Can't find POD region named '$format_name' in POD document";
        }
    }

    if ($section_elem_before_region) {
        push @{ $section_elem_before_region->children }, @{ $text_elem->children };
        splice @{ $document->children }, $region_elem_pos, 1;
    } else {
        splice @{ $document->children }, $region_elem_pos, 1, @{ $text_elem->children };
    }

    return 1;
}

no Moose::Role;
1;
# ABSTRACT: Replace a POD region with a text

=head1 SYNOPSIS

Sample document:

 =head1 SYNOPSIS

 =for MyModule usage

 =head1 DESCRIPTION

 blah...

Sample code:

 my $usage_text = <<EOT;
 Usage: B<prog> [options]

 _;

 $self->replace_region($document, 'MyModule', 'usage', $usage_text);


=head1 DESCRIPTION


=head1 METHODS

=head2 replace_region

Usage:

 $obj->add_text_to_section($document, $format_name, $region_content, $text [, \%opts]) => bool

Replace POD5 region (a C<=for ...> line or C<=begin ... =end> set of lines) in
document C<$document> named C<$format_name> with content C<$region_content>
(string or Regexp object) and replace it with string C<$text>.

Options:

=over

=item * ignore

Bool. Default false. If set to true, then if POD5 region is not found, will
not die with error but do nothing.

=back
