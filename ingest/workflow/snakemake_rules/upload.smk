"""
This part of the workflow handles uploading files to a specified destination.

Uses predefined wildcard `file_to_upload` determine input and predefined
wildcard `remote_file_name` as the remote file name in the specified destination.

Produces output files as `data/upload/{upload_target_name}/{file_to_upload}-to-{remote_file_name}.done`.

Currently only supports uploads to AWS S3, but additional upload rules can
be easily added as long as they follow the output pattern described above.
"""
import os

slack_envvars_defined = "SLACK_CHANNELS" in os.environ and "SLACK_TOKEN" in os.environ
send_notifications = (
    config.get("send_slack_notifications", False) and slack_envvars_defined
)


def _get_upload_inputs(wildcards):
    """
    If the file_to_upload has Slack notifications that depend on diffs with S3 files,
    then we want the upload rule to run after the notification rule.

    This function is mostly to keep track of which flag files to expect for
    the rules in `slack_notifications.smk`, so it only includes flag files if
    `send_notifications` is True.
    """
    file_to_upload = wildcards.file_to_upload

    inputs = {
        "file_to_upload": f"data/{file_to_upload}",
    }

    if send_notifications:
        flag_file = []

        if file_to_upload == "genbank.ndjson":
            flag_file = "data/notify/genbank-record-change.done"
        elif file_to_upload == "metadata.tsv":
            flag_file = "data/notify/metadata-diff.done"

        inputs["notify_flag_file"] = flag_file

    return inputs


rule upload_to_s3:
    input:
        unpack(_get_upload_inputs),
    output:
        "data/upload/s3/{file_to_upload}-to-{remote_file_name}.done",
    params:
        quiet="" if send_notifications else "--quiet",
        s3_dst=config["upload"].get("s3", {}).get("dst", ""),
        cloudfront_domain=config["upload"].get("s3", {}).get("cloudfront_domain", ""),
        upload_to_s3_url="https://raw.githubusercontent.com/nextstrain/monkeypox/644d07ebe3fa5ded64d27d0964064fb722797c5d/ingest/bin/upload-to-s3",
        sha256sum_url="https://raw.githubusercontent.com/nextstrain/monkeypox/644d07ebe3fa5ded64d27d0964064fb722797c5d/ingest/bin/sha256sum",
        cloudfront_invalidate_url="https://raw.githubusercontent.com/nextstrain/monkeypox/644d07ebe3fa5ded64d27d0964064fb722797c5d/ingest/bin/cloudfront-invalidate"
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
        [[ -f bin/upload-to-s3 ]]          || $download_cmd bin/upload-to-s3 {params.upload_to_s3_url}
        [[ -f bin/sha256sum ]]             || $download_cmd bin/sha256sum {params.sha256sum_url}
        [[ -f bin/cloudfront-invalidate ]] || $download_cmd bin/cloudfront-invalidate {params.cloudfront_invalidate_url}
        chmod +x bin/*

        # (3) Run the upload script
        ./bin/upload-to-s3 \
            {params.quiet} \
            {input.file_to_upload:q} \
            {params.s3_dst:q}/{wildcards.remote_file_name:q} \
            {params.cloudfront_domain} 2>&1 | tee {output}
        """
