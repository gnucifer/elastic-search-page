use Modern::Perl;

package ElasticSearchPage::Processor;
use parent 'ElasticSearchPage::Base';

#require Exporter;
#our @ISA = qw(Exporter);
#our @EXPORT = qw();

# ** Abstract Class **
# TODO: Probably add _initialize to all classes
#sub new  {
#    my ($class, $params) = @_;
#    # Also check that is array and all items isa ElasticFacet
#    my $self = {};
#    $self->{namespace} = exists $params->{namespace} ? $params->{namespace} : $class::default_namespace();
#    #$params->{meta}; # Could contain "title" for example
#    return bless $self, $class;
#}
sub _initialize {
    my ($self, $params) = @_;
    $self->{namespace} = exists $params->{namespace} ?
        $params->{namespace} : $self->default_namespace;
}

# TODO: Perl idiom for abstract methods?
sub default_namespace {
    die("Not implemented");
}

# TODO: Perl idiom for abstract methods?
sub namespace {
    my ($self) = @_;
    return $self->{namespace};
}

sub elastic_request_body_alter {}
sub elastic_query_components { return undef; }

1;
