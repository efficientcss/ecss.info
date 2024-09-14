<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
	<xsl:output method="html" doctype-system="about:legacy-compat" />

    <xsl:key name="dicts-by-artist" match="dict" use="key[. = 'Artist']/following-sibling::string[1]" />
    <xsl:key name="dicts-by-album" match="dict" use="key[. = 'Album']/following-sibling::string[1]" />
	<!-- Identity transform -->
	<!-- Primordial. Permet à la machine de fonctionner. -->
	<xsl:template match="@*|node()">
		<xsl:copy>
			<xsl:apply-templates select="@*|node()" />
		</xsl:copy>
	</xsl:template>
	<xsl:variable name="lang">
		<xsl:value-of select="/root/@lang" />
	</xsl:variable>
	<xsl:variable name="special-characters" select="'/ áàâäéèêëíìîïóòôöúùûüçÁÀÂÄÉÈÊËÍÌÎÏÓÒÔÖÚÙÛÜÇABCDEFGHIJKLMNOPQRSTUVWXYZ&amp;’?.()!:,'"/>
	<xsl:variable name="normalized-special-characters" select="'--aaaaeeeeiiiioooouuuuçaaaaeeeeiiiioooouuuuçabcdefghijklmnopqrstuvwxyz_'"/>

	<xsl:template match="* | @* | text()" mode="string-normalizer">
		<xsl:value-of select="translate(normalize-space(.), $special-characters, $normalized-special-characters)"/>
	</xsl:template>

	<xsl:template match="plist">
		<html lang="en">
			<head>
				<meta charset="UTF-8" />
				<title>Songlist</title>
				<link rel="stylesheet" href="assets/css/quarantine.css" />
			</head>
			<body>
				<aside>
					<menu>
						<li><button>Artistes</button></li>
						<li><button>Albums</button></li>
						<li><button>Genres</button></li>
					</menu>
				</aside>
				<main class="song-list">
					<!-- <xsl:apply-templates select="dict/dict/dict" mode="song" /> -->
					<xsl:apply-templates select="dict/dict/dict[generate-id() = generate-id(key('dicts-by-artist', key[. = 'Artist']/following-sibling::string[1])[1])]" mode="artist">
						<xsl:sort select="key[. = 'Artist']/following-sibling::string[1]" order="ascending"></xsl:sort>
					</xsl:apply-templates>
				</main>
			</body>
		</html>
	</xsl:template>

	<xsl:template match="dict" mode="song">
		<article>
			<xsl:apply-templates select="key[1]" mode="song" />
		</article>
	</xsl:template>

	<xsl:template match="key" mode="song">
		<dl>
			<xsl:apply-templates select="self|following-sibling::key" mode="info"></xsl:apply-templates>
		</dl>
		<!-- <xsl:apply-templates select="following-sibling::key[text() = 'Location']" mode="image"></xsl:apply-templates> -->
	</xsl:template>
	<xsl:template match="key" mode="info">
		<dt>
			<small><xsl:value-of select="text()"/></small>
		</dt>
		<dd>
			<xsl:apply-templates select="following-sibling::*[1]" mode="info" />
		</dd>
	</xsl:template>
	<xsl:template match="integer" mode="info">
		<span><xsl:value-of select="text()"/></span>
	</xsl:template>
	<xsl:template match="string" mode="info">
		<xsl:apply-templates select="ancestor::dict[1]" mode="player"/>
		<span><xsl:value-of select="text()"/></span>
	</xsl:template>

	<xsl:template match="key" mode="image">
		<xsl:variable name="album" select="following-sibling::string/text()" />
		<img src="assets/img/covers/{$album}/cover.jpg" alt="{$album}" />
	</xsl:template>

	<xsl:template match="dict" mode="album">
		<xsl:variable name="current-album" select="key[. = 'Album']/following-sibling::string[1]" />
		<article>
			<xsl:apply-templates select="$current-album/following-sibling::key[text() = 'Location']" mode="image" />
			<h4><xsl:value-of select="$current-album"></xsl:value-of></h4>
			<dl>
				<xsl:apply-templates select="key('dicts-by-album', $current-album)/key[text() = 'Name' or text() = 'Rating']" mode="info"></xsl:apply-templates>
			</dl>
		</article>
	</xsl:template>

	<xsl:template match="key" mode="player" priority="-1"></xsl:template>

	<xsl:template match="key[. ='Artist']" mode="player" priority="3">
		<xsl:apply-templates select="following-sibling::string[1]" mode="string-normalizer"/><xsl:text>+</xsl:text>
	</xsl:template>

	<xsl:template match="key[. ='Album']" mode="player" priority="2">
		<xsl:apply-templates select="following-sibling::string[1]" mode="string-normalizer"/>
	</xsl:template>

	<xsl:template match="key[. ='Name']" mode="player" priority="1">
		<xsl:apply-templates select="following-sibling::string[1]" mode="string-normalizer"/><xsl:text>+</xsl:text>
	</xsl:template>

	<xsl:template match="dict" mode="player">
		<xsl:variable name="query">
			<xsl:apply-templates select="key" mode="player"/>
		</xsl:variable>
		<ul>
			<li><a href="https://duckduckgo.com/?q=!ducky+LOL%20Cats">Spotify</a></li>
			<li><a href="https://duckduckgo.com/?q=%5Capple+music+{$query}">Apple Music</a></li>
			<li><a href="https://duckduckgo.com/?q=%5Cyoutube+{$query}"></a>Youtube</li>
			<li><a href="https://duckduckgo.com/?q=%5Cbandcamp+{$query}">Bandcamp</a></li>
		</ul>
	</xsl:template>

	<xsl:template match="dict" mode="artist">
		<xsl:variable name="current-artist" select="key[. = 'Artist']/following-sibling::string[1]" />

		<article>
			<h3>
				<xsl:value-of select="$current-artist" />
			</h3>
			<!-- Apply templates to dicts in the current group -->
			<xsl:apply-templates select="key('dicts-by-artist', $current-artist)[generate-id() = generate-id(key('dicts-by-album', key[. = 'Album']/following-sibling::string[1])[1])]" mode="album">
				<xsl:sort select="key[. = 'Year']/following-sibling::integer[1]" order="ascending"></xsl:sort>
			</xsl:apply-templates>
		</article>
	</xsl:template>
</xsl:stylesheet>
