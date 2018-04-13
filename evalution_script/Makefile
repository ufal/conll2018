.PHONY: all
all:

.PHONY: test
test:
	@sed -n 's/^  - (cd evaluation_script && \(.*\))/\1/; T; s/^python/&2/; p' ../.travis.yml | while read cmd; do eval $$cmd; done
	@sed -n 's/^  - (cd evaluation_script && \(.*\))/\1/; T; s/^python/&3/; p' ../.travis.yml | while read cmd; do eval $$cmd; done
