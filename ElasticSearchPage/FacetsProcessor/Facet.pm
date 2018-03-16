use Modern::Perl;

package ElasticSearchPage::FacetsProcessor::Facet;
use parent 'ElasticSearchPage::Base';

#require Exporter;
#our @ISA = qw(Exporter);
#our @EXPORT = qw();

sub new  {
    my ($class, $params) = @_;
    my $self = {};
    bless $self, $class;
    $self->_initialize($params);
    return $self;
}

sub _initialize {
    my ($self, $params) = @_;
    # @TODO: Proper error handling, croak is probably enough
    die('Missing parameter: "operator"') unless exists $params->{operator};
    die('Missing parameter: "namespace"') unless exists $params->{namespace};
    die('Missing parameter: "field"') unless exists $params->{field};
    $self->{namespace} = $params->{namespace};
    $self->{operator} = $params->{operator};
    $self->{field} = $params->{field};
    $self->{meta} = $params->{meta} if (exists $params->{meta});
    $self->{label} = $params->{meta} if (exists $params->{label});
    $self->{sort} //= [[count => 'asc']]; # count/(display_value/label?)/indexed_value
    # elastic_aggregation_options? raw_options, raw?
    $self->{elastic_options} //= {};
    $self->_validate_elastic_options($params->{elastic_options});
}

sub transferable_properies {
    my ($self) = @_;
    return ('meta');
}

sub namespace {
    my ($self) = @_;
    return $self->{namespace};
}

sub field {
    my ($self) = @_;
    return $self->{field};
}

sub operator {
    my ($self) = @_;
    return $self->{operator};
}

sub bucket_label {
    my ($self, $bucket) = @_;
    return undef;
}

sub processed_facet_properties {
    my ($self) = @_;
    my $properties = {};
    foreach my $property ($self->transferable_properies) {
        if (exists $self->{$property}) {
            $properties->{$property} = $self->{$property};
        }
    }
    return $properties;
}

sub _validate_elastic_options {}

1;
