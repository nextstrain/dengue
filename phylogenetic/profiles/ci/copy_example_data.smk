rule copy_example_data:
    input:
        sequences="example_data/sequences_{serotype}.fasta",
        metadata="example_data/metadata_{serotype}.tsv",
    output:
        sequences="data/sequences_{serotype}.fasta",
        metadata="data/metadata_{serotype}.tsv",
    shell:
        """
        cp -f {input.sequences} {output.sequences}
        cp -f {input.metadata} {output.metadata}
        """

ruleorder: copy_example_data > decompress