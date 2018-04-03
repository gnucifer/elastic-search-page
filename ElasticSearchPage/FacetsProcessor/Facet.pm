package ElasticSearchPage::FacetsProcessor::Facet;

use Moo;
use strictures 2;
use namespace::clean;

use Modern::Perl;
use Specio::Library::Builtins;

# Role for this!?

my $str = t('Str');

# TODO: Add required

has namespace => (
    is => 'ro',
    isa => $str,
    required => 1,
);

# TODO: Change to enum?
has operator => (
    is => 'ro',
    isa => $str,
    required => 1,
);

# Not all facets has field! Should be role instead!?
has field => (
    is => 'ro',
    isa => $str,
    required => 1,
);

has meta => (
    is => 'ro',
    isa => t('Item'),
);

has label => (
    is => 'ro',
    isa => $str,
);

# TODO: Custom type for this?
# Use touple type?
has sort => (
    is => 'ro',
    isa => t('ArrayRef', of => t('ArrayRef', of => $str)),
    default => sub { [[count => 'asc']]; },
);

# TODO: Should be better way for validation?
has elastic_options => (
    is => 'ro',
    isa => t('HashRef'),
    trigger => sub {
        my ($self, $options) = @_;
        $self->_validate_elastic_options($options);
    },
);

sub _transferable_properies {
    my ($self) = @_;
    return ('meta');
}

sub bucket_label {
    my ($self, $bucket) = @_;
    return undef;
}

sub processed_facet_properties {
    my ($self) = @_;
    my $properties = {};
    foreach my $property ($self->_transferable_properies) {
        #if ($self->can($property) && $self->$property) {
        # Hmmm??
        if (defined $self->$property) { # Hmm?? Or use predicate?
            $properties->{$property} = $self->$property;
        }
    }
    return $properties;
}

sub _validate_elastic_options {}

1;
