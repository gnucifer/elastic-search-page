package ElasticSearchPage::FacetsProcessor::FacetTerms;

use Moo;
extends 'ElasticSearchPage::FacetsProcessor::Facet';
use strictures 2;
use namespace::clean;

use Modern::Perl;

sub bucket_condition {
    my ($self, $bucket) = @_; # TODO: Also pass complete response?
    return $bucket->{key};
}

sub bucket_query {
    my ($self, $condition) = @_; # TODO: Also pass complete response?
    # TODO: How to factor in field in less boilerplaty way?
    return { term => { $self->field => $condition } };
}

sub bucket_label {
    my ($self, $bucket) = @_;
    return $bucket->{key};
}

# Hacked in, need to think thorugh interface
sub aggregation {
    my ($self) = @_;
    return { terms => { field => $self->field } };
}

1;
