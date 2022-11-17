#! /usr/bin/env Rscript

library(tidyverse)
library(magrittr)

outfile="processed_metadata.tsv"
args <- commandArgs(trailingOnly = TRUE)
if (length(args) == 0) {
  stop("Expecting one argument, a NCBI Virus metadata.tsv file.n", call. = FALSE)
} else if (length(args) == 1) {
  metadata <- args[1]
} else if (length(args) == 2) {
  metadata <- args[1]
  outfile <- args[2]
}

data <- readr::read_delim(metadata,
                          delim = "\t",
                          col_types = cols(.default = "c"))

cdata <- data %>%
  mutate(
    url=paste("https://www.ncbi.nlm.nih.gov/nuccore/",accession,sep=""),
    strain = case_when(
      (strain != accession) ~ strain,
      (accession == strain) & (!is.na(strain_s)) ~ strain_s,
      TRUE ~ strain),
    strain = strain %>%
      gsub(" ", "_", .) %>%
      gsub("-", "_", .) %>%
      gsub("\\.", "_", .) %>%
      gsub("\\(","_", .) %>%
      gsub("\\)", "_", .),
    strain_s=NULL,
    serotype=case_when(
      grepl("11053", viruslineage_ids) ~ "denv1",
      grepl("11060", viruslineage_ids) ~ "denv2",
      grepl("11069", viruslineage_ids) ~ "denv3",
      grepl("11070", viruslineage_ids) ~ "denv4"
      ),
    viruslineage_ids = NULL,
    authors = abbr_authors,
    abbr_authors = NULL,
    paper_url = case_when(
      !is.na(publications) ~ paste("https://www.ncbi.nlm.nih.gov/pubmed/", publications, se = "") %>% gsub(",.*", "", .)),
    publications = NULL,
    city = location,
    location = NULL
  ) %>%
  select(c("strain", "accession", "serotype", "date", "updated", "region", "country", "division", "city","authors", "url", "title", "paper_url"))

cdata[is.na(cdata)] = "?"
readr::write_delim(cdata, outfile, delim = "\t")
