"""
This part of the workflow handles automatic deployments of the dengue build.
Uploads the build defined as the default output of the workflow through
the `all` rule from Snakefille
"""

rule deploy_all:
    input: *rules.all.input
    output: touch("results/deploy_all.done")
    params:
        deploy_url = config["deploy_url"]
    shell:
        """
        nextstrain remote upload {params.deploy_url} {input}
        """
