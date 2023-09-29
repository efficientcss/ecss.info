<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
	<xsl:template match="*" mode="main-content">
		<xsl:apply-templates/>
	</xsl:template>
	<xsl:template match="root" mode="body" name="body">
		<body>
			<main>
				<xsl:apply-templates mode="main-content" />
			</main>
		</body>
	</xsl:template>
</xsl:stylesheet>
