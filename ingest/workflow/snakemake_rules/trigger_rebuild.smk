"""
This part of the workflow handles triggering new monkeypox builds after the
latest metadata TSV and sequence FASTA files have been uploaded to S3.

Designed to be used internally by the Nextstrain team with hard-coded paths
to expected upload flag files.
"""

rule trigger_build:
    message: "Triggering monekypox builds via repository action type `rebuild`."
    input:
        metadata_upload = "data/upload/s3/metadata.tsv-to-metadata.tsv.gz.done",
        fasta_upload = "data/upload/s3/sequences.fasta-to-sequences.fasta.xz.done"
    output:
        touch("data/trigger/rebuild.done")
    params:
        trigger_on_new_data_url="https://raw.githubusercontent.com/nextstrain/monkeypox/644d07ebe3fa5ded64d27d0964064fb722797c5d/ingest/bin/trigger-on-new-data"
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
        [[ -f bin/trigger-on-new-data ]] || $download_cmd bin/trigger-on-new-data {params.trigger_on_new_data_url}
        chmod +x bin/*
        
        # (3) Trigger the build
        ./bin/trigger-on-new-data {input.metadata_upload} {input.fasta_upload}
        """
