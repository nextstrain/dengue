"""
This part of the workflow handles various Slack notifications.
Designed to be used internally by the Nextstrain team with hard-coded paths
to files on AWS S3.

All rules here require two environment variables:
    * SLACK_TOKEN
    * SLACK_CHANNELS
"""
import os
import sys

slack_envvars_defined = "SLACK_CHANNELS" in os.environ and "SLACK_TOKEN" in os.environ
if not slack_envvars_defined:
    print(
        "ERROR: Slack notifications require two environment variables: 'SLACK_CHANNELS' and 'SLACK_TOKEN'.",
        file=sys.stderr,
    )
    sys.exit(1)

S3_SRC = "s3://nextstrain-data/files/workflows/dengue"


rule notify_on_genbank_record_change:
    input:
        genbank_ndjson="data/genbank.ndjson",
    output:
        touch("data/notify/genbank-record-change.done"),
    params:
        s3_src=S3_SRC,
        notify_on_record_change_url="https://raw.githubusercontent.com/nextstrain/monkeypox/644d07ebe3fa5ded64d27d0964064fb722797c5d/ingest/bin/notify-on-record-change",
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
        [[ -f bin/notify-on-record-change ]] || $download_cmd bin/notify-on-record-change {params.notify_on_record_change_url}
        chmod +x bin/*

        # (3) Run the script
        ./bin/notify-on-record-change {input.genbank_ndjson} {params.s3_src:q}/genbank.ndjson.xz Genbank
        """


rule notify_on_metadata_diff:
    input:
        metadata="data/metadata.tsv",
    output:
        touch("data/notify/metadata-diff.done"),
    params:
        s3_src=S3_SRC,
        notify_on_diff_url = "https://raw.githubusercontent.com/nextstrain/monkeypox/644d07ebe3fa5ded64d27d0964064fb722797c5d/ingest/bin/notify-on-diff",
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
        [[ -f bin/notify-on-diff ]] || $download_cmd bin/notify-on-diff {params.notify_on_diff_url}
        chmod +x bin/*

        # (3) Run the script
        ./bin/notify-on-diff {input.metadata} {params.s3_src:q}/metadata.tsv.gz
        """


onstart:
    shell("./bin/notify-on-job-start")


onerror:
    shell("./bin/notify-on-job-fail")
