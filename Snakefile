configfile: "config/config_dengue.yaml"

serotypes = ['all', 'denv1', 'denv2', 'denv3', 'denv4']

rule all:
    input:
        auspice_json = expand("auspice/dengue_{serotype}.json", serotype=serotypes)

rule files:
    params:
        dropped_strains = "config/dropped_strains.txt",
        reference = "config/reference_dengue_{serotype}.gb",
        auspice_config = "config/auspice_config_{serotype}.json"

files = rules.files.params

def download_serotype(w):
    serotype = {
        'all': 'all',
        'denv1': 'Dengue_virus_1',
        'denv2': 'Dengue_virus_2',
        'denv3': 'Dengue_virus_3',
        'denv4': 'Dengue_virus_4'
    }
    return serotype[w.serotype]

def filter_sequences_per_group(w):
    sequences_per_group = {
        'all': '10',
        'denv1': '36',
        'denv2': '36',
        'denv3': '36',
        'denv4': '36'
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
        'all': 'config/clades_serotypes.tsv',
        'denv1': 'config/clades_genotypes.tsv',
        'denv2': 'config/clades_genotypes.tsv',
        'denv3': 'config/clades_genotypes.tsv',
        'denv4': 'config/clades_genotypes.tsv'
    }
    return defs[w.serotype]

rule download:
    """Downloading sequences and metadata from data.nextstrain.org"""
    output:
        sequences = "data/sequences_{serotype}.fasta.zst",
        metadata = "data/metadata_{serotype}.tsv.zst"

    params:
        sequences_url = "https://data.nextstrain.org/files/dengue/sequences_{serotype}.fasta.zst",
        metadata_url = "https://data.nextstrain.org/files/dengue/metadata_{serotype}.tsv.zst"
    shell:
        """
        curl -fsSL --compressed {params.sequences_url:q} --output {output.sequences}
        curl -fsSL --compressed {params.metadata_url:q} --output {output.metadata}
        """

rule decompress:
    """Parsing fasta into sequences and metadata"""
    input:
        sequences = "data/sequences_{serotype}.fasta.zst",
        metadata = "data/metadata_{serotype}.tsv.zst"
    output:
        sequences = "data/sequences_{serotype}.fasta",
        metadata = "data/metadata_{serotype}.tsv"
    shell:
        """
        zstd -d -c {input.sequences} > {output.sequences}
        zstd -d -c {input.metadata} > {output.metadata}
        """

rule wrangle_metadata:
    input:
        metadata="data/metadata_{serotype}.tsv",
    output:
        metadata="results/wrangled_metadata_{serotype}.tsv",
    params:
        strain_id=config.get("strain_id_field", "strain"), #accession
    shell:
        """
        csvtk -t rename -f strain -n strain_original {input.metadata} \
          | csvtk -t mutate -f {params.strain_id} -n strain > {output.metadata}
        """

rule filter:
    """
    Filtering to
      - {params.sequences_per_group} sequence(s) per {params.group_by!s}
      - excluding strains in {input.exclude}
      - minimum genome length of {params.min_length}
      - excluding strains with missing region, country or date metadata
    """
    input:
        sequences = "data/sequences_{serotype}.fasta",
        metadata = "results/wrangled_metadata_{serotype}.tsv",
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
        """

rule align:
    """
    Aligning sequences to {input.reference}
      - filling gaps with N
    """
    input:
        sequences = "results/filtered_{serotype}.fasta",
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
            --nthreads 8
        """

rule tree:
    """Building tree"""
    input:
        alignment = "results/aligned_{serotype}.fasta"
    output:
        tree = "results/tree-raw_{serotype}.nwk"
    shell:
        """
        augur tree \
            --alignment {input.alignment} \
            --output {output.tree} \
            --nthreads 1
        """

rule refine:
    """
    Refining tree
      - estimate timetree
      - use {params.coalescent} coalescent timescale
      - estimate {params.date_inference} node dates
      - filter tips more than {params.clock_filter_iqd} IQDs from clock expectation
    """
    input:
        tree = "results/tree-raw_{serotype}.nwk",
        alignment = "results/aligned_{serotype}.fasta",
        metadata = "results/wrangled_metadata_{serotype}.tsv"
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
    """Reconstructing ancestral sequences and mutations"""
    input:
        tree = "results/tree_{serotype}.nwk",
        alignment = "results/aligned_{serotype}.fasta"
    output:
        node_data = "results/nt-muts_{serotype}.json"
    params:
        inference = "joint"
    shell:
        """
        augur ancestral \
            --tree {input.tree} \
            --alignment {input.alignment} \
            --output-node-data {output.node_data} \
            --inference {params.inference}
        """

rule translate:
    """Translating amino acid sequences"""
    input:
        tree = "results/tree_{serotype}.nwk",
        node_data = "results/nt-muts_{serotype}.json",
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
    """
    Inferring ancestral traits for {params.columns!s}
      - increase uncertainty of reconstruction by {params.sampling_bias_correction} to partially account for sampling bias
    """
    input:
        tree = "results/tree_{serotype}.nwk",
        metadata = "results/wrangled_metadata_{serotype}.tsv"
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
    """Annotating serotypes / genotypes"""
    input:
        tree = "results/tree_{serotype}.nwk",
        nt_muts = "results/nt-muts_{serotype}.json",
        aa_muts = "results/aa-muts_{serotype}.json",
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

rule export:
    """Exporting data files for for auspice"""
    input:
        tree = "results/tree_{serotype}.nwk",
        metadata = "results/wrangled_metadata_{serotype}.tsv",
        branch_lengths = "results/branch-lengths_{serotype}.json",
        traits = "results/traits_{serotype}.json",
        clades = "results/clades_{serotype}.json",
        nt_muts = "results/nt-muts_{serotype}.json",
        aa_muts = "results/aa-muts_{serotype}.json",
        auspice_config = files.auspice_config
    output:
        auspice_json = "results/raw_dengue_{serotype}.json",
        root_sequence = "results/raw_dengue_{serotype}_root-sequence.json",
    shell:
        """
        augur export v2 \
            --tree {input.tree} \
            --metadata {input.metadata} \
            --node-data {input.branch_lengths} {input.traits} {input.clades} {input.nt_muts} {input.aa_muts} \
            --auspice-config {input.auspice_config} \
            --include-root-sequence \
            --output {output.auspice_json}
        """

rule final_strain_name:
    input:
        auspice_json="results/raw_dengue_{serotype}.json",
        metadata="results/wrangled_metadata_{serotype}.tsv",
        root_sequence="results/raw_dengue_{serotype}_root-sequence.json",
    output:
        auspice_json="auspice/dengue_{serotype}.json",
        root_sequence="auspice/dengue_{serotype}_root-sequence.json",
    params:
        display_strain_field=config.get("display_strain_field", "strain"),
        set_final_strain_name_url="https://raw.githubusercontent.com/nextstrain/monkeypox/644d07ebe3fa5ded64d27d0964064fb722797c5d/scripts/set_final_strain_name.py",
    shell:
        """
        # (1) Pick curl or wget based on availability
        if which curl > /dev/null; then
            download_cmd="curl -fsSL --output"
        elif which wget > /dev/null; then
            download_cmd="wget -O"
        else
            echo "ERROR: Neither curl nor wget found. Please install one of them."
            exit 1
        fi
        # (2) Download the required scripts if not already present
        [[ -d bin ]] || mkdir bin
        [[ -f bin/set_final_strain_name.py ]] || $download_cmd bin/set_final_strain_name.py {params.set_final_strain_name_url}
        chmod +x bin/*
        # (3) Run the script
        python3 bin/set_final_strain_name.py \
            --metadata {input.metadata} \
            --input-auspice-json {input.auspice_json} \
            --display-strain-name {params.display_strain_field} \
            --output {output.auspice_json}
        cp {input.root_sequence} {output.root_sequence}
        """

rule clean:
    """Removing directories: {params}"""
    params:
        "results ",
        "auspice"
    shell:
        "rm -rfv {params}"
