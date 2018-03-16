use lib '.';
use Modern::Perl;
use ElasticSearchPage::ProcessorsPipeline;
use ElasticSearchPage::FacetsProcessor;
use ElasticSearchPage::FacetsProcessor::Facet;
use ElasticSearchPage::FacetsProcessor::FacetTerms;

use Search::Elasticsearch;

# TODO: Facet-factory
my $facets = [
    ElasticSearchPage::FacetsProcessor::FacetTerms->new(
        {
            meta => {
                label => 'Extension', # Pick one
            },
            operator => 'or',
            namespace => 'extension',
            field => 'extension.keyword',
        },
    ),
    ElasticSearchPage::FacetsProcessor::FacetTerms->new(
        {
            meta => {
                label => 'Tags',
            },
            operator => 'and',
            namespace => '@tags',
            field => '@tags.keyword',
        },
    )
];

my $facets_processor = ElasticSearchPage::FacetsProcessor->new(
    {
       facets => $facets,
       namespace => 'facets_processor',
    }
);

my $pipeline =  ElasticSearchPage::ProcessorsPipeline->new(
    {
        processors => [
            $facets_processor,
        ],
    }
);

my $es = Search::Elasticsearch->new(
    nodes => [
        'localhost:9200',
    ]
);

my $searcher = sub {
    my ($request_body) = @_;
    my $results = $es->search(
        index => 'logstash-2015.05.20',
        body => $request_body,
    );
    return $results;
};

my $external_url_part = 'http://localhost/search';
my $internal_url_part;

if ($ARGV[0]) {
    $internal_url_part = $ARGV[0];
    $internal_url_part =~ s/localhost\/search//
}
else {
    my $u = URI->new('', 'http');
    #$u->query_param_append('@tags' => 'error');
    #$u->query_param_append('@tags' => 'info');
    $u->query_param_append('extension' => 'jpg');
    $internal_url_part = $u->as_string;
}

# TODO: add base_url option
my $result = $pipeline->pipe(
    {
        external_url_part => $external_url_part,
        internal_url_part => $internal_url_part,
        searcher => $searcher,
    }
);

use Data::Dumper;
print "### RESULT ###\n";
die(Dumper($result));

