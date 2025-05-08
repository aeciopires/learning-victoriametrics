#---------------------------
#---------------------------
# VARIABLES
#---------------------------
#---------------------------

# Only Ubuntu
SHELL=/usr/bin/bash
# Only MacOS using brew
#SHELL=/opt/homebrew/bin/bash

CLUSTER_NAME="kind-multinodes"
#----------------------------------------------------------------------------------------------------------


#---------------------------
#---------------------------
# MAIN
#---------------------------
#---------------------------

# References
# https://ryanstutorials.net/bash-scripting-tutorial/bash-input.php
# https://stackoverflow.com/questions/3743793/makefile-why-is-the-read-command-not-reading-the-user-input
# https://stackoverflow.com/questions/60147129/interactive-input-of-a-makefile-variable
# https://makefiletutorial.com/
# https://stackoverflow.com/questions/589276/how-can-i-use-bash-syntax-in-makefile-targets
# https://til.hashrocket.com/posts/k3kjqxtppx-escape-dollar-sign-on-makefiles
# https://stackoverflow.com/questions/5618615/check-if-a-program-exists-from-a-makefile
# https://www.docker.com/blog/multi-arch-build-and-images-the-simple-way/


requirements:
REQUIRED_PACKAGES := docker wget curl kind jq kubefwd cmctl
$(foreach package,$(REQUIRED_PACKAGES),\
	$(if $(shell command -v $(package) 2> /dev/null),$(info Found `$(package)`),$(error Please install `$(package)`)))

vm-cluster-mode:
	make requirements
	chmod +x run.sh
	./run.sh

down:
	make requirements
	kill $$(jobs -p -r)
	kind delete clusters ${CLUSTER_NAME}

.ONESHELL:
recreate-vm-cluster-mode:
	make down
	make vm-cluster-mode