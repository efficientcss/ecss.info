<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
	<xsl:template match="*" mode="main-content">
		<xsl:apply-templates/>
	</xsl:template>
	<xsl:template match="root" mode="body" name="body">
		<link rel="stylesheet" href="assets/css/4.regions/body.css"/>
		<body class="side-nav-main-pile bottom-nav-sliding-content">
			<header>
				<h1>ecss</h1>
				<link rel="stylesheet" href="assets/css/4.regions/nav.css"/>
				<nav id="nav-en" lang="en">
					<a href="#intro">Intro</a>
					<a href="#values">Values</a>
					<a href="#principles">Principles</a>
					<a href="#rules">Rules</a>
					<a href="#tools">Tools</a>
					<button lang="fr">Français</button>
				</nav>
				<nav id="nav-fr" lang="fr">
					<a href="#introduction">Intro</a>
					<a href="#valeurs">Valeurs</a>
					<a href="#principes">Principes</a>
					<a href="#regles">Règles</a>
					<a href="#outils">Outils</a>
					<button lang="en">English</button>
				</nav>
			</header>
			<link rel="stylesheet" href="assets/css/4.regions/main.css"/>
			<main lang="en" hidden="until-found">
				<xsl:apply-templates mode="main-content" />
			</main>
			<main lang="fr">
				<h2>test</h2>
			</main>
			<script>
				window.addEventListener("DOMContentLoaded", applyChosenLang);
				const langSwitchers = document.querySelectorAll('button[lang]');
				langSwitchers.forEach((e) => {
					e.addEventListener("click", () => {
						chosenLang = e.getAttribute("lang");
						localStorage.setItem("lang", chosenLang);
						applyChosenLang();
					});
				});

			</script>
		</body>
	</xsl:template>
</xsl:stylesheet>
