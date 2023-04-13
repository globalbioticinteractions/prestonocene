SHELL=/bin/bash
BUILD_DIR=build
STAMP=$(BUILD_DIR)/.$(BUILD_DIR)stamp

ELTON_VERSION:=0.12.6
ELTON_JAR:=$(BUILD_DIR)/elton.jar
ELTON:=java -jar $(BUILD_DIR)/elton.jar
ELTON_DATASET_DIR:=${BUILD_DIR}/datasets

NOMER_VERSION:=0.4.8
NOMER_JAR:=$(BUILD_DIR)/nomer.jar
NOMER:=java -jar $(NOMER_JAR)

GNFINDER:=$(BUILD_DIR)/gnfinder

NAMES:=$(BUILD_DIR)/names.tsv.gz
LINKS:=$(BUILD_DIR)/links.tsv.gz

TAXON_GRAPH_URL_PREFIX:=https://zenodo.org/record/6394935/files

TAXON_CACHE_NAME:=$(BUILD_DIR)/taxonCache.tsv
TAXON_CACHE:=$(TAXON_CACHE_NAME).gz
TAXON_MAP_NAME:=$(BUILD_DIR)/taxonMap.tsv
TAXON_MAP:=$(TAXON_MAP_NAME).gz

DIST_DIR:=dist
TAXON_GRAPH_ARCHIVE:=$(DIST_DIR)/taxon-graph.zip

.PHONY: all clean update resolve normalize package

all: update resolve normalize package

clean:
	rm -rf $(BUILD_DIR)/* $(DIST_DIR)/* .nomer/*

$(STAMP):
	mkdir -p $(BUILD_DIR) && touch $@

$(ELTON_JAR): $(STAMP)
	wget -q "https://github.com/globalbioticinteractions/elton/releases/download/$(ELTON_VERSION)/elton.jar" -O $(ELTON_JAR)

$(NAMES): $(ELTON_JAR)
	$(ELTON) names --cache-dir=$(ELTON_DATASET_DIR) | tail -n+2 | cut -f1-7 | gzip > $(BUILD_DIR)/globi-names.tsv.gz
	cat $(BUILD_DIR)/globi-names.tsv.gz | gunzip | sort | uniq | gzip > $(BUILD_DIR)/globi-names-sorted.tsv.gz
	mv $(BUILD_DIR)/globi-names-sorted.tsv.gz $(NAMES)

update: $(NAMES)

$(NOMER_JAR):
	wget -q "https://github.com/globalbioticinteractions/nomer/releases/download/$(NOMER_VERSION)/nomer.jar" -O $(NOMER_JAR)

$(BUILD_DIR)/term_link.tsv.gz:
	wget -q "$(TAXON_GRAPH_URL_PREFIX)/taxonMap.tsv.gz" -O $(BUILD_DIR)/term_link.tsv.gz

$(BUILD_DIR)/term.tsv.gz:
	wget -q "$(TAXON_GRAPH_URL_PREFIX)/taxonCache.tsv.gz" -O $(BUILD_DIR)/term.tsv.gz

$(BUILD_DIR)/namesUnresolved.tsv.gz:
	wget -q "$(TAXON_GRAPH_URL_PREFIX)/namesUnresolved.tsv.gz" -O $(BUILD_DIR)/namesUnresolved.tsv.gz

resolve: update $(NOMER_JAR) $(BUILD_DIR)/term_link.tsv.gz $(BUILD_DIR)/namesUnresolved.tsv.gz $(TAXON_CACHE).update $(TAXON_MAP).update

$(TAXON_CACHE).update:
	cat $(NAMES) | gunzip | cut -f1,2 | sort | uniq | gzip > $(BUILD_DIR)/names_sorted.tsv.gz
	cat $(BUILD_DIR)/names_sorted.tsv.gz | gunzip | $(NOMER) append globi-correct  | cut -f1,2,4,5 | sort | uniq | gzip > $(BUILD_DIR)/names_new_corrected_tmp.tsv.gz

	cat $(BUILD_DIR)/names_new_corrected_tmp.tsv.gz | gunzip | $(GNFINDER) -c 3 -t 30 | gzip > $(BUILD_DIR)/names_new_corrected_gnfinder.tsv.gz
	cat $(BUILD_DIR)/names_new_corrected_gnfinder.tsv.gz | gunzip | grep -v NOT_FOUND | cut -f1,2,3,5 | gzip > $(BUILD_DIR)/names_new_corrected_gnfinder_tmp.tsv.gz
	cat $(BUILD_DIR)/names_new_corrected_gnfinder.tsv.gz | gunzip | grep NOT_FOUND | cut -f1,2,3,4 | gzip >> $(BUILD_DIR)/names_new_corrected_gnfinder_tmp.tsv.gz
	cat $(BUILD_DIR)/names_new_corrected_gnfinder_tmp.tsv.gz | gunzip | sort | uniq | gzip > $(BUILD_DIR)/names_new_corrected.tsv.gz

	# commenting resolve method that rely on APIs
	cat $(BUILD_DIR)/names_new_corrected.tsv.gz | gunzip | $(NOMER) append --properties=config/resolve.properties gbif | gzip > $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/names_new_corrected.tsv.gz | gunzip | $(NOMER) append --properties=config/resolve.properties itis | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/names_new_corrected.tsv.gz | gunzip | $(NOMER) append --properties=config/resolve.properties ncbi | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/names_new_corrected.tsv.gz | gunzip | $(NOMER) append --properties=config/resolve.properties col | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/names_new_corrected.tsv.gz | gunzip | $(NOMER) append --properties=config/resolve.properties openbiodiv | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/names_new_corrected.tsv.gz | gunzip | $(NOMER) append --properties=config/resolve.properties discoverlife | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/names_new_corrected.tsv.gz | gunzip | $(NOMER) append --properties=config/resolve.properties indexfungorum | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/names_new_corrected.tsv.gz | gunzip | $(NOMER) append --properties=config/resolve.properties wfo | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/names_new_corrected.tsv.gz | gunzip | $(NOMER) append --properties=config/resolve.properties batnames | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/names_new_corrected.tsv.gz | gunzip | $(NOMER) append --properties=config/resolve.properties ott | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz


	cat $(BUILD_DIR)/term_resolved.tsv.gz | gunzip | grep -v "NONE" | gzip > $(BUILD_DIR)/term_resolved_once.tsv.gz
	cat $(BUILD_DIR)/term_resolved.tsv.gz | gunzip | grep "NONE" | cut -f1-4 | sort | uniq | gzip > $(BUILD_DIR)/term_unresolved_once.tsv.gz
	mv $(BUILD_DIR)/term_resolved_once.tsv.gz $(BUILD_DIR)/term_resolved.tsv.gz

	# commenting out name resolve method that rely on (unversioned) web apis
	cat $(BUILD_DIR)/term_unresolved_once.tsv.gz | gunzip | $(NOMER) append --properties=config/corrected.properties gbif | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/term_unresolved_once.tsv.gz | gunzip | $(NOMER) append --properties=config/corrected.properties itis | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/term_unresolved_once.tsv.gz | gunzip | $(NOMER) append --properties=config/corrected.properties ncbi | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/term_unresolved_once.tsv.gz | gunzip | $(NOMER) append --properties=config/corrected.properties col | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/term_unresolved_once.tsv.gz | gunzip | $(NOMER) append --properties=config/corrected.properties openbiodiv | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/term_unresolved_once.tsv.gz | gunzip | $(NOMER) append --properties=config/corrected.properties discoverlife | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/term_unresolved_once.tsv.gz | gunzip | $(NOMER) append --properties=config/corrected.properties indexfungorum | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/term_unresolved_once.tsv.gz | gunzip | $(NOMER) append --properties=config/corrected.properties wfo | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/term_unresolved_once.tsv.gz | gunzip | $(NOMER) append --properties=config/corrected.properties batnames | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/term_unresolved_once.tsv.gz | gunzip | $(NOMER) append --properties=config/corrected.properties ott | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz

	cat $(BUILD_DIR)/term_resolved.tsv.gz | gunzip | grep -v "NONE" | grep -P "(SAME_AS|SYNONYM_OF|HAS_ACCEPTED_NAME|COMMON_NAME_OF|HOMONYM_OF)" | cut -f6-14 | gzip > $(BUILD_DIR)/term_match.tsv.gz
	cat $(BUILD_DIR)/term_resolved.tsv.gz | gunzip | grep -v "NONE" | grep -P "(SAME_AS|SYNONYM_OF|HAS_ACCEPTED_NAME|COMMON_NAME_OF|HOMONYM_OF)" | cut -f1,2,6,7 | gzip > $(BUILD_DIR)/term_link_match.tsv.gz
	cat $(BUILD_DIR)/term_resolved.tsv.gz | gunzip | grep "NONE" | cut -f1,2 | sort | uniq | gzip > $(BUILD_DIR)/term_unresolved_once.tsv.gz
	cat $(BUILD_DIR)/term_link_match.tsv.gz | gunzip | cut -f1,2 | sort | uniq | gzip > $(BUILD_DIR)/term_resolved_once.tsv.gz

	# validate newly resolved terms and their links
	cat $(BUILD_DIR)/term_match.tsv.gz | gunzip | $(NOMER) validate-term | grep "all validations pass" | gzip > $(BUILD_DIR)/term_match_validated.tsv.gz
	cat $(BUILD_DIR)/term_link_match.tsv.gz | gunzip | $(NOMER) validate-term-link | grep "all validations pass" | gzip > $(BUILD_DIR)/term_link_match_validated.tsv.gz

	cat $(BUILD_DIR)/term_link_match_validated.tsv.gz | gunzip | grep -v "FAIL" | cut -f3- | gzip > $(TAXON_MAP).update
	cat $(BUILD_DIR)/term_match_validated.tsv.gz | gunzip | grep -v "FAIL" | cut -f3- | gzip > $(TAXON_CACHE).update


$(TAXON_CACHE): $(BUILD_DIR)/term.tsv.gz
	# swap working files with final result
	#cat $(BUILD_DIR)/term.tsv.gz | gunzip | tail -n +2 | gzip > $(BUILD_DIR)/term_no_header.tsv.gz
	#cat $(BUILD_DIR)/term.tsv.gz | gunzip | head -n1 | gzip > $(BUILD_DIR)/term_header.tsv.gz
	curl -s "$(TAXON_GRAPH_URL_PREFIX)/taxonCache.tsv.gz" | gunzip | head -n1 | gzip > $(BUILD_DIR)/term_header.tsv.gz
	curl -s "$(TAXON_GRAPH_URL_PREFIX)/taxonMap.tsv.gz" | gunzip | head -n1 | gzip > $(BUILD_DIR)/term_link_header.tsv.gz

	cat $(BUILD_DIR)/term_link_header.tsv.gz $(TAXON_MAP).update > $(TAXON_MAP)

	#cat ${BUILD_DIR}/taxonCacheNoHeaderNoNCBI.tsv.gz ${BUILD_DIR}/taxonCacheNoHeaderWithNCBI.tsv.gz > ${BUILD_DIR}/taxonCacheNoHeader.tsv.gz

	# normalize the ranks using nomer
	cat $(TAXON_CACHE).update | gunzip | cut -f3 | awk -F '\t' '{ print $$1 "\t" $$1 }' | $(NOMER) replace --properties=config/name2id.properties globi-taxon-rank | cut -f1 | $(NOMER) replace --properties=config/id2name.properties globi-taxon-rank > $(BUILD_DIR)/norm_ranks.tsv
	cat $(TAXON_CACHE).update | gunzip | cut -f7 | awk -F '\t' '{ print $$1 "\t" $$1 }' | $(NOMER) replace --properties=config/name2id.properties globi-taxon-rank | cut -f1 | $(NOMER) replace --properties=config/id2name.properties globi-taxon-rank > $(BUILD_DIR)/norm_path_ranks.tsv


	paste <(cat $(TAXON_CACHE).update | gunzip | cut -f1-2) <(cat $(BUILD_DIR)/norm_ranks.tsv | gunzip) <(cat $(TAXON_CACHE).update | gunzip | cut -f4-6) <(cat $(BUILD_DIR)/norm_path_ranks.tsv | gunzip) <(cat $(TAXON_CACHE).update | gunzip | cut -f8-) | sort | uniq | gzip > $(BUILD_DIR)/taxonCacheNorm.tsv.gz
	cat $(BUILD_DIR)/term_header.tsv.gz $(BUILD_DIR)/taxonCacheNorm.tsv.gz > $(TAXON_CACHE)

normalize: $(TAXON_CACHE)

$(TAXON_GRAPH_ARCHIVE): $(TAXON_CACHE)
	cat $(TAXON_MAP) | gunzip | sha256sum | cut -d " " -f1 > $(TAXON_MAP_NAME).sha256
	cat $(TAXON_CACHE) | gunzip | sha256sum | cut -d " " -f1 > $(TAXON_CACHE_NAME).sha256

	mkdir -p dist
	cp static/README static/prefixes.tsv $(TAXON_MAP) $(TAXON_MAP_NAME).sha256 $(TAXON_CACHE) $(TAXON_CACHE_NAME).sha256 dist/

	cat $(TAXON_MAP) | gunzip | head -n11 > dist/taxonMapFirst10.tsv
	cat $(TAXON_CACHE) | gunzip | head -n11 > dist/taxonCacheFirst10.tsv

	cat $(BUILD_DIR)/names_sorted.tsv | gzip > dist/names.tsv.gz
	cat dist/names.tsv.gz | gunzip | sha256sum | cut -d " " -f1 > dist/names.tsv.sha256

	diff --changed-group-format='%<' --unchanged-group-format='' <(cat dist/names.tsv.gz | gunzip | cut -f1,2 | sort | uniq) <(cat dist/taxonMap.tsv.gz | gunzip | tail -n+2 | cut -f1,2 | sort | uniq) | gzip > dist/namesUnresolved.tsv.gz

	cat dist/namesUnresolved.tsv.gz | gunzip | sha256sum | cut -d " " -f1 > dist/namesUnresolved.tsv.sha256


package: $(TAXON_GRAPH_ARCHIVE)