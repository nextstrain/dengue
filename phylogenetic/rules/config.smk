"""
This part of the workflow deals with the config

OUTPUTS

    results/run_config.yaml
"""

# Expected values supported by the workflow
SEROTYPES = {'all', 'denv1', 'denv2', 'denv3', 'denv4'}
GENES = {'genome', 'E'}

# Validate config values
if not all(serotype in SEROTYPES for serotype in config["serotypes"]):
    raise InvalidConfigError(f"Values for `config.serotypes` must be one of {sorted(SEROTYPES)!r}")

if not all(gene in GENES for gene in config["genes"]):
    raise InvalidConfigError(f"Values for `config.genes` must be one of {sorted(GENES)!r}")

write_config("results/run_config.yaml")
