# Emacs Plus Development Makefile
#
# Usage:
#   make test                     Run all unit tests
#   make validate                 Validate build.yml config
#   make formula-30               Build Emacs 30 formula
#   make formula-31 --HEAD        Build with extra brew args
#   make cask                     Install cask (test local changes)
#   make cask@master              Install cask@master (test local changes)
#   make postinstall-formula      Re-run formula post_install
#   make postinstall-cask         Re-run cask postflight

.PHONY: test validate postinstall-formula postinstall-cask cask cask@master help

# Capture extra args (everything after the target)
EXTRA_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
# Turn extra args into do-nothing targets so make doesn't complain
$(eval $(EXTRA_ARGS):;@:)

# Default target
help:
	@echo "Emacs Plus Development"
	@echo ""
	@echo "Testing:"
	@echo "  make test                     Run all unit tests"
	@echo "  make validate                 Validate build.yml for formula & cask"
	@echo ""
	@echo "Formula (build from source):"
	@echo "  make formula-VERSION [ARGS]   Build formula (VERSION: 29, 30, 31)"
	@echo "  make formula-30               Build Emacs 30"
	@echo "  make formula-31 --HEAD        Build Emacs 31 from HEAD"
	@echo ""
	@echo "Cask (pre-built binary, tests local Cask/ and Library/ changes):"
	@echo "  make cask                     Install emacs-plus-app cask"
	@echo "  make cask@master              Install emacs-plus-app@master cask"
	@echo ""
	@echo "Post-install (test on existing installation):"
	@echo "  make postinstall-formula      Re-run post_install scripts"
	@echo "  make postinstall-cask         Re-run cask postflight scripts"

#
# Testing
#

test:
	@echo "==> Running unit tests"
	@for test in tests/test_*.rb; do \
		echo "Running $$test..."; \
		ruby "$$test" || exit 1; \
	done
	@echo "==> All tests passed"

validate:
	@ruby -e ' \
		$$LOAD_PATH.unshift "."; \
		require "Library/BuildConfig"; \
		result = BuildConfig.load_config; \
		if result[:source]; \
			puts "==> Loaded build config from: #{result[:source]}"; \
			puts; \
			puts "Formula context:"; \
			BuildConfig.print_config(result[:config], result[:source], context: :formula, output: method(:puts)); \
			puts; \
			puts "Cask context:"; \
			BuildConfig.print_config(result[:config], result[:source], context: :cask, output: method(:puts)); \
			puts; \
			puts "==> Config is valid"; \
		else; \
			puts "==> No build config found"; \
		end \
	'

#
# Formula builds
#

formula-%:
	@echo "==> Building emacs-plus@$*"
	@VERSION=$*; \
	SOURCE_FILE="Formula/emacs-plus@$$VERSION.rb"; \
	TARGET_FILE="Formula/emacs-plus-local.rb"; \
	if [ ! -f "$$SOURCE_FILE" ]; then \
		echo "Error: $$SOURCE_FILE not found"; \
		echo "Valid versions: 29, 30, 31"; \
		exit 1; \
	fi; \
	cleanup() { rm -f "$$TARGET_FILE"; }; \
	trap cleanup EXIT INT TERM; \
	cp "$$SOURCE_FILE" "$$TARGET_FILE"; \
	case $$VERSION in \
		29) sed -i '' 's/class EmacsPlusAT29/class EmacsPlusLocal/g' "$$TARGET_FILE" ;; \
		30) sed -i '' 's/class EmacsPlusAT30/class EmacsPlusLocal/g' "$$TARGET_FILE" ;; \
		31) sed -i '' 's/class EmacsPlusAT31/class EmacsPlusLocal/g' "$$TARGET_FILE" ;; \
	esac; \
	export HOMEBREW_EMACS_PLUS_MODE=local; \
	export HOMEBREW_NO_INSTALL_UPGRADE=true; \
	export HOMEBREW_NO_AUTO_UPDATE=true; \
	brew uninstall emacs-plus-local 2>/dev/null || true; \
	HOMEBREW_DEVELOPER=1 brew install --formula "./$$TARGET_FILE" $(EXTRA_ARGS)

#
# Post-install simulation
#

postinstall-formula:
	@echo "==> Running formula post_install simulation"
	@ruby scripts/postinstall-formula.rb

postinstall-cask:
	@echo "==> Running cask postflight simulation"
	@ruby scripts/postinstall-cask.rb

#
# Cask installation (tests local Cask/ and Library/ changes)
#

# Casks must be in a tap, so we temporarily replace the tap's cask with our modified version
cask:
	@echo "==> Installing emacs-plus-app cask (with local Library/ changes)"
	@LOCAL_PATH=$$(pwd); \
	TAP_CASK="$$(brew --repository d12frosted/emacs-plus)/Casks/emacs-plus-app.rb"; \
	BACKUP="$$TAP_CASK.backup"; \
	cleanup() { [ -f "$$BACKUP" ] && mv "$$BACKUP" "$$TAP_CASK"; }; \
	trap cleanup EXIT INT TERM; \
	cp "$$TAP_CASK" "$$BACKUP"; \
	sed -e "s|tap = Tap.fetch.*|local_path = \"$$LOCAL_PATH\"|" \
	    -e 's|#{tap.path}|#{local_path}|g' \
	    "$$BACKUP" > "$$TAP_CASK"; \
	brew reinstall --cask emacs-plus-app $(EXTRA_ARGS)

cask@master:
	@echo "==> Installing emacs-plus-app@master cask (with local Library/ changes)"
	@LOCAL_PATH=$$(pwd); \
	TAP_CASK="$$(brew --repository d12frosted/emacs-plus)/Casks/emacs-plus-app@master.rb"; \
	BACKUP="$$TAP_CASK.backup"; \
	cleanup() { [ -f "$$BACKUP" ] && mv "$$BACKUP" "$$TAP_CASK"; }; \
	trap cleanup EXIT INT TERM; \
	cp "$$TAP_CASK" "$$BACKUP"; \
	sed -e "s|tap = Tap.fetch.*|local_path = \"$$LOCAL_PATH\"|" \
	    -e 's|#{tap.path}|#{local_path}|g' \
	    "$$BACKUP" > "$$TAP_CASK"; \
	brew reinstall --cask emacs-plus-app@master $(EXTRA_ARGS)
