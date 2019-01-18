serotypes = ['all', 'denv1', 'denv2', 'denv3', 'denv4']

rule all:
    input:
        auspice_tree = expand("auspice/dengue_{serotype}_tree.json", serotype=serotypes),
        auspice_meta = expand("auspice/dengue_{serotype}_meta.json", serotype=serotypes),

rule files:
    params:
        dropped_strains = "config/dropped_strains.txt",
        reference = "config/reference_dengue_{serotype}.gb",
        auspice_config = "config/auspice_config_{serotype}.json"

files = rules.files.params

def download_serotype_integer(w):
    serotype_integer = {
        'all': 'all',
        'denv1': '1',
        'denv2': '2',
        'denv3': '3',
        'denv4': '4'
    }
    return serotype_integer[w.serotype]

def filter_sequences_per_group(w):
    sequences_per_group = {
        'all': '1000',
        'denv1': '30',
        'denv2': '30',
        'denv3': '30',
        'denv4': '30'
    }
    return sequences_per_group[w.serotype]

def traits_columns(w):
    traits = {
        'all': 'region',
        'denv1': 'country region',
        'denv2': 'country region',
        'denv3': 'country region',
        'denv4': 'country region'
    }
    return traits[w.serotype]

def clade_defs(w):
    defs = {
        'all': 'config/clades_genotypes.tsv',
        'denv1': 'config/clades_genotypes.tsv',
        'denv2': 'config/clades_genotypes.tsv',
        'denv3': 'config/clades_genotypes.tsv',
        'denv4': 'config/clades_genotypes.tsv'
    }
    return defs[w.serotype]

rule download:
    message: "Downloading sequences from fauna"
    output:
        sequences = "data/dengue_{serotype}.fasta"
    params:
        fasta_fields = "strain virus accession collection_date region country division location source locus authors url title journal puburl",
        serotype_integer = download_serotype_integer
    run:
        if wildcards.serotype == 'all':
            shell("""
                python3 ../fauna/vdb/download.py \
                    --database vdb \
                    --virus dengue \
                    --fasta_fields {params.fasta_fields} \
                    --path $(dirname {output.sequences}) \
                    --fstem $(basename {output.sequences} .fasta)
            """)
        else:
            shell("""
                python3 ../fauna/vdb/download.py \
                    --database vdb \
                    --virus dengue \
                    --fasta_fields {params.fasta_fields} \
                    --select serotype:{params.serotype_integer} \
                    --path $(dirname {output.sequences}) \
                    --fstem $(basename {output.sequences} .fasta)
            """)

rule parse:
    message: "Parsing fasta into sequences and metadata"
    input:
        sequences = rules.download.output.sequences
    output:
        sequences = "results/sequences_{serotype}.fasta",
        metadata = "results/metadata_{serotype}.tsv"
    params:
        fasta_fields = "strain virus accession date region country division city db segment authors url title journal paper_url"
    shell:
        """
        augur parse \
            --sequences {input.sequences} \
            --output-sequences {output.sequences} \
            --output-metadata {output.metadata} \
            --fields {params.fasta_fields}
        """

rule filter:
    message:
        """
        Filtering to
          - {params.sequences_per_group} sequence(s) per {params.group_by!s}
          - excluding strains in {input.exclude}
          - minimum genome length of {params.min_length}
          - excluding strains with missing region, country or date metadata
        """
    input:
        sequences = rules.parse.output.sequences,
        metadata = rules.parse.output.metadata,
        exclude = files.dropped_strains
    output:
        sequences = "results/filtered_{serotype}.fasta"
    params:
        group_by = "year region",
        sequences_per_group = filter_sequences_per_group,
        min_length = 5000
    shell:
        """
        augur filter \
            --sequences {input.sequences} \
            --metadata {input.metadata} \
            --exclude {input.exclude} \
            --output {output.sequences} \
            --group-by {params.group_by} \
            --sequences-per-group {params.sequences_per_group} \
            --min-length {params.min_length} \
            --exclude-where country=? region=? date=? \
            --include-where region=southeast_asia
        """

rule align:
    message:
        """
        Aligning sequences to {input.reference}
          - filling gaps with N
        """
    input:
        sequences = rules.filter.output.sequences,
        reference = files.reference
    output:
        alignment = "results/aligned_{serotype}.fasta"
    shell:
        """
        augur align \
            --sequences {input.sequences} \
            --reference-sequence {input.reference} \
            --output {output.alignment} \
            --fill-gaps \
            --remove-reference \
            --nthreads auto
        """

rule tree:
    message: "Building tree"
    input:
        alignment = rules.align.output.alignment
    output:
        tree = "results/tree-raw_{serotype}.nwk"
    shell:
        """
        augur tree \
            --alignment {input.alignment} \
            --output {output.tree} \
            --nthreads auto
        """

rule refine:
    message:
        """
        Refining tree
          - estimate timetree
          - use {params.coalescent} coalescent timescale
          - estimate {params.date_inference} node dates
          - filter tips more than {params.clock_filter_iqd} IQDs from clock expectation
        """
    input:
        tree = rules.tree.output.tree,
        alignment = rules.align.output,
        metadata = rules.parse.output.metadata
    output:
        tree = "results/tree_{serotype}.nwk",
        node_data = "results/branch-lengths_{serotype}.json"
    params:
        coalescent = "const",
        date_inference = "marginal",
        clock_filter_iqd = 4
    shell:
        """
        augur refine \
            --tree {input.tree} \
            --alignment {input.alignment} \
            --metadata {input.metadata} \
            --output-tree {output.tree} \
            --output-node-data {output.node_data} \
            --timetree \
            --coalescent {params.coalescent} \
            --date-confidence \
            --date-inference {params.date_inference} \
            --clock-filter-iqd {params.clock_filter_iqd}
        """

rule ancestral:
    message: "Reconstructing ancestral sequences and mutations"
    input:
        tree = rules.refine.output.tree,
        alignment = rules.align.output
    output:
        node_data = "results/nt-muts_{serotype}.json"
    params:
        inference = "joint"
    shell:
        """
        augur ancestral \
            --tree {input.tree} \
            --alignment {input.alignment} \
            --output {output.node_data} \
            --inference {params.inference}
        """

rule translate:
    message: "Translating amino acid sequences"
    input:
        tree = rules.refine.output.tree,
        node_data = rules.ancestral.output.node_data,
        reference = files.reference
    output:
        node_data = "results/aa-muts_{serotype}.json"
    shell:
        """
        augur translate \
            --tree {input.tree} \
            --ancestral-sequences {input.node_data} \
            --reference-sequence {input.reference} \
            --output {output.node_data} \
        """

rule traits:
    message:
        """
        Inferring ancestral traits for {params.columns!s}
          - increase uncertainty of reconstruction by {params.sampling_bias_correction} to partially account for sampling bias
        """
    input:
        tree = rules.refine.output.tree,
        metadata = rules.parse.output.metadata
    output:
        node_data = "results/traits_{serotype}.json",
    params:
        columns = traits_columns,
        sampling_bias_correction = 3
    shell:
        """
        augur traits \
            --tree {input.tree} \
            --metadata {input.metadata} \
            --output {output.node_data} \
            --columns {params.columns} \
            --confidence \
            --sampling-bias-correction {params.sampling_bias_correction}
        """

rule clades:
    message: "Annotating serotypes / genotypes"
    input:
        tree = rules.refine.output.tree,
        nt_muts = rules.ancestral.output,
        aa_muts = rules.translate.output,
        clade_defs = clade_defs,
    output:
        clades = "results/clades_{serotype}.json"
    shell:
        """
        augur clades \
            --tree {input.tree} \
            --mutations {input.nt_muts} {input.aa_muts} \
            --clades {input.clade_defs} \
            --output {output.clades}
        """

rule tip_frequencies:
    input:
        tree = rules.refine.output.tree,
        metadata = rules.parse.output.metadata
    params:
        narrow_bandwidth = 3 / 12.0,
        wide_bandwidth = 3 / 12.0,
        proportion_wide = 0.0,
        min_date = 1970,
        max_date = 2015,
        pivot_interval = 3 # 3 months between pivots or 4 pivots per year
    output:
        tip_freq = "auspice/dengue_{serotype}_tip-frequencies.json",
    shell:
        """
        augur frequencies \
            --method kde \
            --tree {input.tree} \
            --metadata {input.metadata} \
            --narrow-bandwidth {params.narrow_bandwidth} \
            --wide-bandwidth {params.wide_bandwidth} \
            --proportion-wide {params.proportion_wide} \
            --pivot-interval {params.pivot_interval} \
            --min-date {params.min_date} \
            --max-date {params.max_date} \
            --output {output}
        """

rule tree_frequencies:
    input:
        tree = rules.refine.output.tree,
        metadata = rules.parse.output.metadata,
    params:
        min_date = 1970,
        max_date = 2015,
        pivot_interval = 3,
        regions = ['southeast_asia'],
        stiffness = 2
    output:
        "results/tree-frequencies_{serotype}.json",
    shell:
        """
        augur frequencies \
            --method diffusion \
            --include-internal-nodes \
            --tree {input.tree} \
            --regions {params.regions} \
            --metadata {input.metadata} \
            --pivot-interval {params.pivot_interval} \
            --stiffness {params.stiffness} \
            --min-date {params.min_date} \
            --max-date {params.max_date} \
            --output {output}
        """

rule export:
    message: "Exporting data files for for auspice"
    input:
        tree = rules.refine.output.tree,
        metadata = rules.parse.output.metadata,
        branch_lengths = rules.refine.output.node_data,
        traits = rules.traits.output.node_data,
        clades = rules.clades.output.clades,
        nt_muts = rules.ancestral.output.node_data,
        aa_muts = rules.translate.output.node_data,
        auspice_config = files.auspice_config
    output:
        auspice_tree = "auspice/dengue_{serotype}_tree.json",
        auspice_meta = "auspice/dengue_{serotype}_meta.json"
    shell:
        """
        augur export \
            --tree {input.tree} \
            --metadata {input.metadata} \
            --node-data {input.branch_lengths} {input.traits} {input.clades} {input.nt_muts} {input.aa_muts} \
            --auspice-config {input.auspice_config} \
            --output-tree {output.auspice_tree} \
            --output-meta {output.auspice_meta}
        """

rule clean:
    message: "Removing directories: {params}"
    params:
        "results ",
        "auspice"
    shell:
        "rm -rfv {params}"
