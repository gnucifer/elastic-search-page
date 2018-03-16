use Modern::Perl;
use URI;
use URI::QueryParam;

# TODO: Rename to ElasticSearchPage:Dispatcher;
# TODO: MOjligt att kan ha nago slags pattern dar ny dispatcher tar subdel av
# url och foljer samma pattern???

package ElasticSearchPage::ProcessorsPipeline;
use parent 'ElasticSearchPage::Base';

#require Exporter;
#our @ISA = qw(Exporter);
#our @EXPORT = qw();

# TODO: Has:
# - processors
# - search-callback-thingy implementing some interface

# methodods, process($url) #(url can be relative or absolute?) protocol?}

sub _initialize {
    my ($self, $params) = @_;
    $self->SUPER::_initialize($params);
    die('Missing parameter: "processors"') unless exists $params->{processors};
    $self->{processors} = $params->{processors};
}

sub _parse_url {
    my ($self, $url_string) = @_;
    my $url = URI->new($url_string);
    my $parsed_url = {};

    my $path = $url->path;
    if ($path) {
        $parsed_url->{path_segments} = [grep { $_ } split(/\//, $path)];
    }

    my $query = $url->query_form_hash;
    if ($query && %{$query}) {
        $parsed_url->{query} = $query;
    }

    my $fragment = $url->fragment;
    if ($fragment) {
        $parsed_url->{fragment} = $fragment;
    }

    if ($url->can('host')) {
        my $host = $url->host;
        if ($host) {
            $parsed_url->{host} = $host;
        }
    }

    my $scheme = $url->scheme;
    if ($scheme) {
        $parsed_url->{scheme} = $scheme;
    }

    if ($url->can('port')) {
        my $port = $url->port;
        # TODO: This is ugly, fix?
        #if ($port && !($port == 80 && ($scheme eq 'http' || $scheme eq 'https'))) {
        if ($port) {
            $parsed_url->{port} = $port;
        }
    }

    return $parsed_url;
}

# TODO: Better name
sub _url_components_parts_combine {
    my ($self, $url_components_parts) = @_;
    my @path_segments;
    my %query;
    my $fragment = undef;

    my $result = {};

    foreach my $url_components (@{$url_components_parts}) {
        if (exists $url_components->{path_segments} && @{$url_components->{path_segments}}) {
            push @path_segments, @{$url_components->{path_segments}};
        }
        if (exists $url_components->{query}) {
            # Merge (will overwrite keys, processors response this never
            # happens(?))
            foreach my $key (keys %{$url_components->{query}}) {
                my $value = $url_components->{query}->{$key};
                # TODO: Can this kludge be avoided?
                if (ref($value) eq 'ARRAY' && @{$value} && (!ref($value) || $value)) {
                    $query{$key} = $value;
                }
            }
        }
        foreach my $key ('fragment', 'host', 'scheme', 'port') {
            if (exists $url_components->{$key}) {
                $result->{$key} = $url_components->{$key};
            }
        }
    }
    $result->{path_segments} = \@path_segments;
    $result->{query} = \%query;
    return $result;
}

#sub elastic_query_components_parts_combine {
#    my ($self, $url_components_parts) = @_;
#}

# TODO: Does not build url, but just last part, so needs other name (and
# related subs too)
sub _build_url {
    my ($self, $url_components) = @_;

    my $url = URI->new(
        exists $url_components->{host} ? $url_components->{host} : '',
        exists $url_components->{scheme} ? $url_components->{scheme} : 'http'
    );

    # @TODO: WTF is this, host and scheme is purged when setting
    # path_segments etc, set again here as this seams to prevent this
    # @TODO: Fix properly
    if (exists $url_components->{host}) {
        $url->host($url_components->{host});
    }

    if (exists $url_components->{scheme}) {
        $url->scheme($url_components->{scheme});
    }

    if (exists $url_components->{path_segments}) {
        $url->path_segments(@{$url_components->{path_segments}});
    }

    if (exists $url_components->{query} && %{$url_components->{query}}) {
        my $query = $url_components->{query};
        # Force sort lexically for now, but should probably allow more control over this
        foreach my $key (sort keys %{$query}) {
            $url->query_param($key, $query->{$key});
        }
    }

    if (exists $url_components->{fragment}) {
        $url->fragment($url_components->{fragment});
    }

    if (exists $url_components->{port}) {
        $url->port($url_components->{port});
    }

    return $url->canonical->as_string;
}

sub _url_components_parts_build_url {
    my ($self, $url_components_parts) = @_;
    my $url_components = $self->_url_components_parts_combine($url_components_parts);
    return $self->_build_url($url_components);
}

sub pipe {
    my ($self, $params) = @_;
    #TODO: Parameter validation
    my $parsed_external_url_part =
        exists $params->{external_url_part} ?
            $self->_parse_url($params->{external_url_part}) : undef;
    my $parsed_internal_url_part =
        $self->_parse_url($params->{internal_url_part});
    my $searcher = $params->{searcher};
    # TODO: make clearer this represent state of current query? Or leave
    # as is
    my $states = {};

    # Collect query state
    my %url_components_parts;
    my @url_components_parts_keys; # We want to preserve order of hash, is this possible in less hackish way? sub?
    my $query_dsl = {}; # @TODO: base query option
    my $elastic_request_body = {};
    my @elastic_query_components_parts;

    # Split into multiple_methods?
    foreach my $processor (@{$self->{processors}}) {
        my $state = $processor->extract_state($parsed_internal_url_part);
        $states->{$processor->namespace} = $state;
    }

    foreach my $processor (@{$self->{processors}}) {
        my $ns = $processor->namespace;
        $url_components_parts{$ns} = $processor->url_components($states->{$ns});
        push @url_components_parts_keys, $ns;
    }

    # TODO: Break out in methods?
    my $conditions = {};
    foreach my $processor (@{$self->{processors}}) {
        my $query_components = $processor->elastic_query_components(
            $states->{$processor->namespace}
        );
        next unless $query_components;
        # Really just a merge:
        # TODO: Validate format?
        foreach my $context ('query', 'filter') {
            if (exists $query_components->{$context}) {
                # TODO: Case sensitivity?
                foreach my $operator ('and', 'or', 'not') {
                    if (exists $query_components->{$context}->{$operator}) {
                        $conditions->{$context}->{$operator} //= [];
                        push @{$conditions->{$context}->{$operator}}, @{$query_components->{$context}->{$operator}};
                    }
                }
            }
        }
    }

    my $bool_query = {};
    if (exists $conditions->{query}) {
        if (exists $conditions->{query}->{and}) {
            $bool_query->{must} = $conditions->{query}->{and};
        }
        if (exists $conditions->{query}->{or}) {
            $bool_query->{should} = $conditions->{query}->{or};
            $bool_query->{minimum_should_match} = 1;
        }
        if (exists $conditions->{query}->{not}) {
            $bool_query->{must_not} = $conditions->{query}->{not};
        }
    }
    if (exists $conditions->{filter}) {
        my $bool_filter_query = {};
        if (exists $conditions->{filter}->{and}) {
            $bool_filter_query->{must} = $conditions->{filter}->{and};
        }
        if (exists $conditions->{filter}->{'or'}) {
            $bool_filter_query->{should} = $conditions->{filter}->{or};
            $bool_filter_query->{minimum_should_match} = 1;
        }
        if (exists $conditions->{filter}->{not}) {
            $bool_filter_query->{must_not} = $conditions->{query}->{not};
        }
        $bool_query->{filter} = {
            bool => $bool_filter_query
        };
    }

    $elastic_request_body = {};
    if (%{$bool_query}) {
        $elastic_request_body->{query} = {
            bool => $bool_query
        };
    }
    else {
        # Match all for now, change this later
         $elastic_request_body->{query} = {
            match_all => {},
        };
    }

    foreach my $processor (@{$self->{processors}}) {
        $processor->elastic_request_body_alter(
            $states->{$processor->namespace}, $elastic_request_body # TODO: Change order of arguments?
        );
    }

    # Or callback instead just $self->searcher->($query_dsl) ??
    # TODO: Error handling and lots of other stuff
    my $elastic_response = $searcher->($elastic_request_body);
    # Let processors process response (+ state)
    my $result = {};
    # Helper function, foreach_processor?
    #
    # @TODO: RANDOM THOUGHT: More than state that needs to go into
    # url_components, most likely state + other_state? Fix later
    foreach my $processor (@{$self->{processors}}) {
        my $namespace = $processor->namespace;
        my $url_from_state = sub {
            my ($state) = @_;
            # hmm,.. name @new_ prefix??
            my @_url_components_parts =
                $parsed_external_url_part ? $parsed_external_url_part : ();
            # @TODO: Fix comment if keeping this code:
            # Build new url components parts by reusing other processor's
            # and replace current processor's one with new build with
            # passed $state
            foreach my $key (@url_components_parts_keys) {
                if ($key eq $namespace) {
                    push @_url_components_parts, $processor->url_components($state);
                }
                else {
                    # Reuse cached url components
                    push @_url_components_parts, $url_components_parts{$key};
                }
            }
            return $self->_url_components_parts_build_url(\@_url_components_parts);
        };
        $result->{$processor->namespace} = $processor->process(
            $url_from_state,
            $states->{$processor->namespace},
            $elastic_response
        );
    }
    return $result;
}
1;
