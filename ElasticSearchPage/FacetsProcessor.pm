use Modern::Perl;

package ElasticSearchPage::FacetsProcessor; #Processor instead of Controller probably
use parent 'ElasticSearchPage::Processor';

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
    $self->SUPER::_initialize($params);
    die('Missing parameter: "facets"') unless exists $params->{facets};
    # die('Missing parameter: "url_serializer"') unless exists $params->{url_serializer};
    $self->{facets} = $params->{facets};
    # $self->{url_serializer} = $params->{url_serializer};
    # $params->{meta}; # Could contain "title" for example
}

sub default_namespace {
    return 'facets';
}

# TODO: Detta ligger i plug/composable objekt sen, fixa
# url_deserialize
sub extract_state {
    my ($self, $url_components) = @_;
    my $facets = $self->{facets};
    my $query = $url_components->{query};
    # 'facets' => ????
    my $state = {};
    # {
    #   '<facet_key>' => {
    #       bucket_keys => [
    #           <bucket_key1> => undef,
    #           <bucket_key2> => undef,
    #           ...
    #       ]
    #   }
    # }
    # <<<<< HEAR 
    foreach my $facet (@{$facets}) {
        my $ns = $facet->namespace;
        if (exists $query->{$ns}) {
            my $param_values = ref($query->{$ns}) ? $query->{$ns} : [$query->{$ns}];
            $state->{$ns} = {
                # Create hash for easier/faster bucket key/condition lookup
                'bucket_keys' => {map { $_ => undef } @{$param_values}},
            };
        }
    }
    #return %{$state} ? $state : undef;
    return $state;
}

# url_serialize
sub url_components {
    my ($self, $state) = @_;
    my $facets = $self->{facets};
    my $url_components = {
        query => {}
    };

    foreach my $facet_key (%{$state}) {
        my $facet_state = $state->{$facet_key};

        # if ($facet_state) { ??
        # TODO: or is exists fine?
        # TODO: WHY DONT %{ $facet_state->{bucket_keys} } work???
        if (exists $facet_state->{bucket_keys}) {
            $url_components->{query}->{$facet_key} = [keys %{$facet_state->{bucket_keys}}]
        }
    }
    return $url_components;
}

# FIXA HAR >>>
# AND CONDITIONS, OR CONDITIONS??
sub elastic_query_components {
    my ($self, $state, $query_dsl) = @_;
    my @must;
    my $facets = $self->{facets};
    foreach my $facet (@{$facets}) {
        my $namespace = $facet->namespace;
        # TODO: Probably change this so facets can add query without having state?
        if (exists $state->{$namespace}) {
            my $facet_state = $state->{$namespace};
            my @filter_queries;
            foreach my $condition (keys %{$facet_state->{bucket_keys}}) { # @TODO: Bucket_keys/bucket_conditions: pick one
                push @filter_queries, $facet->bucket_query($condition);
            }
            my $query;
            if ($facet->operator eq 'and') {
                $query = {
                    'bool' => {
                        'must' => \@filter_queries,
                    }
                };
            }
            elsif ($facet->operator eq 'or') {
                $query = {
                    'bool' => {
                        'should' => \@filter_queries,
                        'minimum_should_match' => 1
                    }
                };
            }
            push @must, $query;

        }
    }
    # Propably should only allow and, so filter => { and_queries }
    return @must ? { filter => { and => \@must } } : {};
}

sub elastic_request_body_alter {
    my ($self, $_state, $elastic_request_body) = @_;
    my $aggregations = {};
    foreach my $facet (@{$self->{facets}}) {
        my $namespace = $facet->namespace;
        $aggregations->{$namespace} = $facet->aggregation;
    }
    $elastic_request_body->{aggregations} = $aggregations;
}

# @TODO: Brainfuck, could this be implemented as sub-pipe thing?
# Probably absolutely no

sub process {
    # Facets state comes from deserialized url
    # Get passed state, or set state??
    my ($self, $url_from_state, $state, $elastic_response) = @_;

    my @processed_facets;
    return \@processed_facets unless (exists $elastic_response->{aggregations}); # Yes, probably??

    my $aggregations = $elastic_response->{aggregations};
    # Just trying this weirdness out
    # Get my state
    my $facets_states;
    $facets_states = $state;

    # Facets keyed by namespace
    #my %facets = map { $_->namespace => $_ } @{$self->{facets}};

    for my $facet (@{$self->{facets}}) {
        my $namespace = $facet->namespace; # Skall det verkligen heta namespace,
        # kan man vara explicit och kora med aggregation_name???
        # Perhaps a little too presumptuous, might whant to display emtpy facet?
        next unless exists $aggregations->{$namespace}; #??

        my $processed_facet = $facet->processed_facet_properties;
        $processed_facet->{facet} = $namespace; # Or separate method returning namespace by default?
        $processed_facet->{buckets} = [];

        # TODO: Super hack below, must think through how to handle empty state!
        my $facet_state =
            exists $facets_states->{$namespace} ?
                $facets_states->{$namespace} : { bucket_keys => {} }; # Hmm
        my $buckets = $aggregations->{$namespace}->{buckets};

        # @TODO: Handle possible keyed buckets response(!?), or don't allow?
        foreach my $response_bucket (@{$buckets}) {
            my $condition = $facet->bucket_condition($response_bucket); #key/condition
            # TODO: Perhaps need generic manipulators for state thiny??
            # or we will have this superuglyness in every type of processor
            my $facets_states_copy = { %{$facets_states} };
            my $facet_state_copy = { %{$facet_state} };
            $facet_state_copy->{bucket_keys} = { %{$facet_state->{bucket_keys}} };

            my $bucket = {};
            $bucket->{label} = $facet->bucket_label($response_bucket);
            # Place this in facet?
            $bucket->{doc_count} = $response_bucket->{doc_count};
            $bucket->{key} = $response_bucket->{key}; # ??
            $bucket->{condition} = $condition; # ??

            if ($facet_state && exists $facet_state->{bucket_keys}->{$condition}) {
                # This facet bucket is selected/active
                # Create link that excludes own condition
                delete $facet_state_copy->{bucket_keys}->{$condition};
                $facets_states_copy->{$namespace} = $facet_state_copy;
                # TODO: base_query here????
                $bucket->{url} = $url_from_state->($facets_states_copy);
                # TODO: Better name than label, display_value? Nja label ar bra,
                # also probably need use object composition/callback for this
                # (fetch from db etc)
                $bucket->{filter_action} = 'remove'; # add/remove? Or is_remove_query_part?

            }
            else {
                # This facet bucket is not selected/inactive
                # Create link that includes own condition
                $facet_state_copy->{bucket_keys}{$condition} = undef;
                $facets_states_copy->{$namespace} = $facet_state_copy;
                # TODO: Refactor duplicate code
                $bucket->{url} = $url_from_state->($facets_states_copy);
                $bucket->{filter_action} = 'apply'; # apply/add/remove? Or is_remove_query_part?
            }
            # Sort later
            push @{$processed_facet->{buckets}}, $bucket;
        }
        push @processed_facets, $processed_facet;
    }
    return \@processed_facets;
}
1;
