use Modern::Perl;

package ElasticSearchPage::Base;
#use Exporter;
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
    return $self;
}
1;
