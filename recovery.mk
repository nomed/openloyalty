SHELL := /bin/bash
PROFILE ?= 2022
VALID_PROFILES := original 2022 latest
ifeq ($(filter $(PROFILE),$(VALID_PROFILES)),)
$(error Invalid PROFILE: $(PROFILE))
endif
.PHONY: doctor sources materialize verify up setup smoke test down
doctor:
	bash scripts/reference-doctor.sh $(PROFILE)
sources:
	bash scripts/verify-reference.sh
materialize:
	bash scripts/materialize-reference.sh
verify: sources
	bash scripts/reference-doctor.sh $(PROFILE)
up setup smoke test down:
	bash scripts/reference-runtime.sh $@ $(PROFILE)
