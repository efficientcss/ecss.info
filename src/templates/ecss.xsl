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
		<html lang="{$lang}">
		<head>
			<script>
				let chosenLang = "";
				if(!localStorage.lang) {
					chosenLang = navigator.languages[0].split("-")[0];
					if(chosenLang.includes("en") || chosenLang.includes("fr")) {
						localStorage.setItem("lang", chosenLang);
					} else {
						localStorage.setItem("lang", "en");
					}
				} else {
					chosenLang = localStorage.getItem("lang");
				}

				const applyChosenLang = () => { 
					document.documentElement.setAttribute("lang", chosenLang);
					document.querySelectorAll('main').forEach((e) => {
						const contentLang = e.getAttribute("lang");
						if(contentLang == chosenLang) {
							e.removeAttribute('hidden');
						} else {
							e.setAttribute('hidden', 'until-found');
						}
					});
				}
			</script>
			<meta name="viewport" content="width=device-width, initial-scale=1.0" />
			<link rel="stylesheet" href="assets/css/e.css" />
			<link rel="stylesheet" href="assets/fonts/hankenGrotesk.css" />
			<link rel="stylesheet" href="assets/css/4.regions/html.css" />
			<link rel="stylesheet" media="(orientation:landscape)" href="assets/css/5.compositions/side-nav-main-pile.css" />
			<link rel="stylesheet" media="(orientation:portrait)" href="assets/css/5.compositions/bottom-nav-sliding-content.css" />
			<!-- <link rel="stylesheet" href="x.dev/debug.css" /> -->
			<link rel="stylesheet" href="assets/css/x.dev/quarantine.css" />
			<link rel="stylesheet" href="https://use.typekit.net/qly6uoc.css" />
			<meta charset="UTF-8" />
			<title>ECSS</title>
		</head>
		<xsl:call-template name="body" />
	</html>
</xsl:template>
</xsl:stylesheet>
