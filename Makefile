.SILENT:

SRC=src/content
TEMP=temp
DIST=.
DEFAULT_LANG ?= fr
LANG_PREFIX_MODE ?= all
TEMPLATE_OUTPUTS ?= src/templates/index.xsl:index.html src/templates/noscript.xsl:full.html src/templates/code-examples.xsl:code-examples.html
export DEFAULT_LANG LANG_PREFIX_MODE TEMPLATE_OUTPUTS

all: dev

build:
	ENV=$(ENV) FORCE=$(FORCE) sh src/scripts/build.sh $(SRC) $(TEMP) $(DIST)

dev: ENV=dev
dev: build

prod: ENV=prod
prod: build

force: force-dev

force-dev: ENV=dev
force-dev: FORCE=1
force-dev: build

force-prod: ENV=prod
force-prod: FORCE=1
force-prod: build

anchors:
	sh src/scripts/anchors.sh $(SRC)
