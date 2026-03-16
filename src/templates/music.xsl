<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
	<xsl:output method="html" doctype-system="about:legacy-compat" />

	<xsl:param name="artist_offset" select="0" />
	<xsl:param name="max_artists" select="24" />
	<xsl:param name="enable_infinite_loading" select="1" />
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
		<xsl:variable name="artists" select="dict/dict/dict[generate-id() = generate-id(key('dicts-by-artist', key[. = 'Artist']/following-sibling::string[1])[1])]" />
		<xsl:variable name="total-artists" select="count($artists)" />
		<xsl:variable name="initial-end">
			<xsl:choose>
				<xsl:when test="$artist_offset + $max_artists &gt; $total-artists">
					<xsl:value-of select="$total-artists" />
				</xsl:when>
				<xsl:otherwise>
					<xsl:value-of select="$artist_offset + $max_artists" />
				</xsl:otherwise>
			</xsl:choose>
		</xsl:variable>
		<xsl:choose>
			<xsl:when test="$enable_infinite_loading = 1">
				<html lang="en">
					<head>
						<meta charset="UTF-8" />
						<title>Songlist</title>
						<link rel="stylesheet" href="assets/css/quarantine.css" />
						<script src="https://unpkg.com/htmx.org@2.0.4" defer="defer"></script>
						<script src="assets/js/music.js" defer="defer"></script>
					</head>
					<body>
						<main class="album-mosaic" id="artist-stream" data-artists-source="artists.html" data-batch-size="{$max_artists}" data-total-artists="{$total-artists}" data-start-index="{$artist_offset + 1}" data-end-index="{$initial-end}" data-next-artist-index="{$initial-end + 1}" data-infinite-loading="{$enable_infinite_loading}">
							<xsl:for-each select="$artists">
								<xsl:sort select="key[. = 'Artist']/following-sibling::string[1]" />
								<xsl:if test="position() &gt; $artist_offset and position() &lt;= $artist_offset + $max_artists">
									<xsl:apply-templates select="." mode="artist">
										<xsl:with-param name="artist-index" select="position()" />
									</xsl:apply-templates>
								</xsl:if>
							</xsl:for-each>
						</main>
						<div id="artist-load-more" hx-get="artists.html" hx-target="#artist-stream" hx-swap="beforeend" hx-trigger="intersect once threshold:1.0" aria-hidden="true"></div>
					</body>
				</html>
			</xsl:when>
			<xsl:otherwise>
				<xsl:for-each select="$artists">
					<xsl:sort select="key[. = 'Artist']/following-sibling::string[1]" />
					<xsl:apply-templates select="." mode="artist">
						<xsl:with-param name="artist-index" select="position()" />
					</xsl:apply-templates>
				</xsl:for-each>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>


	<xsl:template match="dict" mode="song">
		<xsl:variable name="song-id">
			<xsl:apply-templates select="key[. = 'Album']/following-sibling::string[1]" mode="string-normalizer"/><xsl:text>-</xsl:text><xsl:apply-templates select="key[. = 'Name']/following-sibling::string[1]" mode="string-normalizer"/>
		</xsl:variable>
		<article data-type="song" id="{$song-id}">
			<dl data-type="metadata">
				<xsl:apply-templates select="key[. != 'Location' and . != 'Persistent ID']" mode="info"/>
			</dl>
		</article>
	</xsl:template>

		<xsl:template name="emit-missing-info">
			<xsl:param name="label" />
			<dt data-label="{$label}">
				<small><xsl:value-of select="$label"/></small>
			</dt>
			<dd>
				<span>n/a</span>
			</dd>
		</xsl:template>

		<xsl:template match="key[text() = 'Album']" mode="info">
			<dt data-label="{text()}">
				<small><xsl:value-of select="text()"/></small>
			</dt>
			<dd>
				<xsl:apply-templates select="following-sibling::*[1]" mode="info" />
			</dd>
			<xsl:if test="not(../key[. = 'Genre'])">
				<xsl:call-template name="emit-missing-info">
					<xsl:with-param name="label" select="'Genre'" />
				</xsl:call-template>
			</xsl:if>
			<xsl:if test="not(../key[. = 'Genre']) and not(../key[. = 'Year'])">
				<xsl:call-template name="emit-missing-info">
					<xsl:with-param name="label" select="'Year'" />
				</xsl:call-template>
			</xsl:if>
		</xsl:template>

		<xsl:template match="key[text() = 'Genre']" mode="info">
			<dt data-label="{text()}">
				<small><xsl:value-of select="text()"/></small>
			</dt>
			<dd>
				<xsl:apply-templates select="following-sibling::*[1]" mode="info" />
			</dd>
			<xsl:if test="not(../key[. = 'Year'])">
				<xsl:call-template name="emit-missing-info">
					<xsl:with-param name="label" select="'Year'" />
				</xsl:call-template>
			</xsl:if>
		</xsl:template>

		<xsl:template match="key" mode="info">
		<xsl:variable name="type-label">
			<xsl:choose>
					<xsl:when test="text() = 'Name'">
						<xsl:value-of select="'Song'"/>
					</xsl:when>
					<xsl:otherwise>
						<xsl:value-of select="text()"/>
					</xsl:otherwise>
				</xsl:choose>
			</xsl:variable>
			<dt data-label="{text()}">
				<small><xsl:value-of select="$type-label"/></small>
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
			<img src="assets/covers/{$album}/cover.webp" alt="{$album}" loading="lazy"  />
		</xsl:template>

		<xsl:template match="dict" mode="album">
			<xsl:variable name="current-album" select="key[. = 'Album']/following-sibling::string[1]" />
			<xsl:variable name="album" select="$current-album/following-sibling::key[text() = 'Location']/following-sibling::string/text()"></xsl:variable>
			<article data-type="album" style="--placeholder: url('../covers/{$album}/cover.webp')">
				<div>
				<header>
					<xsl:apply-templates select="$current-album/following-sibling::key[text() = 'Location']" mode="image" />
					<h4><xsl:value-of select="$current-album"></xsl:value-of></h4>
					<nav data-type="songs">
						<xsl:for-each select="key('dicts-by-album', $current-album)">
							<xsl:variable name="song-id">
								<xsl:apply-templates select="key[. = 'Album']/following-sibling::string[1]" mode="string-normalizer"/><xsl:text>-</xsl:text><xsl:apply-templates select="key[. = 'Name']/following-sibling::string[1]" mode="string-normalizer"/>
							</xsl:variable>
							<a href="#{$song-id}">■</a>
						</xsl:for-each>
					</nav>
				</header>
					<xsl:apply-templates select="key('dicts-by-album', $current-album)" mode="song"/>
				</div>
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
			<menu>
				<li><a href="https://duckduckgo.com/?q=!ducky+LOL%20Cats">Spotify</a></li>
				<li><a href="https://duckduckgo.com/?q=%5Capple+music+{$query}">Apple Music</a></li>
				<li><a href="https://duckduckgo.com/?q=%5Cyoutube+{$query}"></a>Youtube</li>
				<li><a href="https://duckduckgo.com/?q=%5Cbandcamp+{$query}">Bandcamp</a></li>
			</menu>
		</xsl:template>

		<xsl:template match="dict" mode="artist">
			<xsl:param name="artist-index" select="1" />
			<xsl:variable name="current-artist" select="key[. = 'Artist']/following-sibling::string[1]" />
			<xsl:variable name="artist-slug">
				<xsl:apply-templates select="$current-artist" mode="string-normalizer" />
			</xsl:variable>

			<article data-type="artist" id="artist-{$artist-index}" data-artist-index="{$artist-index}" data-artist-slug="{$artist-slug}">
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
