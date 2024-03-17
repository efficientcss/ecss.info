<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" >
	<xsl:output method="html" doctype-system="about:legacy-compat" />

	<xsl:template match="@*|node()">
		<xsl:copy>
			<xsl:apply-templates select="@*|node()" />
		</xsl:copy>
	</xsl:template>

	<xsl:template match="/">
		<html>
			<head>
				<meta charset="UTF-8"/>
			</head>
			<body>
				<xsl:apply-templates select="//div[@class='sourceCode'][@id]" />
			</body>
		</html>
	</xsl:template>
</xsl:stylesheet>


