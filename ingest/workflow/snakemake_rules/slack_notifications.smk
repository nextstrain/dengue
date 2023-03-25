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
        genbank_ndjson="data/genbank_{serotype}.ndjson",
    output:
        touch("data/notify/genbank-record-change.done"),
    params:
        s3_src=S3_SRC,
        genbank_filename="genbank_{serotype}.ndjson.xz",
    shell:
        """
        ./bin/notify-on-record-change {input.genbank_ndjson} {params.s3_src:q}/{params.genbank_filename:q} Genbank
        """


rule notify_on_metadata_diff:
    input:
        metadata="data/metadata_{serotype}.tsv",
    output:
        touch("data/notify/metadata_{serotype}-diff.done"),
    params:
        s3_src=S3_SRC,
        metadata_filename="metadata_{serotype}.tsv.gz",
    shell:
        """
        ./bin/notify-on-diff {input.metadata} {params.s3_src:q}/{params.metadata_filename:q}
        """


onstart:
    shell("./bin/notify-on-job-start")


onerror:
    shell("./bin/notify-on-job-fail")
