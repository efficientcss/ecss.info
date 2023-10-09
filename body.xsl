<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
	<xsl:template match="*" mode="main-content">
		<xsl:apply-templates/>
	</xsl:template>
	<xsl:template match="root" mode="body" name="body">
		<body>
			<header>
				<h1>ecss</h1>
				<nav>
					<a href="">Intro</a>
					<a href="">Values</a>
					<a href="">Principles</a>
					<a href="">Rules</a>
					<a href="">Tools</a>
				</nav>
			</header>
			<main>
				<xsl:apply-templates mode="main-content" />
			</main>
		</body>
	</xsl:template>
</xsl:stylesheet>
