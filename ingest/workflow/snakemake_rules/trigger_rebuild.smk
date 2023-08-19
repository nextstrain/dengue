"""
This part of the workflow handles triggering new Dengue builds after the
latest metadata TSV and sequence FASTA files have been uploaded to S3.

Designed to be used internally by the Nextstrain team with hard-coded paths
to expected upload flag files.
"""

rule trigger_build:
    message: "Triggering monekypox builds via repository action type `rebuild`."
    input:
        metadata_upload = "data/upload/s3/metadata_{serotype}.tsv-to-metadata_{serotype}.tsv.gz.done",
        fasta_upload = "data/upload/s3/sequences_{serotype}.fasta-to-sequences_{serotype}.fasta.xz.done"
    output:
        touch("data/trigger/rebuild_{serotype}.done")
    shell:
        """
        ./bin/trigger-on-new-data {input.metadata_upload} {input.fasta_upload}
        """
