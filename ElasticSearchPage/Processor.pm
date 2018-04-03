package ElasticSearchPage::Processor;

use Moo;
use strictures 2;
use namespace::clean;

use Modern::Perl;
use Specio::Declare;
use Specio::Library::Builtins;

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

has namespace => (
    is => 'ro',
    isa => t('Str'),
    default => sub { $_::_default_namespace },
);

# TODO: Perl idiom for abstract methods?
sub _default_namespace {
    die("Not implemented");
}

sub elastic_request_body_alter {}
sub elastic_query_components { return undef; }

1;
