.PHONY: fmt validate bundle
PROVIDERS := aws azure gcp openstack oci
BUNDLE := dist/privacy-stack-native-multicloud.zip

fmt:
	terraform fmt -recursive .

validate: fmt
	@for provider in $(PROVIDERS); do \
		echo "Validating $$provider"; \
		terraform -chdir=$$provider validate || exit 1; \
	done
	bash -n modules/native_stack/install.sh.tftpl \
		modules/native_stack/install-database.sh.tftpl \
		modules/native_stack/install-nextcloud.sh.tftpl \
		modules/native_stack/install-passbolt.sh.tftpl

bundle: validate
	mkdir -p dist
	rm -f $(BUNDLE)
	zip -qr $(BUNDLE) README.md modules $(PROVIDERS) -x '*/.terraform/*' -x '*.tfstate*' -x '*/terraform.tfvars'
	@echo "Created $(BUNDLE)"
