<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
	<xsl:output method="html" doctype-system="about:legacy-compat" />

	<xsl:include href="body.xsl" />
	<!-- Identity transform -->
	<!-- Primordial. Permet à la machine de fonctionner. -->
	<xsl:template match="@*|node()">
		<xsl:copy>
			<xsl:apply-templates select="@*|node()" />
		</xsl:copy>
	</xsl:template>


	<!-- On démarre la machine -->
	<xsl:template match="/">
		<html lang="fr">
		<head>
			<meta name="viewport" content="width=device-width, initial-scale=1.0" />
			<link rel="stylesheet" href="e.css" />
			<!-- <link rel="stylesheet" href="x.dev/debug.css" /> -->
			<link rel="stylesheet" href="x.dev/quarantine.css" />
			<meta charset="UTF-8" />
			<title>ECSS</title>
		</head>
		<xsl:call-template name="body" />
		</html>
	</xsl:template>
</xsl:stylesheet>
