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
		<xsl:variable name="lang">
			<xsl:value-of select="/root/@lang" />
		</xsl:variable>
		<html lang="{$lang}" class="side-nav-main-pile bottom-nav-sliding-content">
		<head>
			<link rel="preconnect" href="https://use.typekit.net" crossorigin="" />
			<link rel="preconnect" href="https://p.typekit.net" crossorigin="" />
			<link rel="preload" href="https://p.typekit.net" crossorigin="" />

			<link rel="stylesheet" href="../assets/css/1.base/1.layers.css" />
			<link rel="stylesheet" href="../assets/css/min.e.css" />
			<link rel="stylesheet" media="(orientation:landscape)" href="../assets/css/5.compositions/side-nav-main-pile.css" />
			<link rel="stylesheet" media="(orientation:portrait)" href="../assets/css/5.compositions/bottom-nav-sliding-content.css" />
			<link rel="stylesheet" href="https://use.typekit.net/qly6uoc.css" />

			<meta name="viewport" content="width=device-width, initial-scale=1.0" />
			<meta charset="UTF-8" />
			<xsl:choose>
				<xsl:when test="$lang='en'">
					<meta name="description" content="ECSS sets simple rules for simple styling. No more naming everything, no more technological dependencies. Only intentional, consistent, simple, expressive, predictable, sustainable CSS." />
					<title>ECSS — Simple Rules for efficient CSS</title>
				</xsl:when>
				<xsl:otherwise>
					<meta name="description" content="ECSS établit des règles simples pour des styliser simplement. Plus besoin de tout nommer, plus de dépendances technologiques. Uniquement du CSS intentionnel, cohérent, simple, expressif, prévisible et durable." />
					<title>ECSS — Des règles simples pour du CSS efficient</title>
				</xsl:otherwise>
			</xsl:choose>
		</head>
		<xsl:call-template name="body" />
	</html>
</xsl:template>
		</xsl:stylesheet>
