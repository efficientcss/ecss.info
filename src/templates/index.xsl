<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
	<xsl:output method="html" doctype-system="about:legacy-compat" />
	<xsl:include href="ecss.xsl" />

	<!-- Load code examples with HTMX -->
	<xsl:variable name="script" select="true()"/>
	<xsl:template match="div[@class='sourceCode'][@id]">
		<div class="{@class}" id="{@id}" data-hx-get="code-examples.html" data-hx-swap="outerHTML" data-hx-select="#{@id}" data-hx-trigger="intersect once"></div>
	</xsl:template>

</xsl:stylesheet>
